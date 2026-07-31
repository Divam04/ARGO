import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:lottie/lottie.dart';
import 'parcel_screen.dart';
import '../services/guard_session.dart';

class EnterPinScreen extends StatefulWidget {
  @override
  _EnterPinScreenState createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends State<EnterPinScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onChanged(String value, int index) {
    setState(() {
      _errorMessage = null;
    });

    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _submitPin();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _submitPin() async {
    final pin = _controllers.map((c) => c.text).join();
    if (pin.length < 4) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final guardId = GuardSession.currentGuardId ?? 'unknown';
      final deviceId = 'device_123'; // In a real app, use device_info_plus to get a real device ID

      final result = await FirebaseFunctions.instance.httpsCallable('resolvePin').call({
        'pin': pin,
        'deviceId': deviceId,
        'guardId': guardId,
      });

      final parcelData = Map<String, dynamic>.from(result.data);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ParcelScreen(parcelData: parcelData)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is FirebaseFunctionsException
            ? (e.message ?? 'Incorrect PIN entered')
            : 'Incorrect PIN entered';
        for (var c in _controllers) {
          c.clear();
        }
      });
      _focusNodes[0].requestFocus();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Enter Collection Code'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter 4-Digit PIN',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 70,
                    height: 80,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      enabled: !_isLoading,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                        ),
                      ),
                      onChanged: (value) => _onChanged(value, index),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              if (_isLoading) 
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Lottie.asset('assets/cart_loading.json'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
