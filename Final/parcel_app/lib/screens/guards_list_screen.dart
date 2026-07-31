import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import 'guard_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GuardsListScreen extends StatelessWidget {
  const GuardsListScreen({super.key});

  Future<void> _addGuard(BuildContext context) async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Add Guard', style: TextStyle(color: AppColors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(labelText: 'GUARD ID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'GUARD NAME'),
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
            child: const Text('ADD', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && idCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty && passwordCtrl.text.isNotEmpty) {
      // Re-authenticate admin to confirm action
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        try {
          final cred = EmailAuthProvider.credential(email: user.email!, password: passwordCtrl.text);
          await user.reauthenticateWithCredential(cred);
          
          await FirebaseFirestore.instance.collection('guards').doc(idCtrl.text).set({
            'guardId': idCtrl.text,
            'name': nameCtrl.text,
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guard added.')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to authenticate or add guard.')));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: const BackButton(color: AppColors.textOnPrimary),
        title: const Text('Guards', style: TextStyle(color: AppColors.textOnPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.textOnPrimary),
            onPressed: () => _addGuard(context),
            tooltip: 'Add Guard',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('guards')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final guards = snapshot.data?.docs ?? [];
          
          if (guards.isEmpty) {
            return const Center(child: Text('No guards found.', style: TextStyle(fontSize: 18)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: guards.length,
            itemBuilder: (context, index) {
              final guardDoc = guards[index];
              final data = guardDoc.data() as Map<String, dynamic>;
              final isActive = data['active'] ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                color: isActive ? Colors.white : Colors.grey.shade200,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor: isActive ? AppColors.primary : Colors.grey,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    data['name'] ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: isActive ? null : TextDecoration.lineThrough,
                      color: isActive ? AppColors.textPrimary : Colors.grey.shade600,
                    ),
                  ),
                  subtitle: Text('ID: ${data['guardId']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GuardDetailScreen(
                          docId: guardDoc.id,
                          guardData: data,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
