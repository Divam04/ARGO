const { getFirestore } = require('firebase-admin/firestore');
const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'argo-parcel-app-backend' });
const db = getFirestore();

async function run() {
    const nameLower = "divam gupta";
    const candidatesMap = new Map();
    const allStudents = await db.collection('students').get();
    
    const levenshtein = (a, b) => {
        if (a.length === 0) return b.length;
        if (b.length === 0) return a.length;
        const matrix = [];
        for (let i = 0; i <= b.length; i++) matrix[i] = [i];
        for (let j = 0; j <= a.length; j++) matrix[0][j] = j;
        for (let i = 1; i <= b.length; i++) {
            for (let j = 1; j <= a.length; j++) {
                if (b.charAt(i - 1) === a.charAt(j - 1)) {
                    matrix[i][j] = matrix[i - 1][j - 1];
                } else {
                    matrix[i][j] = Math.min(
                        matrix[i - 1][j - 1] + 1,
                        Math.min(matrix[i][j - 1] + 1, matrix[i - 1][j] + 1)
                    );
                }
            }
        }
        return matrix[b.length][a.length];
    };

    for (const doc of allStudents.docs) {
        const studentData = doc.data();
        const studentNameLower = (studentData.name || '').toLowerCase();
        
        let isMatch = false;
        
        if (studentNameLower === nameLower) {
            isMatch = true;
        } else if (studentNameLower.length >= 3 && nameLower.length >= 3) {
            if (studentNameLower.includes(nameLower) || nameLower.includes(studentNameLower)) {
                isMatch = true;
            } else {
                const distance = levenshtein(studentNameLower, nameLower);
                const maxLength = Math.max(studentNameLower.length, nameLower.length);
                if (maxLength > 0) {
                    const similarity = 1 - (distance / maxLength);
                    if (similarity > 0.7) {
                        isMatch = true;
                    }
                }
            }
        } else if (studentNameLower.includes(nameLower)) {
            isMatch = true;
        }
        
        if (isMatch) {
            candidatesMap.set(doc.id, { uid: doc.id, name: studentData.name, email: studentData.email });
        }
    }
    
    console.log("Fuzzy Match Results:", Array.from(candidatesMap.values()));
}

run().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
