const { getFirestore } = require('firebase-admin/firestore');
const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'argo-parcel-app-backend' });
const db = getFirestore();

async function run() {
    console.log("Fixing orphaned parcels...");
    const parcelsSnap = await db.collection('parcels').get();
    const batch = db.batch();
    let count = 0;
    
    for (const doc of parcelsSnap.docs) {
        const data = doc.data();
        if (data.studentUid && data.studentUid !== data.studentUid.toLowerCase()) {
            const lowerUid = data.studentUid.toLowerCase();
            
            // Check if the lowercase student exists
            const studentSnap = await db.collection('students').doc(lowerUid).get();
            if (studentSnap.exists) {
                // Update the parcel to use the lowercase UID
                batch.update(doc.ref, { studentUid: lowerUid });
                count++;
                console.log(`Updated parcel ${doc.id} from ${data.studentUid} to ${lowerUid}`);
            }
        }
    }
    
    if (count > 0) {
        await batch.commit();
        console.log(`Successfully fixed ${count} parcels.`);
    } else {
        console.log("No parcels needed fixing.");
    }
}

run().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
