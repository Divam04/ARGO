const { getAuth } = require('firebase-admin/auth');
const admin = require('firebase-admin');

admin.initializeApp({
    projectId: 'argo-parcel-app-backend'
});

async function checkAdmin() {
    try {
        const listUsersResult = await getAuth().listUsers();
        if (listUsersResult.users.length === 0) {
            console.log("No users found in Firebase Auth.");
        } else {
            console.log(`Found ${listUsersResult.users.length} users:`);
            listUsersResult.users.forEach(userRecord => {
                console.log(`- ${userRecord.email} (uid: ${userRecord.uid})`);
            });
        }
    } catch (error) {
        console.error("Error listing users:", error);
    }
}

checkAdmin().then(() => process.exit(0)).catch(() => process.exit(1));
