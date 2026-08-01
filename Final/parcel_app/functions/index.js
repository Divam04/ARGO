const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { parse } = require('csv-parse/sync');
const nodemailer = require('nodemailer');
const { GoogleGenAI } = require('@google/genai');

const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

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
            lockedUntil = Timestamp.fromDate(new Date(Date.now() + lockoutMinutes * 60000));
        }
        
        await attemptRef.set({
            failedCount,
            lockedUntil,
            lastGuardId: guardId,
            updatedAt: FieldValue.serverTimestamp()
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
    if (!parcelId || !verificationMethod || !guardId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields for handover');
    }

    const parcelRef = db.collection('parcels').doc(parcelId);
    const parcelDoc = await parcelRef.get();
    
    if (!parcelDoc.exists) throw new functions.https.HttpsError('not-found', 'Parcel not found');
    const parcel = parcelDoc.data();
    if (parcel.status !== 'stored') throw new functions.https.HttpsError('failed-precondition', 'Parcel is not stored');
    
    // Update Parcel status to collected
    await parcelRef.update({
        status: 'collected',
        receiverUid: receiverUid || null,
        receiverName: receiverName || null,
        receiverIsOwner: isOwner,
        collectedByGuardId: guardId,
        collectedAt: FieldValue.serverTimestamp(),
        verificationMethod,
        faceMatchScore: faceMatchScore || null
    });

    // Decrement student parcelsWaiting if applicable
    const studentUid = parcel.studentUid;
    if (studentUid) {
        try {
            const studentRef = db.collection('students').doc(studentUid);
            const studentDoc = await studentRef.get();
            if (studentDoc.exists) {
                await studentRef.update({
                    parcelsWaiting: FieldValue.increment(-1)
                });
            }
        } catch (err) {
            console.warn('Could not decrement parcelsWaiting:', err);
        }
    }

    // Send collection email to owner
    if (studentUid) {
        try {
            const ownerDoc = await db.collection('students').doc(studentUid).get();
            if (ownerDoc.exists) {
                const ownerEmail = ownerDoc.data().email;
                
                let guardName = guardId;
                try {
                    const guardDoc = await db.collection('guards').doc(guardId).get();
                    if (guardDoc.exists) guardName = guardDoc.data().name || guardId;
                } catch(e) {}

                const dateStr = new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', dateStyle: 'medium', timeStyle: 'short' });

                let text = `Your parcel from ${parcel.deliveryService || 'N/A'} has been collected.\n`;
                text += `AWB: ${parcel.trackingNumber || 'N/A'}\n`;
                text += `Collected By: ${receiverName || 'Unknown'} (${receiverUid || 'N/A'})\n`;
                text += `Handed Over By: ${guardName}\n`;
                text += `Date/Time: ${dateStr}\n`;

                const html = `
                <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #ddd; border-radius: 8px; overflow: hidden;">
                    <div style="background-color: #0d6efd; color: white; padding: 16px; text-align: center;">
                        <h2 style="margin: 0;">Parcel Handed Over</h2>
                    </div>
                    <div style="padding: 24px;">
                        <p>Hello ${ownerDoc.data().name || ''},</p>
                        <p>${isOwner ? 'You have' : 'Someone has'} collected your parcel.</p>
                        
                        <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
                            <tr style="border-bottom: 1px solid #eee;">
                                <td style="padding: 12px 0; color: #666;"><strong>Courier:</strong></td>
                                <td style="padding: 12px 0; text-align: right;">${parcel.deliveryService || 'N/A'}</td>
                            </tr>
                            <tr style="border-bottom: 1px solid #eee;">
                                <td style="padding: 12px 0; color: #666;"><strong>AWB:</strong></td>
                                <td style="padding: 12px 0; text-align: right;">${parcel.trackingNumber || 'N/A'}</td>
                            </tr>
                            <tr style="border-bottom: 1px solid #eee;">
                                <td style="padding: 12px 0; color: #666;"><strong>Collected By:</strong></td>
                                <td style="padding: 12px 0; text-align: right;">${receiverName || 'Unknown'} (${receiverUid || 'N/A'})</td>
                            </tr>
                            <tr style="border-bottom: 1px solid #eee;">
                                <td style="padding: 12px 0; color: #666;"><strong>Handed Over By:</strong></td>
                                <td style="padding: 12px 0; text-align: right;">${guardName}</td>
                            </tr>
                            <tr style="border-bottom: 1px solid #eee;">
                                <td style="padding: 12px 0; color: #666;"><strong>Time:</strong></td>
                                <td style="padding: 12px 0; text-align: right;">${dateStr}</td>
                            </tr>
                        </table>
                    </div>
                </div>
                `;

                await db.collection('emails').add({
                    type: 'COLLECTED',
                    to: ownerEmail,
                    subject: 'Parcel Collected',
                    text: text,
                    html: html,
                    parcelId: parcelId,
                    studentUid: studentUid,
                    sentAt: FieldValue.serverTimestamp(),
                    status: 'pending'
                });
            }
        } catch (err) {
            console.warn('Could not send collection email:', err);
        }
    }

    return { success: true };
});

exports.massHandover = functions.https.onRequest(async (req, res) => {
    try {
        const parcelsSnap = await db.collection('parcels').where('status', '==', 'stored').get();
        if (parcelsSnap.empty) {
            return res.send("No stored parcels found.");
        }
        
        let count = 0;
        
        for (const doc of parcelsSnap.docs) {
            const parcel = doc.data();
            await doc.ref.update({
                status: 'collected',
                collectedAt: FieldValue.serverTimestamp(),
                verificationMethod: 'mass_handover',
                collectedByGuardId: 'admin'
            });
            
            if (parcel.studentUid) {
                try {
                    const studentRef = db.collection('students').doc(parcel.studentUid);
                    const studentDoc = await studentRef.get();
                    if (studentDoc.exists) {
                        await studentRef.update({
                            parcelsWaiting: FieldValue.increment(-1)
                        });
                    }
                } catch(e) {}
            }
            count++;
        }
        
        res.send(`Successfully handed over ${count} parcels.`);
    } catch (e) {
        res.status(500).send("Error: " + e.message);
    }
});

exports.resolveStudentMatch = functions.https.onCall(async (data, context) => {
    const { recipientName } = data || {};
    if (!recipientName) return { exact: false, candidates: [] };
    
    const nameLower = recipientName.trim().toLowerCase();
    
    // Check for an exact match first
    const exactSnap = await db.collection('students')
        .where('nameLower', '==', nameLower)
        .get();
        
    if (!exactSnap.empty && exactSnap.size === 1) {
        const doc = exactSnap.docs[0];
        return {
            exact: true,
            candidates: [{ uid: doc.id, name: doc.data().name, email: doc.data().email }]
        };
    }
    
    // Otherwise, perform a comprehensive substring and fuzzy search
    const candidatesMap = new Map();
    const allStudents = await db.collection('students').get();
    
    // Helper function for Levenshtein distance
    const levenshtein = (a, b) => {
        if (a.length === 0) return b.length;
        if (b.length === 0) return a.length;
        const matrix = [];
        for (let i = 0; i <= b.length; i++) matrix[i] = [i];
        for (let j = 0; j <= a.length; j++) matrix[0][j] = j;
        for (let i = 1; i <= b.length; i++) {
            for (let j = 1; j <= a.length; j++) {
                if (b.charAt(i - 1) === a.charAt(j - 1)) {
                    matrix[i][j] = matrix[i - 1][j - 1];
                } else {
                    matrix[i][j] = Math.min(
                        matrix[i - 1][j - 1] + 1,
                        Math.min(matrix[i][j - 1] + 1, matrix[i - 1][j] + 1)
                    );
                }
            }
        }
        return matrix[b.length][a.length];
    };

    for (const doc of allStudents.docs) {
        const studentData = doc.data();
        const studentNameLower = (studentData.name || '').toLowerCase();
        
        let isMatch = false;
        
        if (studentNameLower === nameLower) {
            isMatch = true;
        } else if (studentNameLower.length >= 3 && nameLower.length >= 3) {
            if (studentNameLower.includes(nameLower) || nameLower.includes(studentNameLower)) {
                isMatch = true;
            } else {
                const distance = levenshtein(studentNameLower, nameLower);
                const maxLength = Math.max(studentNameLower.length, nameLower.length);
                if (maxLength > 0) {
                    const similarity = 1 - (distance / maxLength);
                    if (similarity > 0.7) {
                        isMatch = true;
                    }
                }
            }
        } else if (studentNameLower.includes(nameLower)) {
            isMatch = true;
        }
        
        if (isMatch) {
            candidatesMap.set(doc.id, { uid: doc.id, name: studentData.name, email: studentData.email });
        }
    }
    
    const candidates = Array.from(candidatesMap.values());
    
    return { exact: false, candidates };
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
    const { deliveryService, recipientName, trackingNumber, rack, guardId, studentUid } = data;
    
    if (!studentUid) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing studentUid');
    }

    const studentDoc = await db.collection('students').doc(studentUid).get();
    if (!studentDoc.exists) {
        throw new functions.https.HttpsError('not-found', `Student not found in database.`);
    }

    const toEmail = studentDoc.data().email;
    const studentName = studentDoc.data().name;

    const pin = Math.floor(1000 + Math.random() * 9000).toString();
    const crypto = require('crypto');
    const pinHash = crypto.createHash('sha256').update(pin).digest('hex');
    
    const currentMonthStr = new Date().toISOString().slice(0, 7); // "YYYY-MM"
    let sequenceNumber = 1;
    let parcelId = '';
    
    await db.runTransaction(async (transaction) => {
        const configRef = db.collection('config').doc('parcelSequence');
        const configDoc = await transaction.get(configRef);
        
        if (configDoc.exists) {
            const data = configDoc.data();
            if (data.currentMonth === currentMonthStr) {
                sequenceNumber = (data.lastSequenceNumber || 0) + 1;
            }
        }
        
        transaction.set(configRef, {
            currentMonth: currentMonthStr,
            lastSequenceNumber: sequenceNumber
        });
        
        const newParcelRef = db.collection('parcels').doc();
        parcelId = newParcelRef.id;
        
        transaction.set(newParcelRef, {
            deliveryService,
            recipientName,
            trackingNumber,
            rack,
            monthlySequenceNumber: sequenceNumber,
            pin,
            pinHash,
            status: 'stored',
            receivedAt: FieldValue.serverTimestamp(),
            studentUid: studentUid,
            studentName: studentName
        });
    });

    let guardName = guardId || 'Unknown Guard';
        if (guardId) {
            try {
                const guardDoc = await db.collection('guards').doc(guardId).get();
                if (guardDoc.exists) guardName = guardDoc.data().name || guardId;
            } catch(e) {}
        }

        const dateStr = new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', dateStyle: 'medium', timeStyle: 'short' });

        let text = `Hello ${studentName || recipientName},\n\nYour parcel from ${deliveryService} has been stored at Gate 1.\n\n`;
        text += `AWB: ${trackingNumber || 'N/A'}\n`;
        text += `Arrival Time: ${dateStr}\n`;
        text += `Registered By: ${guardName}\n`;
        text += `Courier: ${deliveryService}\n\n`;
        text += `Your collection PIN is: ${pin}\n\nPlease collect it at your earliest convenience.`;

        const html = `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #ddd; border-radius: 8px; overflow: hidden;">
            <div style="background-color: #28a745; color: white; padding: 16px; text-align: center;">
                <h2 style="margin: 0;">Parcel Arrived</h2>
            </div>
            <div style="padding: 24px;">
                <p>Hello ${studentName || recipientName},</p>
                <p>Your parcel has arrived and is safely stored at <strong>Gate 1</strong>.</p>
                
                <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
                    <tr style="border-bottom: 1px solid #eee;">
                        <td style="padding: 12px 0; color: #666;"><strong>Courier:</strong></td>
                        <td style="padding: 12px 0; text-align: right;">${deliveryService || 'N/A'}</td>
                    </tr>
                    <tr style="border-bottom: 1px solid #eee;">
                        <td style="padding: 12px 0; color: #666;"><strong>AWB:</strong></td>
                        <td style="padding: 12px 0; text-align: right;">${trackingNumber || 'N/A'}</td>
                    </tr>
                    <tr style="border-bottom: 1px solid #eee;">
                        <td style="padding: 12px 0; color: #666;"><strong>Arrival Time:</strong></td>
                        <td style="padding: 12px 0; text-align: right;">${dateStr}</td>
                    </tr>
                    <tr style="border-bottom: 1px solid #eee;">
                        <td style="padding: 12px 0; color: #666;"><strong>Registered By:</strong></td>
                        <td style="padding: 12px 0; text-align: right;">${guardName}</td>
                    </tr>
                </table>
                
                <div style="margin-top: 32px; background-color: #f8f9fa; padding: 16px; text-align: center; border-radius: 8px;">
                    <p style="margin: 0; color: #666; font-size: 14px;">Your Collection PIN</p>
                    <h1 style="margin: 8px 0 0 0; letter-spacing: 4px; color: #0d6efd;">${pin}</h1>
                </div>
                
                <p style="margin-top: 24px; color: #666; font-size: 14px; text-align: center;">Please collect it at your earliest convenience.</p>
            </div>
        </div>
        `;

        await db.collection('emails').add({
            type: 'STORED',
            to: toEmail,
            subject: `Your parcel from ${deliveryService} has arrived!`,
            text: text,
            html: html,
            status: 'pending',
            sentAt: FieldValue.serverTimestamp()
        });

    return { success: true, parcelId: parcelId, pin, emailSentTo: toEmail, sequenceNumber };
});

exports.dashboardStats = functions.https.onCall(async (data, context) => {
    // Only allow signed-in users (guards or admins)
    // if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Not signed in');
    
    try {
        const parcelsSnap = await db.collection('parcels').get();
        let total = 0;
        let collected = 0;
        let stored = 0;
        let unmatched = 0;
        
        let totalDaysTaken = 0;
        let collectionCount = 0;
        
        const now = new Date();
        const intakeMap = new Map();
        
        // Initialize last 7 days
        for(let i=6; i>=0; i--) {
            const d = new Date();
            d.setDate(now.getDate() - i);
            const dateStr = d.toISOString().split('T')[0];
            intakeMap.set(dateStr, { received: 0, collected: 0 });
        }

        const storedParcels = [];

        parcelsSnap.forEach(doc => {
            const p = doc.data();
            total++;
            
            if (!p.studentUid) unmatched++;
            
            if (p.status === 'collected') {
                collected++;
                if (p.receivedAt && p.collectedAt) {
                    const diffTime = Math.abs(p.collectedAt.toDate() - p.receivedAt.toDate());
                    const diffDays = diffTime / (1000 * 60 * 60 * 24);
                    totalDaysTaken += diffDays;
                    collectionCount++;
                }
                
                if (p.collectedAt) {
                    const colDate = p.collectedAt.toDate().toISOString().split('T')[0];
                    if (intakeMap.has(colDate)) {
                        intakeMap.get(colDate).collected++;
                    }
                }
            } else if (p.status === 'stored') {
                stored++;
                storedParcels.push({
                    id: doc.id,
                    deliveryService: p.deliveryService || 'N/A',
                    trackingNumber: p.trackingNumber || 'N/A',
                    recipientName: p.recipientNameRaw || p.studentName || 'Unknown',
                    rack: p.rack || 'Unassigned',
                    monthlySequenceNumber: p.monthlySequenceNumber || null,
                    receivedAt: p.receivedAt ? p.receivedAt.toDate().toISOString() : null
                });
            }
            
            if (p.receivedAt) {
                const recDate = p.receivedAt.toDate().toISOString().split('T')[0];
                if (intakeMap.has(recDate)) {
                    intakeMap.get(recDate).received++;
                }
            }
        });
        
        const avgDays = collectionCount > 0 ? (totalDaysTaken / collectionCount) : 0;
        
        const dailyIntake = Array.from(intakeMap.entries()).map(([date, counts]) => ({
            date,
            received: counts.received,
            collected: counts.collected
        }));

        // Sort stored parcels by received date descending
        storedParcels.sort((a, b) => {
            if (!a.receivedAt) return 1;
            if (!b.receivedAt) return -1;
            return new Date(b.receivedAt) - new Date(a.receivedAt);
        });

        return {
            total,
            collected,
            uncollected: stored,
            unmatched,
            avgDays,
            dailyIntake,
            storedParcels
        };
    } catch (e) {
        console.error("Dashboard stats error", e);
        throw new functions.https.HttpsError('internal', e.message);
    }
});

// Temporary function to create an admin user
const { getAuth } = require('firebase-admin/auth');
exports.makeAdmin = functions.https.onRequest(async (req, res) => {
    const email = req.query.email;
    const password = req.query.password;
    
    if (!email || !password) {
        res.send("Please provide ?email=...&password=... in the URL.");
        return;
    }

    try {
        let user;
        try {
            user = await getAuth().getUserByEmail(email);
            await getAuth().updateUser(user.uid, { password: password });
        } catch (e) {
            user = await getAuth().createUser({ email, password });
        }
        
        await getAuth().setCustomUserClaims(user.uid, { admin: true });
        res.send(`SUCCESS: User ${email} is now an admin with the provided password! You can log in on the tablet.`);
    } catch (e) {
        res.send(`ERROR: ${e.message}`);
    }
});

exports.syncRackOccupancy = functions.firestore
    .document('parcels/{parcelId}')
    .onWrite(async (change, context) => {
        const db = getFirestore();
        const before = change.before.exists ? change.before.data() : null;
        const after = change.after.exists ? change.after.data() : null;

        const beforeRack = (before && before.status === 'stored') ? before.rack : null;
        const afterRack = (after && after.status === 'stored') ? after.rack : null;

        if (beforeRack === afterRack) return null;

        const batch = db.batch();

        if (beforeRack) {
            batch.update(db.collection('racks').doc(`rack_${beforeRack}`), {
                occupied: FieldValue.increment(-1)
            });
        }

        if (afterRack) {
            batch.update(db.collection('racks').doc(`rack_${afterRack}`), {
                occupied: FieldValue.increment(1)
            });
        }

        return batch.commit();
    });

exports.fixRacks = functions.https.onRequest(async (req, res) => {
    try {
        const db = getFirestore();
        // Reset all racks to 0
        const racksSnap = await db.collection('racks').get();
        const batch = db.batch();
        const existingIds = [];
        racksSnap.forEach(doc => {
            existingIds.push(doc.id);
            batch.update(doc.ref, { occupied: 0 });
        });
        
        // Count all stored parcels
        const parcelsSnap = await db.collection('parcels').where('status', '==', 'stored').get();
        const counts = {};
        parcelsSnap.forEach(doc => {
            const rack = doc.data().rack;
            if (rack) {
                counts[rack] = (counts[rack] || 0) + 1;
            }
        });
        
        // Update racks
        for (const [rackId, count] of Object.entries(counts)) {
            // Re-apply prefix when looking up the rack document
            batch.update(db.collection('racks').doc(`rack_${rackId}`), { occupied: count });
        }
        
        await batch.commit();
        res.send(`Fixed occupancies: ${JSON.stringify(counts)}. Found IDs: ${existingIds.join(', ')}`);
    } catch (e) {
        res.send(`Error: ${e.message}`);
    }
});


exports.checkAndSendReminders = functions.pubsub.schedule('every 2 minutes').onRun(async (context) => {
    const db = getFirestore();
    const parcelsSnap = await db.collection('parcels').where('status', '==', 'stored').get();
    
    const now = Date.now();
    let intervalMinutes = 10;
    
    try {
        const settingsDoc = await db.collection('settings').doc('general').get();
        if (settingsDoc.exists && settingsDoc.data().reminderIntervalMinutes) {
            intervalMinutes = Math.max(1, settingsDoc.data().reminderIntervalMinutes); // Minimum 1 minute
        }
    } catch (err) {
        console.error("Error fetching settings: ", err);
    }
    
    const intervalInMillis = intervalMinutes * 60 * 1000;
    
    let emailsSent = 0;

    for (const doc of parcelsSnap.docs) {
        const parcel = doc.data();
        
        const lastSentMillis = parcel.lastReminderSentAt 
            ? parcel.lastReminderSentAt.toMillis() 
            : (parcel.receivedAt ? parcel.receivedAt.toMillis() : 0);
            
        if (lastSentMillis === 0) continue; // No receivedAt timestamp
        
        if ((now - lastSentMillis) >= intervalInMillis) {
            // It has been 10+ minutes since last reminder (or since received)
            
            // Get student info for email
            const studentDoc = await db.collection('students').doc(parcel.studentUid).get();
            if (!studentDoc.exists) continue;
            
            const student = studentDoc.data();
            if (!student.email) continue;
            
            // Format the arrival time
            const arrivalTime = parcel.receivedAt ? parcel.receivedAt.toDate().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', dateStyle: 'medium', timeStyle: 'short' }) : 'recently';

            // Send email by creating a document in the 'emails' collection
            await db.collection('emails').add({
                to: student.email,
                subject: 'Parcel Reminder',
                html: `Dear ${student.name},<br><br>You can pickup your parcel using the OTP <b>${parcel.pin}</b> from Gate 1 as soon as possible. It has been waiting for you since ${arrivalTime}.<br><br>Thank You,<br>Team Argo`,
                text: `Dear ${student.name},\n\nYou can pickup your parcel using the OTP ${parcel.pin} from Gate 1 as soon as possible. It has been waiting for you since ${arrivalTime}.\n\nThank You,\nTeam Argo`,
                createdAt: Timestamp.now(),
                type: 'reminder'
            });
            
            // Update lastReminderSentAt
            await db.collection('parcels').doc(doc.id).update({
                lastReminderSentAt: Timestamp.now()
            });
            
            emailsSent++;
        }
    }
    
    console.log(`Sent ${emailsSent} reminder emails.`);
    return null;
});

exports.onboardStudent = functions.https.onCall(async (data, context) => {
    // We don't enforce context.auth here because this is for the guard tablet app
    // which might use a shared session or anon auth. In a real app, enforce auth.

    const { uid, name, email, faceEmbedding } = data;

    if (!uid || !name || !email || !faceEmbedding) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Missing required fields (uid, name, email, or faceEmbedding).'
        );
    }

    try {
        await db.collection('students').doc(uid).set({
            uid: uid,
            name: name,
            email: email,
            faceEmbedding: faceEmbedding,
            createdAt: FieldValue.serverTimestamp()
        });

        return { success: true };
    } catch (error) {
        console.error('Error onboarding student:', error);
        throw new functions.https.HttpsError('internal', 'Failed to onboard student.');
    }
});
