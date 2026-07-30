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
                nameLower: (record.name || '').trim().toLowerCase(),
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
                pass: 'izmcgrywgvojwlru'
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

exports.resolvePin = functions.https.onCall(async (data, context) => {
    // if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Not signed in');
    
    const { pin, deviceId, guardId } = data;
    if (!pin || !deviceId || !guardId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing pin, deviceId, or guardId');
    }

    const maxAttempts = 10;
    const lockoutMinutes = 2;
    
    // Check brute force attempts
    const attemptRef = db.collection('pinAttempts').doc(deviceId);
    const attemptDoc = await attemptRef.get();
    let failedCount = 0;
    
    if (attemptDoc.exists) {
        const attemptData = attemptDoc.data();
        if (attemptData.lockedUntil && attemptData.lockedUntil.toDate() > new Date()) {
            throw new functions.https.HttpsError('resource-exhausted', `Device locked out. Try again later.`);
        }
        if (attemptData.lockedUntil && attemptData.lockedUntil.toDate() <= new Date()) {
            // Lockout expired, reset
            failedCount = 0;
        } else {
            failedCount = attemptData.failedCount || 0;
        }
    }

    const crypto = require('crypto');
    const pinHash = crypto.createHash('sha256').update(pin).digest('hex');

    // Find the parcel matching the hash
    const parcelsSnap = await db.collection('parcels')
        .where('status', '==', 'stored')
        .where('pinHash', '==', pinHash)
        .limit(1)
        .get();

    if (parcelsSnap.empty) {
        // Record failed attempt
        failedCount++;
        let lockedUntil = null;
        if (failedCount >= maxAttempts) {
            lockedUntil = admin.firestore.Timestamp.fromDate(new Date(Date.now() + lockoutMinutes * 60000));
        }
        
        await attemptRef.set({
            failedCount,
            lockedUntil,
            lastGuardId: guardId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        if (lockedUntil) {
            throw new functions.https.HttpsError('resource-exhausted', 'Device locked out due to too many failed attempts.');
        } else {
            throw new functions.https.HttpsError('not-found', 'Invalid PIN.');
        }
    }

    // Success! Reset attempts.
    if (attemptDoc.exists) {
        await attemptRef.delete();
    }

    const parcelDoc = parcelsSnap.docs[0];
    const parcelData = parcelDoc.data();
    return {
        id: parcelDoc.id,
        deliveryService: parcelData.deliveryService || null,
        dateOfDelivery: parcelData.receivedAt ? parcelData.receivedAt.toDate().toISOString() : null,
        recipientName: parcelData.recipientName || parcelData.recipientNameRaw || null,
        trackingNumber: parcelData.trackingNumber || null,
        rack: parcelData.rack || parcelData.rackId || null,
        studentUid: parcelData.studentUid || null,
        studentName: parcelData.studentName || null
    };
});

exports.completeHandover = functions.https.onCall(async (data, context) => {
    const { parcelId, receiverUid, receiverName, isOwner, verificationMethod, faceMatchScore, guardId } = data;
    if (!parcelId || !receiverUid || !verificationMethod || !guardId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields for handover');
    }

    const parcelRef = db.collection('parcels').doc(parcelId);
    
    await db.runTransaction(async (transaction) => {
        const parcelDoc = await transaction.get(parcelRef);
        if (!parcelDoc.exists) throw new functions.https.HttpsError('not-found', 'Parcel not found');
        const parcel = parcelDoc.data();
        if (parcel.status !== 'stored') throw new functions.https.HttpsError('failed-precondition', 'Parcel is not stored');
        
        const rackRef = db.collection('racks').doc(parcel.rackId);
        
        // Update Parcel
        transaction.update(parcelRef, {
            status: 'collected',
            receiverUid,
            receiverIsOwner: isOwner,
            collectedByGuardId: guardId,
            collectedAt: admin.firestore.FieldValue.serverTimestamp(),
            verificationMethod,
            faceMatchScore: faceMatchScore || null
        });

        // Free the rack slot
        transaction.update(rackRef, {
            occupied: admin.firestore.FieldValue.increment(-1)
        });

        // Decrement student parcelsWaiting
        if (parcel.studentUid) {
            const studentRef = db.collection('students').doc(parcel.studentUid);
            transaction.update(studentRef, {
                parcelsWaiting: admin.firestore.FieldValue.increment(-1)
            });
        }
        
        // Send email to owner
        if (parcel.studentUid) {
            const ownerRef = db.collection('students').doc(parcel.studentUid);
            const ownerDoc = await transaction.get(ownerRef);
            if (ownerDoc.exists) {
                const ownerEmail = ownerDoc.data().email;
                const emailRef = db.collection('emails').doc();
                
                let text = `Your parcel from ${parcel.deliveryService} has been collected.`;
                if (!isOwner) {
                   text = `Your parcel from ${parcel.deliveryService} was collected on your behalf by ${receiverName} (${receiverUid}).`;
                }

                transaction.set(emailRef, {
                    type: 'COLLECTED',
                    to: ownerEmail,
                    subject: 'Parcel collected',
                    text: text,
                    html: `<p>${text}</p><br><p>Verification: ${verificationMethod}</p>`,
                    parcelId: parcelId,
                    studentUid: parcel.studentUid,
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                    status: 'queued'
                });
            }
        }
    });

    return { success: true };
});

exports.assignRack = functions.https.onCall(async (data, context) => {
    // 1. Generate all possible racks
    const allRacks = [];
    for (const r of ['A', 'B', 'C', 'D']) {
        for (let c = 1; c <= 5; c++) {
            allRacks.push(`${r}${c}`);
        }
    }

    // 2. Query all stored parcels to count how many are in each rack
    const parcelsSnapshot = await db.collection('parcels').where('status', '==', 'stored').get();
    const rackCounts = {};
    parcelsSnapshot.forEach(doc => {
        const p = doc.data();
        if (p.rack) {
            rackCounts[p.rack] = (rackCounts[p.rack] || 0) + 1;
        }
    });

    // 3. Filter racks that have less than 5 parcels
    const availableRacks = allRacks.filter(r => (rackCounts[r] || 0) < 5);

    if (availableRacks.length === 0) {
        throw new functions.https.HttpsError('resource-exhausted', 'All racks are full (capacity 5 per cell).');
    }

    // 4. Select the first available rack (ascending order)
    const chosenRack = availableRacks[0];

    return { success: true, rack: chosenRack };
});

exports.commitParcel = functions.https.onCall(async (data, context) => {
    const { deliveryService, recipientName, trackingNumber, rack } = data;
    
    const pin = Math.floor(1000 + Math.random() * 9000).toString();
    const crypto = require('crypto');
    const pinHash = crypto.createHash('sha256').update(pin).digest('hex');
    
    const parcelRef = await db.collection('parcels').add({
        deliveryService,
        recipientName,
        trackingNumber,
        rack,
        pin,
        pinHash,
        status: 'stored',
        receivedAt: FieldValue.serverTimestamp()
    });

    // --- Robust student lookup ---
    // 1. Try exact case-insensitive match using nameLower field
    const nameLower = (recipientName || '').trim().toLowerCase();
    let toEmail = null;
    let matchedUid = null;
    let matchedName = null;
    
    if (nameLower) {
        // First try: exact match on nameLower
        let studentsSnap = await db.collection('students')
            .where('nameLower', '==', nameLower)
            .limit(1)
            .get();
        
        if (!studentsSnap.empty) {
            toEmail = studentsSnap.docs[0].data().email;
            matchedUid = studentsSnap.docs[0].id;
            matchedName = studentsSnap.docs[0].data().name;
        }

        // Second try: prefix match on the original name field (case-sensitive fallback)
        if (!toEmail) {
            studentsSnap = await db.collection('students')
                .where('name', '>=', recipientName)
                .where('name', '<=', recipientName + '\uf8ff')
                .limit(1)
                .get();
            if (!studentsSnap.empty) {
                toEmail = studentsSnap.docs[0].data().email;
                matchedUid = studentsSnap.docs[0].id;
                matchedName = studentsSnap.docs[0].data().name;
            }
        }

        // Third try: fetch ALL students and do a fuzzy contains match
        if (!toEmail) {
            const allStudents = await db.collection('students').get();
            for (const doc of allStudents.docs) {
                const studentData = doc.data();
                const studentNameLower = (studentData.name || '').toLowerCase();
                // Check if either name contains the other (handles partial names from labels)
                if (studentNameLower.includes(nameLower) || nameLower.includes(studentNameLower)) {
                    toEmail = studentData.email;
                    matchedUid = doc.id;
                    matchedName = studentData.name;
                    break;
                }
            }
        }
    }

    if (matchedUid) {
        await parcelRef.update({
            studentUid: matchedUid,
            studentName: matchedName
        });
    }

    if (!toEmail) {
        console.warn(`No student found matching name: "${recipientName}". Email will not be sent.`);
    } else {
        await db.collection('emails').add({
            to: toEmail,
            subject: `Your parcel from ${deliveryService} has arrived!`,
            text: `Hello ${recipientName},\n\nYour parcel from ${deliveryService} has been stored at Gate 1.\n\nYour collection PIN is: ${pin}\n\nPlease collect it at your earliest convenience.`,
            status: 'pending'
        });
    }

    return { success: true, parcelId: parcelRef.id, pin, emailSentTo: toEmail || 'none' };
});