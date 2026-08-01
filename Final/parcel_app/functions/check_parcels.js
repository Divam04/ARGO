const { getFirestore } = require('firebase-admin/firestore');
const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'argo-parcel-app-backend' });
const db = getFirestore();
async function check() {
    const snap = await db.collection('parcels').get();
    console.log("Total parcels right now:", snap.size);
}
check().then(()=>process.exit(0)).catch(console.error);
