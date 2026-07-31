const { getFirestore } = require('firebase-admin/firestore');
const admin = require('firebase-admin');

admin.initializeApp({
    projectId: 'argo-parcel-app-backend'
});

const db = getFirestore();

async function resetDB() {
    console.log("Resetting database...");
    
    // 1. Delete all parcels
    console.log("Deleting all parcels...");
    const parcelsSnap = await db.collection('parcels').get();
    let batch = db.batch();
    let count = 0;
    for (const doc of parcelsSnap.docs) {
        batch.delete(doc.ref);
        count++;
        if (count % 400 === 0) {
            await batch.commit();
            batch = db.batch();
        }
    }
    await batch.commit();
    console.log(`Deleted ${count} parcels.`);

    // 2. Delete all emails
    console.log("Deleting all emails...");
    const emailsSnap = await db.collection('emails').get();
    batch = db.batch();
    count = 0;
    for (const doc of emailsSnap.docs) {
        batch.delete(doc.ref);
        count++;
        if (count % 400 === 0) {
            await batch.commit();
            batch = db.batch();
        }
    }
    await batch.commit();
    console.log(`Deleted ${count} emails.`);

    // 3. Reset students parcelsWaiting to 0
    console.log("Resetting students parcelsWaiting...");
    const studentsSnap = await db.collection('students').get();
    batch = db.batch();
    count = 0;
    for (const doc of studentsSnap.docs) {
        batch.update(doc.ref, { parcelsWaiting: 0 });
        count++;
        if (count % 400 === 0) {
            await batch.commit();
            batch = db.batch();
        }
    }
    await batch.commit();
    console.log(`Reset ${count} students.`);

    console.log("Database reset complete!");
}

resetDB().catch(console.error);
