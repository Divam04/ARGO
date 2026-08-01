const { getFirestore } = require('firebase-admin/firestore');
const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'argo-parcel-app-backend' });
const db = getFirestore();

async function check() {
    const parcelsSnap = await db.collection('parcels').get();
    let total = 0, collected = 0, stored = 0, unmatched = 0;
    parcelsSnap.forEach(doc => {
        total++;
        const p = doc.data();
        if (!p.studentUid) unmatched++;
        if (p.status === 'collected') collected++;
        else if (p.status === 'stored') stored++;
    });
    console.log({total, collected, stored, unmatched});
}
check().then(()=>process.exit(0)).catch(console.error);
