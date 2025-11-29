import 'package:flutter/material.dart';
import 'dart:async';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final Function(String) onVerificationComplete;
  final VoidCallback onResendOtp;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    required this.onVerificationComplete,
    required this.onResendOtp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isVerifying = false;
  int _resendCountdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _otpCode {
    return _otpControllers.map((c) => c.text).join();
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        // Auto-verify when all 6 digits entered
        if (_otpCode.length == 6) {
          _verifyOtp();
        }
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter complete OTP')),
      );
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await widget.onVerificationComplete(_otpCode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _handleResendOtp() {
    widget.onResendOtp();
    _startResendTimer();
    // Clear OTP fields
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OTP sent successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone Number'), elevation: 0),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.message_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'Enter Verification Code',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'We sent a 6-digit code to',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.phoneNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 48),

                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 50,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (value) => _onOtpChanged(index, value),
                        onTap: () {
                          _otpControllers[index].selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _otpControllers[index].text.length,
                          );
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Resend OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (_resendCountdown > 0)
                      Text(
                        'Resend in ${_resendCountdown}s',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _handleResendOtp,
                        child: const Text(
                          'Resend OTP',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const Spacer(),

                // Help Text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Make sure your phone can receive SMS messages',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
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
