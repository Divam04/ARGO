import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiKeyEditScreen extends StatefulWidget {
  final String title;
  final String fieldType; // 'gemini' or 'smtp'
  final Map<String, dynamic>? currentData;

  const ApiKeyEditScreen({
    super.key,
    required this.title,
    required this.fieldType,
    this.currentData,
  });

  @override
  State<ApiKeyEditScreen> createState() => _ApiKeyEditScreenState();
}

class _ApiKeyEditScreenState extends State<ApiKeyEditScreen> {
  final _geminiCtrl = TextEditingController();
  
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _smtpSecure = true;

  @override
  void initState() {
    super.initState();
    if (widget.fieldType == 'gemini') {
      _geminiCtrl.text = widget.currentData?['gemini'] ?? '';
    } else if (widget.fieldType == 'smtp') {
      final smtp = widget.currentData?['smtp'] as Map<String, dynamic>? ?? {};
      _hostCtrl.text = smtp['host'] ?? '';
      _portCtrl.text = smtp['port']?.toString() ?? '465';
      _userCtrl.text = smtp['username'] ?? '';
      _smtpSecure = smtp['secure'] ?? true;
      // Password is intentionally left blank
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      };

      if (widget.fieldType == 'gemini') {
        updateData['gemini'] = _geminiCtrl.text;
      } else if (widget.fieldType == 'smtp') {
        final currentSmtp = widget.currentData?['smtp'] as Map<String, dynamic>? ?? {};
        // If password field is blank, keep existing password
        final pass = _passCtrl.text.isNotEmpty ? _passCtrl.text : (currentSmtp['password'] ?? '');
        
        updateData['smtp'] = {
          'host': _hostCtrl.text,
          'port': int.tryParse(_portCtrl.text) ?? 465,
          'username': _userCtrl.text,
          'password': pass,
          'secure': _smtpSecure,
          'fromAddress': _userCtrl.text, // Assume same as username for this setup
        };
      }

      await FirebaseFirestore.instance.collection('config').doc('apiKeys').set(updateData, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // DO NOT AUTOSAVE on back. WillPopScope just allows popping without saving.
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          leading: const BackButton(color: AppColors.textOnPrimary),
          title: Text(widget.title, style: const TextStyle(color: AppColors.textOnPrimary)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.fieldType == 'gemini') ...[
                      TextField(
                        controller: _geminiCtrl,
                        decoration: const InputDecoration(labelText: 'GEMINI API KEY', border: OutlineInputBorder()),
                        obscureText: true,
                      ),
                    ] else ...[
                      TextField(
                        controller: _hostCtrl,
                        decoration: const InputDecoration(labelText: 'SMTP HOST', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _portCtrl,
                        decoration: const InputDecoration(labelText: 'SMTP PORT', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Use SSL/TLS (Implicit Secure)'),
                        value: _smtpSecure,
                        onChanged: (v) => setState(() => _smtpSecure = v),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(labelText: 'USERNAME', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passCtrl,
                        decoration: const InputDecoration(
                          labelText: 'PASSWORD',
                          border: OutlineInputBorder(),
                          helperText: 'Leave blank to keep existing password unchanged',
                        ),
                        obscureText: true,
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(context), // Discards changes
                              child: const Text('BACK', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _save,
                              child: const Text('SAVE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
