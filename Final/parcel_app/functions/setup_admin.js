// setup_admin.js
// Run this script from the terminal to create an admin user in Firebase Auth.
// Usage: node setup_admin.js <email> <password>
// Ensure you have set GOOGLE_APPLICATION_CREDENTIALS in your environment if needed.

const { getAuth } = require('firebase-admin/auth');
const admin = require('firebase-admin');

admin.initializeApp({
    projectId: 'argo-parcel-app-backend'
});

async function createAdmin() {
    const args = process.argv.slice(2);
    if (args.length < 2) {
        console.error("Usage: node setup_admin.js <email> <password>");
        process.exit(1);
    }

    const email = args[0];
    const password = args[1];

    try {
        const userRecord = await getAuth().createUser({
            email: email,
            password: password,
            emailVerified: true,
        });

        // Set custom claims to mark this user as an admin
        await getAuth().setCustomUserClaims(userRecord.uid, { admin: true });

        console.log(`Successfully created new admin user: ${userRecord.uid}`);
    } catch (error) {
        if (error.code === 'auth/email-already-exists') {
            console.log("User already exists. Attempting to grant admin privileges...");
            try {
                const userRecord = await getAuth().getUserByEmail(email);
                await getAuth().setCustomUserClaims(userRecord.uid, { admin: true });
                console.log(`Successfully granted admin privileges to existing user: ${userRecord.uid}`);
            } catch (innerError) {
                console.error("Failed to grant privileges:", innerError);
            }
        } else {
            console.error("Error creating new user:", error);
        }
    }
}

createAdmin().then(() => process.exit(0)).catch(() => process.exit(1));
