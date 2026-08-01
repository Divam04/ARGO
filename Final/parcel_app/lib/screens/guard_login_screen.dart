import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../session.dart';
import '../theme/app_colors.dart';
import '../services/guard_session.dart';
import 'admin_login_screen.dart';
import 'settings_screen.dart';

class GuardLoginScreen extends StatefulWidget {
  const GuardLoginScreen({super.key});

  @override
  State<GuardLoginScreen> createState() => _GuardLoginScreenState();
}

class _GuardLoginScreenState extends State<GuardLoginScreen> {
  final _guardIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    final guardId = _guardIdController.text.trim();
    if (guardId.isEmpty) {
      setState(() => _errorMessage = 'Please enter a Guard ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('guards').doc(guardId).get();
      
      if (!doc.exists) {
        throw Exception('Invalid Guard ID. Access denied.');
      }

      final data = doc.data();
      if (data != null) {
        if (data['active'] == false) {
          throw Exception('This guard account has been deactivated.');
        }
        if (data.containsKey('name')) {
          Session.guardName = data['name'];
          GuardSession.currentGuardId = guardId;
        }
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents OS back button
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App icon / logo area
                        Image.asset(
                          'assets/logo.png',
                          width: 100,
                          height: 100,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Guard Login',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your Guard ID to continue',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _guardIdController,
                          decoration: const InputDecoration(
                            labelText: 'Guard ID',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 24),
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        if (_errorMessage != null) const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textOnPrimary,
                                  ),
                                )
                              : const Text('Login'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen(showAdminLogin: true)),
                    );
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: AppColors.primary,
                      size: 24,
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
