import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import '../session.dart';
import '../theme/app_colors.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/face_recognition_service.dart';

import 'scan_label_screen.dart';
import 'parcel_details_screen.dart';
import 'enter_pin_screen.dart';
import 'settings_screen.dart';
import 'onboard_student_screen.dart';
import '../services/guard_session.dart';
import 'receiver_search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  List<DocumentSnapshot> _suggestions = [];
  bool _isSearching = false;
  DocumentSnapshot? _selectedStudent;
  List<DocumentSnapshot> _studentParcels = [];
  bool _isLoadingParcels = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_selectedStudent != null) {
      setState(() {
        _selectedStudent = null;
        _studentParcels = [];
      });
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final qLower = query.toLowerCase();
    
    try {
      final snapshot = await FirebaseFirestore.instance.collection('students').get();
      List<DocumentSnapshot> matched = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name']?.toString() ?? '').toLowerCase();
        final uid = (data['uid']?.toString() ?? doc.id).toLowerCase();
        
        if (uid.contains(qLower) || name.contains(qLower)) {
          matched.add(doc);
        }
      }
      
      if (mounted) {
        setState(() {
          _suggestions = matched.take(5).toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search Error: $e')));
      }
    }
  }

  Future<void> _selectStudent(DocumentSnapshot studentDoc) async {
    _searchFocus.unfocus();
    final data = studentDoc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final uid = data['uid']?.toString() ?? studentDoc.id;
    _searchController.text = '$name ($uid)';
    setState(() {
      _selectedStudent = studentDoc;
      _suggestions = [];
      _isLoadingParcels = true;
    });

    try {
      final parcelsSnap = await FirebaseFirestore.instance
          .collection('parcels')
          .where('studentUid', isEqualTo: studentDoc.id)
          .where('status', isEqualTo: 'stored')
          .get();

      if (mounted) {
        setState(() {
          _studentParcels = parcelsSnap.docs;
          _isLoadingParcels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingParcels = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Parcels Error: $e')));
      }
    }
  }

  Future<void> _handoverParcel(DocumentSnapshot parcelDoc) async {
    final parcelData = Map<String, dynamic>.from(parcelDoc.data() as Map);
    parcelData['id'] = parcelDoc.id;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiverSearchScreen(
          parcelData: parcelData,
          ownerUid: _selectedStudent?.id,
        ),
      ),
    );
  }

  Future<void> _resendEmail(DocumentSnapshot parcelDoc) async {
    final p = parcelDoc.data() as Map<String, dynamic>;
    if (_selectedStudent == null) return;
    final studentData = _selectedStudent!.data() as Map<String, dynamic>;
    final toEmail = studentData['email'];
    if (toEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No email found for student')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final deliveryService = p['deliveryService'] ?? 'Unknown Courier';
      final trackingNumber = p['trackingNumber'] ?? 'N/A';
      final studentName = studentData['name'] ?? 'Student';
      final pin = p['pin'] ?? 'Unknown';

      final text = 'Hello $studentName,\n\nThis is a reminder that your parcel from $deliveryService is waiting at Gate 1.\n\nAWB: $trackingNumber\nCourier: $deliveryService\n\nYour collection PIN is: $pin\n\nPlease collect it at your earliest convenience.';

      final html = '''
      <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #ddd; border-radius: 8px; overflow: hidden;">
          <div style="background-color: #28a745; color: white; padding: 16px; text-align: center;">
              <h2 style="margin: 0;">Parcel Reminder</h2>
          </div>
          <div style="padding: 24px;">
              <p>Hello $studentName,</p>
              <p>This is a reminder that your parcel is waiting at <strong>Gate 1</strong>.</p>
              
              <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
                  <tr style="border-bottom: 1px solid #eee;">
                      <td style="padding: 12px 0; color: #666;"><strong>Courier:</strong></td>
                      <td style="padding: 12px 0; text-align: right;">$deliveryService</td>
                  </tr>
                  <tr style="border-bottom: 1px solid #eee;">
                      <td style="padding: 12px 0; color: #666;"><strong>AWB:</strong></td>
                      <td style="padding: 12px 0; text-align: right;">$trackingNumber</td>
                  </tr>
              </table>
              
              <div style="margin-top: 32px; background-color: #f8f9fa; padding: 16px; text-align: center; border-radius: 8px;">
                  <p style="margin: 0; color: #666; font-size: 14px;">Your Collection PIN</p>
                  <h1 style="margin: 8px 0 0 0; letter-spacing: 4px; color: #0d6efd;">$pin</h1>
              </div>
              
              <p style="margin-top: 24px; color: #666; font-size: 14px; text-align: center;">Please collect it at your earliest convenience.</p>
          </div>
      </div>
      ''';

      await FirebaseFirestore.instance.collection('emails').add({
        'type': 'REMINDER',
        'to': toEmail,
        'subject': 'Reminder: Your parcel from $deliveryService is waiting!',
        'text': text,
        'html': html,
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder email sent successfully!')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send email: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildSearchCard(context),
                      if (_selectedStudent != null) ...[
                        const SizedBox(height: 24),
                        Expanded(child: _buildParcelsList()),
                      ] else ...[
                        const SizedBox(height: 24),
                        _buildActionCard(context),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: AppColors.textOnPrimaryMuted,
                    size: 24,
                  ),
                ),
              ),
              Image.asset(
                'assets/logo.png',
                height: 72,
                fit: BoxFit.contain,
                color: Colors.white,
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/profile');
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentCream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Welcome back,',
            style: TextStyle(
              color: AppColors.textOnPrimaryMuted,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Session.guardName,
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentTeal, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    icon: const Icon(Icons.search, color: AppColors.textSecondary, size: 22),
                    hintText: 'Enter student ID or Name',
                    border: InputBorder.none,
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                    suffixIcon: _selectedStudent != null || _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _selectedStudent = null;
                                _studentParcels = [];
                                _suggestions = [];
                              });
                              _searchFocus.unfocus();
                            },
                          )
                        : null,
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        if (!_isSearching && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: Column(
              children: _suggestions.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
                  title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['uid'] ?? doc.id),
                  onTap: () => _selectStudent(doc),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildParcelsList() {
    if (_isLoadingParcels) return const Center(child: CircularProgressIndicator());
    if (_studentParcels.isEmpty) {
      return Center(
        child: Text(
          'No stored parcels found for this student.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pending Parcels',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.85),
            itemCount: _studentParcels.length,
            itemBuilder: (context, index) {
              final parcelDoc = _studentParcels[index];
              final p = parcelDoc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2, color: AppColors.primary, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            p['deliveryService'] ?? 'Unknown Courier',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Text('Tracking: ${p['trackingNumber'] ?? 'N/A'}', style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text('Rack Location: ${p['rack'] ?? 'N/A'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blue)),
                    const SizedBox(height: 8),
                    Text('Parcel No: ${p['monthlySequenceNumber'] ?? 'N/A'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _resendEmail(parcelDoc),
                              child: const Text('RESEND EMAIL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _handoverParcel(parcelDoc),
                              child: const Text('HANDOVER', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    flex: 17,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          children: [
                            Expanded(
                              flex: 7,
                              child: InkWell(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ScanLabelScreen()),
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    const Text(
                                      'Scan Parcel Label',
                                      style: TextStyle(color: AppColors.textOnPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final dashCount = (constraints.constrainWidth() / 10).floor();
                                return Flex(
                                  direction: Axis.horizontal,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(dashCount, (_) {
                                    return SizedBox(
                                      width: 5,
                                      height: 2,
                                      child: DecoratedBox(decoration: BoxDecoration(color: Colors.white.withOpacity(0.2))),
                                    );
                                  }),
                                );
                              },
                            ),
                            Expanded(
                              flex: 3,
                              child: Ink(
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryDark,
                                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                                ),
                                child: InkWell(
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ParcelDetailsScreen(initialData: {})),
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit_document, color: Colors.white.withOpacity(0.9), size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Enter details manually',
                                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    flex: 17,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EnterPinScreen()),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.accentTeal,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Enter Collection PIN',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    flex: 6,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OnboardStudentScreen()),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.person_add_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Onboard New Student',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
