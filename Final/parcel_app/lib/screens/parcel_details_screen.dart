import 'package:flutter/material.dart';
import 'dart:async';
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
  Timer? _debounce;

  bool _isProcessing = false;
  bool _isResolvingOnLoad = false;
  bool _showInlineDropdown = false;
  String? _selectedUid;
  String? _selectedName;
  List<dynamic>? _dropdownCandidates;

  @override
  void initState() {
    super.initState();
    String trackingNum = widget.initialData['trackingNumber'] ?? '';
    if (trackingNum.toUpperCase().startsWith('AWB')) {
      trackingNum = trackingNum.substring(3).trimLeft();
    }

    _serviceController = TextEditingController(text: widget.initialData['deliveryService'] ?? '');
    _recipientController = TextEditingController(text: widget.initialData['recipientName'] ?? '');
    _trackingController = TextEditingController(text: trackingNum);

    _recipientController.addListener(() {
      if (_selectedUid != null && _recipientController.text != _selectedName) {
        _selectedUid = null;
        _selectedName = null;
      }
      
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (_recipientController.text.isNotEmpty && _recipientController.text != _selectedName) {
          _resolveLiveStudent();
        } else if (_recipientController.text.isEmpty) {
          setState(() {
            _showInlineDropdown = false;
            _dropdownCandidates = null;
          });
        }
      });
    });

    if (_recipientController.text.isNotEmpty) {
      _resolveInitialStudent();
    }
  }

  Future<void> _resolveLiveStudent() async {
    final name = _recipientController.text;
    if (name.isEmpty) return;

    setState(() => _isResolvingOnLoad = true);
    try {
      final resolveResult = await FirebaseFunctions.instance.httpsCallable('resolveStudentMatch').call({
        'recipientName': name,
      });
      
      if (!mounted) return;
      if (_recipientController.text != name) return; // Stale result

      final bool exact = resolveResult.data['exact'] as bool;
      final List candidates = resolveResult.data['candidates'] as List;

      if (!exact && candidates.isEmpty) {
        setState(() {
          _isResolvingOnLoad = false;
          _showInlineDropdown = false;
          _dropdownCandidates = null;
        });
        return;
      }

      if (exact && candidates.isNotEmpty) {
        setState(() {
          _selectedUid = candidates[0]['uid'];
          _selectedName = candidates[0]['name'];
          _recipientController.text = _selectedName!;
          _isResolvingOnLoad = false;
          _showInlineDropdown = false;
        });
      } else {
        setState(() {
          _dropdownCandidates = candidates;
          _isResolvingOnLoad = false;
          _showInlineDropdown = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isResolvingOnLoad = false);
    }
  }

  Future<void> _resolveInitialStudent() async {
    final name = _recipientController.text;
    if (name.isEmpty) return;

    setState(() => _isResolvingOnLoad = true);
    try {
      final resolveResult = await FirebaseFunctions.instance.httpsCallable('resolveStudentMatch').call({
        'recipientName': name,
      });
      final bool exact = resolveResult.data['exact'] as bool;
      final List candidates = resolveResult.data['candidates'] as List;

      if (!mounted) return;

      if (!exact && candidates.isEmpty) {
        setState(() {
          _isResolvingOnLoad = false;
          _recipientController.text = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User Not Found'), backgroundColor: AppColors.error),
        );
        return;
      }

      if (exact && candidates.isNotEmpty) {
        setState(() {
          _selectedUid = candidates[0]['uid'];
          _selectedName = candidates[0]['name'];
          _isResolvingOnLoad = false;
        });
      } else {
        setState(() {
          _dropdownCandidates = candidates;
          _isResolvingOnLoad = false;
          _showInlineDropdown = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isResolvingOnLoad = false);
    }
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
      if (_selectedUid == null) {
        // 1. Resolve Student
        final resolveResult = await FirebaseFunctions.instance.httpsCallable('resolveStudentMatch').call({
          'recipientName': _recipientController.text,
        });
        final bool exact = resolveResult.data['exact'] as bool;
        final List candidates = resolveResult.data['candidates'] as List;

        if (!exact && candidates.isEmpty) {
          // Direct no-match -> throw User Not Found immediately
          if (!mounted) return;
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User Not Found'), backgroundColor: AppColors.error),
          );
          return;
        }

        if (exact && candidates.isNotEmpty) {
          _selectedUid = candidates[0]['uid'];
          _selectedName = candidates[0]['name'];
        } else {
          // Fuzzy matches -> show dropdown menu in the field box
          if (!mounted) return;
          setState(() {
            _dropdownCandidates = candidates;
            _isProcessing = false;
            _showInlineDropdown = true;
          });
          return; // Wait for user to select from dropdown
        }
      }

      // 2. Assign Rack
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
            studentUid: _selectedUid!,
            studentName: _selectedName!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      String errorMsg = 'Failed to assign rack: $e';
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

  Widget _buildDropdownItem({required String title, String? subtitle, Color? titleColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: titleColor ?? AppColors.textPrimary, fontSize: 16)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]
          ],
        ),
      ),
    );
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
                      hintText: 'e.g. Amazon, Flipkart, Myntra',
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
                    readOnly: _showInlineDropdown,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), 
                        borderSide: _showInlineDropdown ? const BorderSide(color: AppColors.primary, width: 2) : BorderSide.none
                      ),
                      hintText: 'e.g. John Doe',
                      suffixIcon: _isResolvingOnLoad 
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : _showInlineDropdown 
                              ? const Icon(Icons.arrow_drop_down, color: AppColors.primary) 
                              : null,
                    ),
                  ),
                  if (_showInlineDropdown && _dropdownCandidates != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          ..._dropdownCandidates!.map((c) => _buildDropdownItem(
                             title: c['name'],
                             subtitle: 'UID: ${c['uid']}',
                             onTap: () {
                                setState(() {
                                  _selectedUid = c['uid'];
                                  _selectedName = c['name'];
                                  _recipientController.text = c['name'];
                                  _showInlineDropdown = false;
                                  _dropdownCandidates = null;
                                });
                                _storeParcel();
                             }
                          )),
                          _buildDropdownItem(
                             title: 'None of the Above',
                             titleColor: AppColors.error,
                             onTap: () {
                                Navigator.popUntil(context, (route) => route.isFirst);
                             }
                          ),
                        ]
                      )
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
