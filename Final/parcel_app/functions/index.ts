import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { parse } from 'csv-parse/sync';

admin.initializeApp();
const db = admin.firestore();

export const importStudents = functions.https.onCall(async (data, context) => {
    // 1. Check if user is authenticated and is an admin
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'You must be signed in to import students.'
        );
    }
    
    // For Phase 1, we will allow anyone signed in to run this (or mock the admin check), 
    // but typically you would check context.auth.token.admin
    // if (!context.auth.token.admin) {
    //    throw new functions.https.HttpsError('permission-denied', 'You must be an admin.');
    // }

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

        // Write in batches of 500 (Firestore limit)
        const batches = [];
        let currentBatch = db.batch();
        let operationCount = 0;

        for (const record of records) {
            // Assume CSV has id, name, room, email, etc.
            // Format to match spec: { uid, name, email, room, isActive }
            const studentRef = db.collection('students').doc(record.uid || record.id || record.email);
            
            const studentData = {
                uid: record.uid || record.id || record.email,
                name: record.name,
                email: record.email,
                room: record.room,
                isActive: true // Default to active on import
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
            error
        );
    }
});
