const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { parse } = require('csv-parse/sync');
const nodemailer = require('nodemailer');
const { GoogleGenAI } = require('@google/genai');

const { getFirestore, FieldValue } = require('firebase-admin/firestore');

admin.initializeApp();
const db = getFirestore();

exports.importStudents = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'You must be signed in to import students.'
        );
    }
    
    const csvData = data.csvData;
    if (!csvData) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'The function must be called with a "csvData" argument.'
        );
    }

    try {
        const records = parse(csvData, {
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
    } catch (error) {
        console.error('Error importing students:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Failed to parse or save the CSV data.',
            String(error)
        );
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
            
            await snap.ref.update({ status: 'sent', sentAt: FieldValue.serverTimestamp() });
        } catch (error) {
            console.error('Error sending email:', error);
            await snap.ref.update({ status: 'error', error: String(error) });
        }
    });

exports.scanLabel = functions.https.onCall(async (data, context) => {
    // if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Not signed in');
    
    const base64Image = data.image;
    if (!base64Image) throw new functions.https.HttpsError('invalid-argument', 'Image required');

    // Use Vertex AI with the Cloud Function's built-in service account — no API key needed!
    const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
    const ai = new GoogleGenAI({ vertexai: true, project: projectId, location: 'us-central1' });
    
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
    } catch (error) {
        console.error('Gemini API Error:', error);
        throw new functions.https.HttpsError('internal', 'Failed to scan label with AI', error.message || String(error));
    }
});

exports.assignRack = functions.https.onCall(async (data, context) => {
    return { success: true, rack: 'A3 - Slot 2' };
});

exports.commitParcel = functions.https.onCall(async (data, context) => {
    const { deliveryService, recipientName, trackingNumber, rack } = data;
    
    const pin = Math.floor(1000 + Math.random() * 9000).toString();
    
    const parcelRef = await db.collection('parcels').add({
        deliveryService,
        recipientName,
        trackingNumber,
        rack,
        pin,
        status: 'STORED',
        receivedAt: FieldValue.serverTimestamp()
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