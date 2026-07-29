import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'parcel_recorded_screen.dart';

class ParcelDetailsScreen extends StatefulWidget {
  final Map<dynamic, dynamic> initialData;
  final bool hasError;

  const ParcelDetailsScreen({
    super.key,
    this.initialData = const {},
    this.hasError = false,
  });

  @override
  State<ParcelDetailsScreen> createState() => _ParcelDetailsScreenState();
}

class _ParcelDetailsScreenState extends State<ParcelDetailsScreen> {
  late TextEditingController _serviceController;
  late TextEditingController _recipientController;
  late TextEditingController _trackingController;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _serviceController = TextEditingController(text: widget.initialData['deliveryService'] ?? '');
    _recipientController = TextEditingController(text: widget.initialData['recipientName'] ?? '');
    _trackingController = TextEditingController(text: widget.initialData['trackingNumber'] ?? '');
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _recipientController.dispose();
    _trackingController.dispose();
    super.dispose();
  }

  Future<void> _storeParcel() async {
    if (_serviceController.text.isEmpty || _recipientController.text.isEmpty || _trackingController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1. Call assignRack to get a tentative rack assignment
      final rackResult = await FirebaseFunctions.instance.httpsCallable('assignRack').call();
      final rackAssignment = rackResult.data['rack'] as String;

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Navigate to confirmation screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ParcelRecordedScreen(
            deliveryService: _serviceController.text,
            recipientName: _recipientController.text,
            trackingNumber: _trackingController.text,
            assignedRack: rackAssignment,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign rack: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Parcel Details', style: TextStyle(color: AppColors.textOnPrimary)),
        leading: const BackButton(color: AppColors.textOnPrimary),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.hasError) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.error_outline, color: AppColors.error),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Label scan failed or was unreadable. Please enter details manually.',
                              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  const Text(
                    'Delivery Service',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _serviceController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      hintText: 'e.g. Amazon, FedEx, USPS',
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Recipient Name',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _recipientController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      hintText: 'e.g. John Doe',
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Tracking Number',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _trackingController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      hintText: 'Enter alphanumeric tracking number',
                    ),
                  ),
                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _storeParcel,
                      child: const Text(
                        'Store Parcel',
                        style: TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
