const { getFirestore } = require('firebase-admin/firestore');
const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'argo-parcel-app-backend' });
const db = getFirestore();

async function run() {
    const nameLower = "divam gupta";
    const exactSnap = await db.collection('students').where('nameLower', '==', nameLower).get();
    if (!exactSnap.empty && exactSnap.size === 1) {
        console.log("EXACT MATCH DOC ID:", exactSnap.docs[0].id);
    } else {
        console.log("NO EXACT MATCH OR MULTIPLE MATCHES. Size:", exactSnap.size);
    }
}

run().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
