import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import 'admin_menu_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<bool> _checkRateLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Clean old attempts (older than 1 minute)
    final attemptsStr = prefs.getStringList('admin_login_attempts') ?? [];
    final attempts = attemptsStr.map((s) => int.parse(s)).where((t) => now - t < 60000).toList();
    
    if (attempts.length >= 5) {
      return false;
    }
    
    attempts.add(now);
    await prefs.setStringList('admin_login_attempts', attempts.map((e) => e.toString()).toList());
    return true;
  }

  Future<void> _login() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final canAttempt = await _checkRateLimit();
    if (!canAttempt) {
      setState(() {
        _errorMessage = 'Too many attempts. Please wait a minute.';
        _isLoading = false;
      });
      return;
    }

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final token = await cred.user?.getIdTokenResult();
      final isAdmin = token?.claims?['admin'] == true;

      if (!isAdmin) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _errorMessage = 'User does not have admin privileges.';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminMenuScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Invalid credentials.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred connecting to the server.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: const BackButton(color: AppColors.textOnPrimary),
        title: const Text('Admin Login', style: TextStyle(color: AppColors.textOnPrimary)),
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
                const Icon(
                  Icons.admin_panel_settings,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade900),
                      textAlign: TextAlign.center,
                    ),
                  ),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'USERNAME (EMAIL)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'PASSWORD',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.textOnPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              color: AppColors.textOnPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
