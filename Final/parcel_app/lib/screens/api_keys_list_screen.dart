import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import 'api_key_edit_screen.dart';

class ApiKeysListScreen extends StatelessWidget {
  const ApiKeysListScreen({super.key});

  Future<void> _confirmEdit(BuildContext context, String title, String fieldType, Map<String, dynamic>? currentData) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('Confirm Change', style: TextStyle(color: fieldType == 'smtp' ? Colors.red : Colors.orange)),
        content: Text('ARE YOU SURE YOU WANT TO CHANGE THE $title?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('NO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('YES', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ApiKeyEditScreen(
            title: title,
            fieldType: fieldType,
            currentData: currentData,
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
        leading: const BackButton(color: AppColors.textOnPrimary),
        title: const Text('API Keys', style: TextStyle(color: AppColors.textOnPrimary)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('config').doc('apiKeys').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          
          final geminiKey = data['gemini'] as String? ?? '';
          final maskedGemini = geminiKey.length > 4 
              ? '................${geminiKey.substring(geminiKey.length - 4)}'
              : 'Not configured';

          final smtp = data['smtp'] as Map<String, dynamic>? ?? {};
          final smtpHost = smtp['host'] as String? ?? '';
          final smtpPort = smtp['port']?.toString() ?? '';
          final smtpUser = smtp['username'] as String? ?? '';
          
          String maskedHost = smtpHost.isEmpty ? 'Not configured' : smtpHost;
          if (smtpHost.length > 5 && smtpHost.contains('.')) {
            final parts = smtpHost.split('.');
            if (parts.length >= 2) {
              maskedHost = '${parts[0]}.•••••••.${parts.last}';
            }
          }
          
          String displayUser = smtpUser.isEmpty ? 'Not configured' : smtpUser;

          return ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Card(
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(24),
                  title: const Text('GEMINI API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(maskedGemini, style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                    onPressed: () => _confirmEdit(context, 'GEMINI API KEY', 'gemini', data),
                    child: const Text('EDIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(24),
                  title: const Text('SMTP SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Host: $maskedHost : $smtpPort', style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('User: $displayUser', style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
                      ],
                    ),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                    onPressed: () => _confirmEdit(context, 'SMTP SETTINGS', 'smtp', data),
                    child: const Text('EDIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
