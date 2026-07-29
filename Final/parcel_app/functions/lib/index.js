"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.commitParcel = exports.assignRack = exports.scanLabel = exports.sendEmail = exports.importStudents = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const sync_1 = require("csv-parse/sync");
const nodemailer = __importStar(require("nodemailer"));
const genai_1 = require("@google/genai");
admin.initializeApp();
const db = admin.firestore();
exports.importStudents = functions.https.onCall(async (request) => {
    const data = request.data || request;
    const auth = request.auth;
    if (!auth) {
        throw new functions.https.HttpsError('unauthenticated', 'You must be signed in to import students.');
    }
    const csvData = data.csvData;
    if (!csvData) {
        throw new functions.https.HttpsError('invalid-argument', 'The function must be called with a "csvData" argument.');
    }
    try {
        const records = (0, sync_1.parse)(csvData, {
            columns: true,
            skip_empty_lines: true
        });
        const batches = [];
        let currentBatch = db.batch();
        let operationCount = 0;
        for (const record of records) {
            const studentRef = db.collection('students').doc(record.uid || record.id || record.email);
            const studentData = {
                uid: record.uid || record.id || record.email,
                name: record.name,
                email: record.email,
                room: record.room,
                isActive: true
            };
            currentBatch.set(studentRef, studentData, { merge: true });
            operationCount++;
            if (operationCount === 500) {
                batches.push(currentBatch.commit());
                currentBatch = db.batch();
                operationCount = 0;
            }
        }
        if (operationCount > 0) {
            batches.push(currentBatch.commit());
        }
        await Promise.all(batches);
        return {
            success: true,
            message: `Successfully imported ${records.length} students.`,
        };
    }
    catch (error) {
        console.error('Error importing students:', error);
        throw new functions.https.HttpsError('internal', 'Failed to parse or save the CSV data.', String(error));
    }
});
exports.sendEmail = functions.firestore
    .document('emails/{emailId}')
    .onCreate(async (snap, context) => {
    const emailData = snap.data();
    const transporter = nodemailer.createTransport({
        host: 'smtp.gmail.com',
        port: 465,
        secure: true,
        auth: {
            user: 'argo.notify@gmail.com',
            pass: 'hwwyibxaayqknodn'
        }
    });
    try {
        const info = await transporter.sendMail({
            from: '"Argo Notification" <argo.notify@gmail.com>',
            to: emailData.to,
            subject: emailData.subject,
            text: emailData.text,
            html: emailData.html
        });
        console.log('Message sent: %s', info.messageId);
        await snap.ref.update({ status: 'sent', sentAt: admin.firestore.FieldValue.serverTimestamp() });
    }
    catch (error) {
        console.error('Error sending email:', error);
        await snap.ref.update({ status: 'error', error: String(error) });
    }
});
exports.scanLabel = functions.https.onCall(async (request) => {
    var _a;
    const data = request.data || request;
    const auth = request.auth;
    // if (!auth) throw new functions.https.HttpsError('unauthenticated', 'Not signed in');
    const base64Image = data.image;
    if (!base64Image)
        throw new functions.https.HttpsError('invalid-argument', 'Image required');
    const configSnap = await db.collection('config').doc('apiKeys').get();
    const apiKey = (_a = configSnap.data()) === null || _a === void 0 ? void 0 : _a.gemini;
    if (!apiKey)
        throw new functions.https.HttpsError('failed-precondition', 'Gemini API key not configured in config/apiKeys');
    const ai = new genai_1.GoogleGenAI({ apiKey });
    try {
        const response = await ai.models.generateContent({
            model: 'gemini-2.5-flash',
            contents: [
                {
                    role: 'user',
                    parts: [
                        { text: "Extract the following details from this shipping label and return ONLY a valid JSON object with these keys: deliveryService (string, e.g. 'Amazon', 'FedEx', 'UPS', 'USPS'), recipientName (string), trackingNumber (string)." },
                        { inlineData: { mimeType: 'image/jpeg', data: base64Image } }
                    ]
                }
            ]
        });
        let responseText = response.text || "{}";
        responseText = responseText.replace(/```json/g, "").replace(/```/g, "").trim();
        const extractedData = JSON.parse(responseText);
        return { success: true, data: extractedData };
    }
    catch (e) {
        console.error('Gemini Error:', e);
        throw new functions.https.HttpsError('internal', 'Failed to scan label with AI', String(e));
    }
});
exports.assignRack = functions.https.onCall(async (request) => {
    return { success: true, rack: 'A3 - Slot 2' };
});
exports.commitParcel = functions.https.onCall(async (request) => {
    const data = request.data || request;
    const { deliveryService, recipientName, trackingNumber, rack } = data;
    const pin = Math.floor(1000 + Math.random() * 9000).toString();
    const parcelRef = await db.collection('parcels').add({
        deliveryService,
        recipientName,
        trackingNumber,
        rack,
        pin,
        status: 'STORED',
        receivedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    const studentsSnap = await db.collection('students')
        .where('name', '>=', recipientName)
        .where('name', '<=', recipientName + '\uf8ff')
        .limit(1)
        .get();
    let toEmail = 'student@example.com';
    if (!studentsSnap.empty) {
        toEmail = studentsSnap.docs[0].data().email;
    }
    await db.collection('emails').add({
        to: toEmail,
        subject: `Your parcel from ${deliveryService} has arrived!`,
        text: `Hello ${recipientName},\n\nYour parcel from ${deliveryService} has been stored at the security desk.\n\nYour collection PIN is: ${pin}\n\nPlease collect it at your earliest convenience.`,
        status: 'pending'
    });
    return { success: true, parcelId: parcelRef.id, pin };
});
//# sourceMappingURL=index.js.map