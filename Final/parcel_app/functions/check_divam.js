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
            matches.push({ id: doc.id, ...data });
        }
    });
    console.log("Matched students:", JSON.stringify(matches, null, 2));

    console.log("\nChecking for parcels for these UIDs...");
    for (const s of matches) {
        const parcelsSnap = await db.collection('parcels').where('studentUid', '==', s.id).get();
        const pList = [];
        parcelsSnap.forEach(doc => pList.push({ id: doc.id, ...doc.data() }));
        console.log(`Parcels for ${s.id}:`, JSON.stringify(pList, null, 2));
    }

    console.log("\nChecking for ANY parcels with 'divam' in recipientName or studentName...");
    const allParcels = await db.collection('parcels').get();
    const matchedParcels = [];
    allParcels.forEach(doc => {
        const d = doc.data();
        const rec = (d.recipientName || '').toLowerCase();
        const stu = (d.studentName || '').toLowerCase();
        if (rec.includes('divam') || stu.includes('divam')) {
            matchedParcels.push({ id: doc.id, ...d });
        }
    });
    console.log("Matched parcels by name:", JSON.stringify(matchedParcels, null, 2));
}

run().then(() => process.exit(0)).catch(e => {
    console.error(e);
    process.exit(1);
});
