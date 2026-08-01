const { getFirestore } = require('firebase-admin/firestore');
const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'argo-parcel-app-backend' });
const db = getFirestore();

async function run() {
    const studentsSnap = await db.collection('students').doc('u20250235').get();
    console.log("Divam's nameLower:", studentsSnap.data().nameLower);
    console.log("Divam's name:", studentsSnap.data().name);
}

run().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
