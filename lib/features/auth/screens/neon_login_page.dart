import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/neon_colors.dart';
import '../../../shared/widgets/neon_components.dart';

/// ============================================================================
/// NEON LOGIN SCREEN - Electric Lounge Brand
/// Dark theme with neon orange and blue accents, logo branding
/// ============================================================================

class NeonLoginPage extends StatefulWidget {
  const NeonLoginPage({super.key});

  @override
  State<NeonLoginPage> createState() => _NeonLoginPageState();
}

class _NeonLoginPageState extends State<NeonLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _hidePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Basic validation
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    if (!_emailController.text.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Navigate to '/app' which triggers RootAuthGate to check auth and show authenticated app
      debugPrint('âœ… [Login] Sign in successful. Navigating to /app...');
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/app',
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Login failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.darkBg,
      body: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                NeonColors.darkBg2.withValues(alpha: 0.8),
                NeonColors.darkBg,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo section
                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                  _buildLogoSection(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),

                  // Login form
                  NeonGlowCard(
                    glowColor: NeonColors.neonBlue,
                    glowRadius: 20,
                    borderRadius: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title
                        const NeonText(
                          'WELCOME BACK',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          textColor: Colors.white,
                          glowColor: NeonColors.neonOrange,
                          glowRadius: 10,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to your Mix & Mingle account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: NeonColors.textSecondary,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Error message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: NeonColors.errorRed.withValues(alpha: 0.1),
                              border: Border.all(
                                color: NeonColors.errorRed,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: NeonColors.errorRed,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: NeonColors.errorRed,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_errorMessage != null) const SizedBox(height: 16),

                        // Email field
                        NeonInputField(
                          controller: _emailController,
                          hint: 'Enter your email',
                          label: 'Email',
                          prefixIcon: Icons.email_outlined,
                          focusGlowColor: NeonColors.neonOrange,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        _buildPasswordField(),
                        const SizedBox(height: 24),

                        // Login button
                        NeonButton(
                          label: _isLoading ? 'SIGNING IN...' : 'SIGN IN',
                          onPressed: _handleLogin,
                          glowColor: NeonColors.neonOrange,
                          isLoading: _isLoading,
                          height: 54,
                        ),

                        const SizedBox(height: 24),

                        // Forgot password link
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context)
                                .pushNamed('/forgot-password'),
                            child: const Text(
                              'Forgot your password?',
                              style: TextStyle(
                                color: NeonColors.neonBlue,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Divider
                        NeonDivider(
                          startColor:
                              NeonColors.neonOrange.withValues(alpha: 0.2),
                          endColor: NeonColors.neonBlue.withValues(alpha: 0.2),
                          height: 1.5,
                        ),

                        const SizedBox(height: 24),

                        // Sign up link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: NeonColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/signup'),
                              child: const Text(
                                'Create one',
                                style: TextStyle(
                                  color: NeonColors.neonBlue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Animated logo container
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: NeonColors.neonOrange.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: NeonColors.neonBlue.withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    NeonColors.neonOrange.withValues(alpha: 0.15),
                    NeonColors.neonBlue.withValues(alpha: 0.15),
                  ],
                ),
                border: Border.all(
                  color: NeonColors.neonOrange.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          NeonColors.neonOrange,
                          NeonColors.neonPurple,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.music_note,
                      size: 40,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const NeonText(
          'MIX & MINGLE',
          fontSize: 26,
          fontWeight: FontWeight.w900,
          textColor: Colors.white,
          glowColor: NeonColors.neonOrange,
          glowRadius: 12,
        ),
        const SizedBox(height: 4),
        const Text(
          'Global DJ Vibes',
          style: TextStyle(
            fontSize: 12,
            color: NeonColors.textSecondary,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Material(
      color: NeonColors.darkCard,
      borderRadius: BorderRadius.circular(12),
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: NeonColors.darkCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: NeonColors.divider,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: NeonColors.divider.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: NeonColors.neonBlue,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        child: TextField(
          controller: _passwordController,
          obscureText: _hidePassword,
          style: const TextStyle(
            color: NeonColors.textPrimary,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            labelText: 'Password',
            prefixIcon: const Icon(
              Icons.lock_outlined,
              color: NeonColors.neonOrange,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _hidePassword ? Icons.visibility_off : Icons.visibility,
                color: NeonColors.neonBlue,
              ),
              onPressed: () {
                setState(() => _hidePassword = !_hidePassword);
              },
            ),
            hintStyle: const TextStyle(
              color: NeonColors.textTertiary,
            ),
            labelStyle: TextStyle(
              color: NeonColors.neonBlue.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
