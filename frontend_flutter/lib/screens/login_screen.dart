import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// Email/password and Phone login screen.
class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Email Auth Data
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Phone Auth Data
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isPhoneAuth = false;
  bool _codeSent = false;
  String? _verificationId;

  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final authService = context.read<AuthService>();
      final notificationService = context.read<NotificationService>();

      await authService.loginWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Persist FCM token for the signed-in user.
      await notificationService.refreshAndSaveTokenForCurrentUser();
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = e.message ?? 'Login failed.');
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _errorText = 'Unexpected error: $e');
      setState(() => _isLoading = false);
    }
    // Note: Do not setState(_isLoading = false) in finally if login succeeds, 
    // because the StreamBuilder in main.dart unmounts this screen, causing an error.
  }

  Future<void> _onSendOtp() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final authService = context.read<AuthService>();
    await authService.sendPhoneOtp(
      phoneNumber: _phoneController.text,
      codeSent: (verificationId, resendToken) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
            _errorText = null;
          });
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() {
            _errorText = e.message ?? 'Verification failed';
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _onVerifyOtp() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_verificationId == null) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final authService = context.read<AuthService>();
      final notificationService = context.read<NotificationService>();

      await authService.verifyCurrentPhoneOtp(
        verificationId: _verificationId!,
        smsCode: _otpController.text,
        phoneNumber: _phoneController.text,
      );

      await notificationService.refreshAndSaveTokenForCurrentUser();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.message ?? 'Invalid OTP code.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Unexpected error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isPhoneAuth = !_isPhoneAuth;
      _codeSent = false;
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isPhoneAuth ? 'Phone Login' : 'Email Login')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Text('SmartCity Emergency', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Sign in to find hospitals, live beds, and emergency help.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),

                    // EMAIL UI
                    if (!_isPhoneAuth) ...[
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Password is required.';
                          if (v.trim().length < 6) return 'Password must be at least 6 characters.';
                          return null;
                        },
                      ),
                    ],

                    // PHONE UI
                    if (_isPhoneAuth) ...[
                      if (!_codeSent) ...[
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number (with country code)',
                            hintText: '+91 9876543210',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: (v) => (v == null || v.trim().length < 8) ? 'Enter a valid phone number.' : null,
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '6-digit OTP Code',
                            prefixIcon: Icon(Icons.message),
                          ),
                          validator: (v) => (v == null || v.trim().length < 6) ? 'Enter the full 6-digit code.' : null,
                        ),
                      ],
                    ],

                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorText!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 18),

                    if (!_isPhoneAuth) ...[
                      ElevatedButton(
                        onPressed: _isLoading ? null : _onLogin,
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                            : const Text('Login with Email'),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: _isLoading ? null : (_codeSent ? _onVerifyOtp : _onSendOtp),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                            : Text(_codeSent ? 'Verify OTP' : 'Send OTP Code'),
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : _toggleAuthMode,
                      child: Text(_isPhoneAuth ? 'Use Email / Password instead' : 'Login with Phone Number'),
                    ),
                    if (!_isPhoneAuth)
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).pushNamed('/signup');
                              },
                        child: const Text('Create an account'),
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
