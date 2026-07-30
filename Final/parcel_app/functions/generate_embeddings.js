const ort = require('onnxruntime-node');
const Jimp = require('jimp');
const fs = require('fs');
const path = require('path');
const { getFirestore } = require('firebase-admin/firestore');
const admin = require('firebase-admin');

admin.initializeApp({
    projectId: 'argo-parcel-app-backend'
});
const db = getFirestore();

async function extractEmbedding(imagePath, session) {
    // 1. Read and resize image
    const image = await Jimp.read(imagePath);
    // Ideally we would do ML Kit face detection crop here, but we will assume these are already headshots
    // We crop centrally just in case to mimic a face crop
    const size = Math.min(image.bitmap.width, image.bitmap.height);
    const x = (image.bitmap.width - size) / 2;
    const y = (image.bitmap.height - size) / 2;
    image.crop(x, y, size, size);
    image.resize(112, 112);

    // 2. Prepare tensor (1, 3, 112, 112)
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

    // 3. Inference
    const results = await session.run(feeds);
    const outputName = session.outputNames[0];
    const outputTensor = results[outputName];
    return Array.from(outputTensor.data);
}

async function run() {
    console.log('Loading ONNX model...');
    const modelPath = path.join(__dirname, '..', 'assets', 'mobilefacenet.onnx');
    const session = await ort.InferenceSession.create(modelPath);

    const facesDir = path.join(__dirname, '..', '..', 'student_database', 'faces');
    const files = fs.readdirSync(facesDir);
    
    let processed = 0;
    for (const file of files) {
        if (!file.endsWith('.jpeg') && !file.endsWith('.jpg') && !file.endsWith('.png')) continue;
        const uid = file.split('.')[0]; // e.g. U20230101
        
        try {
            console.log(`Processing ${uid}...`);
            const embedding = await extractEmbedding(path.join(facesDir, file), session);
            
            // Save to firestore
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

run().then(() => process.exit(0)).catch(e => {
    console.error(e);
    process.exit(1);
});
