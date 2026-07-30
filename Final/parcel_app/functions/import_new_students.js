const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const ort = require('onnxruntime-node');
const Jimp = require('jimp');

admin.initializeApp({
    projectId: 'argo-parcel-app-backend',
    storageBucket: 'argo-parcel-app-backend.firebasestorage.app'
});

const db = getFirestore();
const bucket = getStorage().bucket();

async function extractEmbedding(imagePath, session) {
    const image = await Jimp.read(imagePath);
    const size = Math.min(image.bitmap.width, image.bitmap.height);
    const x = (image.bitmap.width - size) / 2;
    const y = (image.bitmap.height - size) / 2;
    image.crop(x, y, size, size);
    image.resize(112, 112);

    const float32Data = new Float32Array(1 * 3 * 112 * 112);
    let index = 0;
    for (let h = 0; h < 112; h++) {
        for (let w = 0; w < 112; w++) {
            const hex = image.getPixelColor(w, h);
            const rgba = Jimp.intToRGBA(hex);
            float32Data[index] = (rgba.r - 127.5) / 128.0;
            float32Data[112 * 112 + index] = (rgba.g - 127.5) / 128.0;
            float32Data[2 * 112 * 112 + index] = (rgba.b - 127.5) / 128.0;
            index++;
        }
    }

    const inputTensor = new ort.Tensor('float32', float32Data, [1, 3, 112, 112]);
    const feeds = {};
    feeds[session.inputNames[0]] = inputTensor;

    const results = await session.run(feeds);
    const outputName = session.outputNames[0];
    const outputTensor = results[outputName];
    return Array.from(outputTensor.data);
}

async function run() {
    console.log("Reading students_new.json...");
    const jsonPath = path.join(__dirname, '..', '..', 'student_database_new', 'students_new.json');
    const studentsData = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

    console.log("Uploading new students (skipping deletion)...");
    let addedCount = 0;
    for (const s of studentsData) {
        if (!s.uid) continue;
        const docRef = db.collection('students').doc(s.uid);
        await docRef.set({
            uid: s.uid,
            name: s.name || '',
            nameLower: (s.name || '').toLowerCase(),
            email: s.mail || s.email || '',
            isActive: true,
            parcelsWaiting: 0
        }, { merge: true }); // Use merge to update existing without overwriting all fields
        addedCount++;
    }
    console.log(`Added/Updated ${addedCount} student records in Firestore.`);

    console.log("Uploading faces to Storage...");
    const facesDir = path.join(__dirname, '..', '..', 'student_database_new'); // Assuming images are in the root of the new folder
    const files = fs.readdirSync(facesDir);
    let uploadedCount = 0;
    for (const file of files) {
        if (!file.endsWith('.jpeg') && !file.endsWith('.jpg') && !file.endsWith('.png')) continue;
        const filePath = path.join(facesDir, file);
        const destination = `faces/${file}`;
        await bucket.upload(filePath, {
            destination: destination,
            metadata: {
                contentType: 'image/jpeg',
            }
        });
        uploadedCount++;
    }
    console.log(`Uploaded ${uploadedCount} photos to Firebase Storage.`);

    console.log('Loading ONNX model for embeddings...');
    const modelPath = path.join(__dirname, '..', 'assets', 'mobilefacenet.onnx');
    const session = await ort.InferenceSession.create(modelPath);
    
    let processed = 0;
    for (const file of files) {
        if (!file.endsWith('.jpeg') && !file.endsWith('.jpg') && !file.endsWith('.png')) continue;
        const uid = file.split('.')[0]; 
        
        try {
            console.log(`Processing face embedding for ${uid}...`);
            const embedding = await extractEmbedding(path.join(facesDir, file), session);
            
            await db.collection('students').doc(uid).update({
                faceEmbedding: embedding
            });
            processed++;
        } catch (e) {
            console.error(`Failed to process ${uid}:`, e);
        }
    }
    console.log(`Successfully generated and saved embeddings for ${processed} students.`);
}

run().then(() => {
    console.log("All done!");
    process.exit(0);
}).catch(e => {
    console.error(e);
    process.exit(1);
});
