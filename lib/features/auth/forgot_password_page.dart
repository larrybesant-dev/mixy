import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/providers/providers.dart';
import 'package:mixvy/shared/widgets/club_background.dart';
import 'package:mixvy/shared/widgets/glow_text.dart';
import 'package:mixvy/shared/widgets/neon_button.dart';
import 'package:mixvy/core/utils.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.resetPassword(_emailController.text.trim());

      setState(() => _emailSent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send reset email: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Logo/Brand
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4C4C), Color(0xFFFFD700)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4C4C).withValues(alpha: 0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const GlowText(
                    text: 'Reset Password',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                    glowColor: Color(0xFFFF4C4C),
                    glowRadius: 10,
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'Enter your email to receive a password reset link',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  if (_emailSent) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Reset email sent!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check your email at ${_emailController.text} for password reset instructions.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    NeonButton(
                      label: 'Back to Login',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ] else ...[
                    // Email field
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email, color: Color(0xFFFFD700)),
                        helperText:
                            'Enter the email associated with your account',
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!AppUtils.isValidEmail(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Reset Password Button
                    NeonButton(
                      label: _isLoading ? 'Sending...' : 'Send Reset Email',
                      onPressed: _isLoading ? () {} : () => _resetPassword(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

