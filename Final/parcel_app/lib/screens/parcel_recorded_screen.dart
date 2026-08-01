import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/guard_session.dart';

class ParcelRecordedScreen extends StatefulWidget {
  final String deliveryService;
  final String recipientName;
  final String trackingNumber;
  final String assignedRack;
  final String studentUid;
  final String studentName;

  const ParcelRecordedScreen({
    super.key,
    required this.deliveryService,
    required this.recipientName,
    required this.trackingNumber,
    required this.assignedRack,
    required this.studentUid,
    required this.studentName,
  });

  @override
  State<ParcelRecordedScreen> createState() => _ParcelRecordedScreenState();
}

class _ParcelRecordedScreenState extends State<ParcelRecordedScreen> {
  bool _isCommitting = false;

  Future<void> _commitAndFinish() async {
    setState(() => _isCommitting = true);

    try {
      final result = await FirebaseFunctions.instance.httpsCallable('commitParcel').call({
        'deliveryService': widget.deliveryService,
        'recipientName': widget.recipientName,
        'trackingNumber': widget.trackingNumber,
        'rack': widget.assignedRack,
        'guardId': GuardSession.currentGuardId ?? 'unknown',
        'studentUid': widget.studentUid,
      });

      if (!mounted) return;
      
      final sequenceNumber = result.data['sequenceNumber'];

      // Show dialog with sequence number before popping
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Parcel Recorded!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please write this ID on the parcel:', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Text(
                  '#$sequenceNumber (Rack ${widget.assignedRack})',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              const Text('The student has been notified.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('DONE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.popUntil(context, ModalRoute.withName('/home'));
      
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCommitting = false);
      String errorMsg = 'Failed to commit parcel: $e';
      if (e.toString().contains('not-found')) {
        errorMsg = 'User Not Found';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.error,
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
        title: const Text('Store Parcel', style: TextStyle(color: AppColors.textOnPrimary)),
        leading: const BackButton(color: AppColors.textOnPrimary),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_rounded, size: 100, color: AppColors.success),
              const SizedBox(height: 32),
              const Text(
                'Assigned Rack',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  widget.assignedRack,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              _isCommitting
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _commitAndFinish,
                        child: const Text(
                          'DONE',
                          style: TextStyle(
                            color: AppColors.textOnPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
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
