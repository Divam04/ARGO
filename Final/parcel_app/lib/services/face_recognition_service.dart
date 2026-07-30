import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

class FaceRecognitionService {
  late OrtSession _session;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    OrtEnv.instance.init();
    
    // Copy model from assets to app directory (onnxruntime needs a file path usually, or byte buffer)
    final byteData = await rootBundle.load('assets/mobilefacenet.onnx');
    final bytes = byteData.buffer.asUint8List();
    
    // Create session from memory
    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromBuffer(bytes, sessionOptions);
    
    _initialized = true;
  }

  void dispose() {
    _session.release();
    OrtEnv.instance.release();
    _faceDetector.close();
  }

  Future<List<double>?> extractEmbedding(File imageFile) async {
    if (!_initialized) await init();

    // 1. Detect Face using ML Kit
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      print('No face detected');
      return null;
    }
    
    // We only process the first face found
    final face = faces.first;
    final boundingBox = face.boundingBox;

    // 2. Load and crop the image
    final imageBytes = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(imageBytes);
    
    if (decodedImage == null) {
      print('Failed to decode image');
      return null;
    }

    // Crop to bounding box
    var croppedFace = img.copyCrop(
      decodedImage,
      x: boundingBox.left.toInt(),
      y: boundingBox.top.toInt(),
      width: boundingBox.width.toInt(),
      height: boundingBox.height.toInt(),
    );

    // Resize to 112x112 as expected by MobileFaceNet
    var resizedFace = img.copyResize(croppedFace, width: 112, height: 112);

    // 3. Prepare input tensor (1, 3, 112, 112) normalized
    final tensorData = Float32List(1 * 3 * 112 * 112);
    int index = 0;
    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        final pixel = resizedFace.getPixel(x, y);
        // Normalize (this depends on the specific model, typical is (val - 127.5)/128.0 or /255.0)
        // MobileFaceNet is typically (val - 127.5) / 128.0
        final r = (pixel.r - 127.5) / 128.0;
        final g = (pixel.g - 127.5) / 128.0;
        final b = (pixel.b - 127.5) / 128.0;

        // ONNX expects NCHW (batch, channel, height, width)
        tensorData[index] = r; // R channel
        tensorData[112 * 112 + index] = g; // G channel
        tensorData[2 * 112 * 112 + index] = b; // B channel
        index++;
      }
    }

    // 4. Run Inference
    final shape = [1, 3, 112, 112];
    final inputOrt = OrtValueTensor.createTensorWithDataList(tensorData, shape);
    
    final runOptions = OrtRunOptions();
    
    try {
      final inputName = _session.inputNames[0];
      final inputs = {inputName: inputOrt};

      final outputs = _session.run(runOptions, inputs);
      
      if (outputs.isEmpty) return null;
      
      final outputOrt = outputs.first;
      // ONNX output is usually a multidimensional array or flat list.
      // We know mobilefacenet outputs [1, 512].
      final embeddingList = (outputOrt?.value as List?) ?? [];
      List<double> embedding = [];
      if (embeddingList.isNotEmpty && embeddingList[0] is List) {
         embedding = (embeddingList[0] as List).cast<double>().toList();
      } else {
         embedding = embeddingList.cast<double>().toList();
      }
      
      // Cleanup
      inputOrt.release();
      runOptions.release();
      for (var out in outputs) {
        out?.release();
      }

      return embedding;
    } catch (e) {
      print('ONNX Inference Error: $e');
      inputOrt.release();
      runOptions.release();
      return null;
    }
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
