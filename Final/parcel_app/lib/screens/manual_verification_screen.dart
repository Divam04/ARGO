import 'package:flutter/material.dart';
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
  State<ManualVerificationScreen> createState() => _ManualVerificationScreenState();
}

class _ManualVerificationScreenState extends State<ManualVerificationScreen> {

  void _verifyAndProceed() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelHandedOverScreen(
          parcelData: widget.parcelData,
          receiverDoc: widget.receiverDoc,
          isOwner: widget.isOwner,
          verificationMethod: 'manual_guard',
          faceMatchScore: null,
        ),
      ),
    );
  }

  void _reject() {
    // Just pop back to the previous screen (e.g. Receiver Search)
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final receiverData = widget.receiverDoc.data() as Map<String, dynamic>? ?? {};
    final studentName = receiverData['name'] ?? 'Unknown Student';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('MANUAL VERIFICATION'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Image.asset(
              'assets/faces/${widget.receiverDoc.id}.jpeg',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Text(
                  'Could not load student photo from local assets.',
                  style: TextStyle(color: Colors.red, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please visually verify that the student matches the database photo above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _reject,
                        child: const Text('REJECT', style: TextStyle(fontSize: 18, color: Colors.white)),
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
