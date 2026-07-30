const { getFirestore } = require('firebase-admin/firestore');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

admin.initializeApp({
    projectId: 'argo-parcel-app-backend'
});

const db = getFirestore();

async function run() {
    console.log("Reading guards_database.json...");
    const jsonPath = path.join(__dirname, '..', '..', 'guards_database.json');
    const guardsData = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

    console.log("Deleting old guards...");
    const oldGuards = await db.collection('guards').get();
    const batch = db.batch();
    oldGuards.forEach(doc => {
        batch.delete(doc.ref);
    });
    await batch.commit();
    console.log(`Deleted ${oldGuards.size} old records.`);

    console.log("Uploading new guards...");
    let addedCount = 0;
    for (const g of guardsData) {
        if (!g.guard_id) continue;
        const docRef = db.collection('guards').doc(g.guard_id);
        await docRef.set({
            guard_id: g.guard_id,
            name: g.name
        });
        addedCount++;
    }
    console.log(`Added ${addedCount} guard records to Firestore.`);
}

run().then(() => {
    console.log("All done!");
    process.exit(0);
}).catch(e => {
    console.error(e);
    process.exit(1);
});
