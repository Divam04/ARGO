import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io';
import '../services/face_recognition_service.dart';
import 'manual_verification_screen.dart';
import 'parcel_handed_over_screen.dart';

class FaceScanScreen extends StatefulWidget {
  final Map<String, dynamic> parcelData;
  final DocumentSnapshot receiverDoc;
  final bool isOwner;

  const FaceScanScreen({
    Key? key,
    required this.parcelData,
    required this.receiverDoc,
    required this.isOwner,
  }) : super(key: key);

  @override
  _FaceScanScreenState createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  CameraController? _controller;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  bool _isProcessing = false;
  Timer? _timeoutTimer;
  Timer? _captureTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _faceService.init();

    // 10 second timeout -> fallback to Manual Verification
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      _fallbackToManual();
    });
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(frontCamera, ResolutionPreset.medium);
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});

    _captureLoop();
  }

  void _captureLoop() {
    _captureTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (_isProcessing || !mounted) return;
      await _captureAndVerify();
    });
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    setState(() => _isProcessing = true);
    try {
      final xFile = await _controller!.takePicture();
      final file = File(xFile.path);

      final liveEmbedding = await _faceService.extractEmbedding(file);
      if (liveEmbedding != null) {
        // Compare with stored embedding
        final receiverData = widget.receiverDoc.data() as Map<String, dynamic>;
        final storedEmbeddingDynamic = receiverData['faceEmbedding'];
        
        if (storedEmbeddingDynamic == null) {
          // No enrolled face -> Manual
          _fallbackToManual();
          return;
        }

        final storedEmbedding = (storedEmbeddingDynamic as List).cast<double>().toList();
        final score = _faceService.cosineSimilarity(liveEmbedding, storedEmbedding);
        print('Face Match Score: $score');

        // Assuming threshold 0.36
        if (score > 0.36) {
          _onMatchSuccess(score);
          return;
        }
      }
    } catch (e) {
      print('Camera capture error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _onMatchSuccess(double score) {
    _captureTimer?.cancel();
    _timeoutTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelHandedOverScreen(
          parcelData: widget.parcelData,
          receiverDoc: widget.receiverDoc,
          isOwner: widget.isOwner,
          verificationMethod: 'face',
          faceMatchScore: score,
        ),
      ),
    );
  }

  void _fallbackToManual() {
    _captureTimer?.cancel();
    _timeoutTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ManualVerificationScreen(
          parcelData: widget.parcelData,
          receiverDoc: widget.receiverDoc,
          isOwner: widget.isOwner,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceService.dispose();
    _captureTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            CameraPreview(_controller!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          
          // Oval framing guide
          Center(
            child: Container(
              width: 300,
              height: 400,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 4),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ),
          
          if (_isProcessing)
            const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Analyzing Face...', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
