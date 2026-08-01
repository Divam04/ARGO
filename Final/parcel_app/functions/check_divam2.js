const { getFirestore } = require('firebase-admin/firestore');
const admin = require('firebase-admin');

admin.initializeApp({
    projectId: 'argo-parcel-app-backend'
});

const db = getFirestore();

async function run() {
    console.log("Checking for 'Divam' in students...");
    const studentsSnap = await db.collection('students').get();
    const matches = [];
    studentsSnap.forEach(doc => {
        const data = doc.data();
        if (data.name && data.name.toLowerCase().includes('divam')) {
            matches.push({ id: doc.id, uid: data.uid, name: data.name });
        }
    });
    console.log("Matched students:", JSON.stringify(matches, null, 2));

    console.log("\nChecking for stored parcels for 'Divam'...");
    const parcelsSnap = await db.collection('parcels').where('status', '==', 'stored').get();
    const pList = [];
    parcelsSnap.forEach(doc => {
        const d = doc.data();
        if (d.studentName && d.studentName.toLowerCase().includes('divam')) {
            pList.push({ id: doc.id, studentUid: d.studentUid, name: d.studentName });
        }
    });
    console.log("Stored parcels:", JSON.stringify(pList, null, 2));
}

run().then(() => process.exit(0)).catch(e => {
    console.error(e);
    process.exit(1);
});
