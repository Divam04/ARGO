const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'argo-parcel-app-backend' });
const db = getFirestore();

async function revert() {
    console.log("Reverting mass handover...");
    const parcelsSnap = await db.collection('parcels').where('verificationMethod', '==', 'mass_handover').get();
    
    if (parcelsSnap.empty) {
        console.log("No parcels found that were affected by mass_handover. Checking if they used 'guard_override' or something else...");
        const allSnap = await db.collection('parcels').where('status', '==', 'collected').get();
        let found = 0;
        allSnap.forEach(d => {
            if (d.data().collectedByGuardId === 'admin') found++;
        });
        console.log(`Found ${found} collected parcels with guardId='admin'`);
        return;
    }
    
    const batch = db.batch();
    let count = 0;
    
    parcelsSnap.forEach(doc => {
        batch.update(doc.ref, {
            status: 'stored',
            collectedAt: FieldValue.delete(),
            verificationMethod: FieldValue.delete(),
            collectedByGuardId: FieldValue.delete()
        });
        count++;
    });
    
    await batch.commit();
    console.log(`Successfully reverted ${count} parcels back to 'stored'.`);
}

revert().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
