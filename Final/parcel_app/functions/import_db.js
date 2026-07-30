const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

admin.initializeApp({
    projectId: 'argo-parcel-app-backend',
    storageBucket: 'argo-parcel-app-backend.firebasestorage.app'
});

const db = getFirestore();
const bucket = getStorage().bucket();

async function run() {
    console.log("Reading students.json...");
    const jsonPath = path.join(__dirname, '..', '..', 'student_database', 'students.json');
    const studentsData = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

    console.log("Deleting old students...");
    const oldStudents = await db.collection('students').get();
    const batch = db.batch();
    oldStudents.forEach(doc => {
        batch.delete(doc.ref);
    });
    await batch.commit();
    console.log(`Deleted ${oldStudents.size} old records.`);

    console.log("Uploading new students...");
    let addedCount = 0;
    for (const s of studentsData) {
        if (!s.uid) continue;
        const docRef = db.collection('students').doc(s.uid);
        await docRef.set({
            uid: s.uid,
            name: s.name || '',
            nameLower: (s.name || '').toLowerCase(),
            email: s.mail || '',
            isActive: true,
            parcelsWaiting: 0
        });
        addedCount++;
    }
    console.log(`Added ${addedCount} student records to Firestore.`);

    console.log("Uploading faces to Storage...");
    const facesDir = path.join(__dirname, '..', '..', 'student_database', 'faces');
    const files = fs.readdirSync(facesDir);
    let uploadedCount = 0;
    for (const file of files) {
        if (!file.endsWith('.jpeg') && !file.endsWith('.jpg') && !file.endsWith('.png')) continue;
        const filePath = path.join(facesDir, file);
        const destination = `faces/${file}`;
        await bucket.upload(filePath, {
            destination: destination,
            metadata: {
                contentType: 'image/jpeg',
            }
        });
        uploadedCount++;
    }
    console.log(`Uploaded ${uploadedCount} photos to Firebase Storage.`);
}

run().then(() => {
    console.log("All done!");
    process.exit(0);
}).catch(e => {
    console.error(e);
    process.exit(1);
});
