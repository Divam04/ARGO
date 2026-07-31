import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class GuardDetailScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> guardData;

  const GuardDetailScreen({
    super.key,
    required this.docId,
    required this.guardData,
  });

  Future<void> _changeDetails(BuildContext context) async {
    final nameCtrl = TextEditingController(text: guardData['name']);
    final passwordCtrl = TextEditingController();

    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Change Details', style: TextStyle(color: Colors.cyan)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'NEW NAME'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter Admin Password to confirm:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(labelText: 'ADMIN PASSWORD'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('SAVE', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.isNotEmpty && passwordCtrl.text.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        try {
          final cred = EmailAuthProvider.credential(email: user.email!, password: passwordCtrl.text);
          await user.reauthenticateWithCredential(cred);
          
          await FirebaseFirestore.instance.collection('guards').doc(docId).update({
            'name': nameCtrl.text,
          });
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guard updated.')));
            Navigator.pop(context); // return to list
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication failed.')));
          }
        }
      }
    }
  }

  Future<void> _deleteGuard(BuildContext context) async {
    final passwordCtrl = TextEditingController();

    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Delete Guard', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This will deactivate the guard. Historical parcels will remain intact.'),
            const SizedBox(height: 16),
            const Text(
              'Enter Admin Password to confirm:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(labelText: 'ADMIN PASSWORD'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && passwordCtrl.text.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        try {
          final cred = EmailAuthProvider.credential(email: user.email!, password: passwordCtrl.text);
          await user.reauthenticateWithCredential(cred);
          
          await FirebaseFirestore.instance.collection('guards').doc(docId).update({
            'active': false,
          });
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guard deactivated.')));
            Navigator.pop(context); // return to list
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication failed.')));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = guardData['active'] ?? false;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: const BackButton(color: AppColors.textOnPrimary),
        title: const Text('Guard Details', style: TextStyle(color: AppColors.textOnPrimary)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: isActive ? AppColors.primary : Colors.grey,
                  child: const Icon(Icons.person, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  guardData['name'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${guardData['guardId']}',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                if (isActive) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _changeDetails(context),
                      child: const Text(
                        'CHANGE DETAILS',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _deleteGuard(context),
                      child: const Text(
                        'DELETE GUARD',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning, color: Colors.red),
                        SizedBox(width: 8),
                        Text('This guard is inactive.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
