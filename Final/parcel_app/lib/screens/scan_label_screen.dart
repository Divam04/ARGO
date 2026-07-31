import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_colors.dart';
import 'parcel_details_screen.dart';

class ScanLabelScreen extends StatefulWidget {
  const ScanLabelScreen({super.key});

  @override
  State<ScanLabelScreen> createState() => _ScanLabelScreenState();
}

class _ScanLabelScreenState extends State<ScanLabelScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  Future<void> _captureAndProcess() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return; // User cancelled

      setState(() => _isProcessing = true);

      // Convert to base64
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Call Cloud Function
      final result = await FirebaseFunctions.instance.httpsCallable('scanLabel').call({
        'image': base64Image,
      });

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final extractedData = result.data['data'] as Map<dynamic, dynamic>;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ParcelDetailsScreen(initialData: extractedData),
        ),
      );
    } catch (e) {
      print('CLOUD FUNCTION ERROR: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      
      // Navigate to blank details screen with error state
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ParcelDetailsScreen(
            initialData: const {},
            hasError: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Scan Label', style: TextStyle(color: AppColors.textOnPrimary)),
        leading: const BackButton(color: AppColors.textOnPrimary),
      ),
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Lottie.asset('assets/cart_loading.json'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Processing parcel...',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.document_scanner_rounded,
                      size: 120,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Ready to Scan',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Center the shipping label in the frame to automatically extract delivery details.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _captureAndProcess,
                        icon: const Icon(Icons.camera_alt, color: AppColors.textOnPrimary, size: 28),
                        label: const Text(
                          'Open Camera',
                          style: TextStyle(
                            color: AppColors.textOnPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        label: const Text(
                          'RETURN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
