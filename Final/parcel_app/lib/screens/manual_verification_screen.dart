import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'parcel_handed_over_screen.dart';

class ManualVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> parcelData;
  final DocumentSnapshot receiverDoc;
  final bool isOwner;

  const ManualVerificationScreen({
    Key? key,
    required this.parcelData,
    required this.receiverDoc,
    required this.isOwner,
  }) : super(key: key);

  @override
  _ManualVerificationScreenState createState() => _ManualVerificationScreenState();
}

class _ManualVerificationScreenState extends State<ManualVerificationScreen> {
  CameraController? _controller;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    // For ID capture, we typically want the back camera.
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(backCamera, ResolutionPreset.high);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _captureId() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final image = await _controller!.takePicture();
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      print('Failed to capture ID: $e');
    }
  }

  void _reCapture() {
    setState(() {
      _capturedImage = null;
    });
  }

  void _verifyAndProceed() {
    // In a full implementation, we'd upload `_capturedImage` to Firebase Storage
    // and pass the URL to completeHandover. For now, we skip upload and just proceed.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelHandedOverScreen(
          parcelData: widget.parcelData,
          receiverDoc: widget.receiverDoc,
          isOwner: widget.isOwner,
          verificationMethod: 'manual_id',
          faceMatchScore: null,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('STUDENT ID'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _capturedImage == null
                ? (_controller != null && _controller!.value.isInitialized
                    ? CameraPreview(_controller!)
                    : const Center(child: CircularProgressIndicator()))
                : Image.network(_capturedImage!.path, fit: BoxFit.cover),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_capturedImage == null)
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _captureId,
                      child: const Text('CAPTURE ID', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  )
                else ...[
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _reCapture,
                      child: const Text('RE-SHOT', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _verifyAndProceed,
                      child: const Text('VERIFY', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
