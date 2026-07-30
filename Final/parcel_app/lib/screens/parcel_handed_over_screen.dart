import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/guard_session.dart';

class ParcelHandedOverScreen extends StatefulWidget {
  final Map<String, dynamic> parcelData;
  final DocumentSnapshot receiverDoc;
  final bool isOwner;
  final String verificationMethod;
  final double? faceMatchScore;

  const ParcelHandedOverScreen({
    Key? key,
    required this.parcelData,
    required this.receiverDoc,
    required this.isOwner,
    required this.verificationMethod,
    this.faceMatchScore,
  }) : super(key: key);

  @override
  _ParcelHandedOverScreenState createState() => _ParcelHandedOverScreenState();
}

class _ParcelHandedOverScreenState extends State<ParcelHandedOverScreen> {
  bool _isProcessing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _completeHandover();
  }

  Future<void> _completeHandover() async {
    try {
      final guardId = GuardSession.currentGuardId ?? 'unknown';
      final receiverData = widget.receiverDoc.data() as Map<String, dynamic>;
      
      await FirebaseFunctions.instance.httpsCallable('completeHandover').call({
        'parcelId': widget.parcelData['id'],
        'receiverUid': receiverData['uid'],
        'receiverName': receiverData['name'],
        'isOwner': widget.isOwner,
        'verificationMethod': widget.verificationMethod,
        'faceMatchScore': widget.faceMatchScore,
        'guardId': guardId,
      });

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Failed to complete handover: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isProcessing
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text('Completing Handover...', style: TextStyle(fontSize: 18)),
                  ],
                )
              : _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 64),
                        const SizedBox(height: 24),
                        Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          child: const Text('Return to Home'),
                        )
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Color(0xFF2E7D32), size: 64),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'PARCEL HANDED OVER',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 32),
                        _buildInfoRow('RECEIVER', (widget.receiverDoc.data() as Map)['name']),
                        if (!widget.isOwner) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Notice: Receiver is different from the owner (${widget.parcelData['recipientName']})',
                                    style: TextStyle(color: Colors.orange.shade900),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            child: const Text('DONE', style: TextStyle(fontSize: 18, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
