import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/layout/app_layout.dart';
import 'package:mixvy/core/providers/guest_mode_provider.dart';
import 'package:mixvy/core/services/guest_session_service.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/shared/widgets/app_page_scaffold.dart';
import 'package:mixvy/services/analytics_service.dart';
import 'package:mixvy/widgets/brand_ui_kit.dart';

// ── MIXVY Brand Colors — locked ───────────────────────────────────────────────
const _surface = Color(0xFF0B0B0B); // Jet Black
const _surfaceHigh = Color(0xFF1C1617); // elevated surface
const _surfaceCard = Color(0xFF161012); // card background
const _primary = Color(0xFFD4AF37); // Gold
const _primaryDim = Color(0xFF9A7B1A); // deep gold
const _secondary = Color(0xFF781E2B); // Deep Wine Red
const _secondaryBright = Color(0xFF9B2535); // wine highlight
const _onSurface = Color(0xFFF7EDE2); // Soft Cream
const _onVariant = Color(0xFFAD9585); // muted cream
const _goldBorder = Color(0x40D4AF37); // semi-transparent gold border
// ignore: unused_element
const _ghostBorder = Color(0x26FFFFFF); // subtle white ghost border
// ignore: unused_element
const _surfaceHighest = Color(0xFF211619); // highest elevation surface

class MixVyLoginScreen extends ConsumerStatefulWidget {
  const MixVyLoginScreen({super.key});

  @override
  ConsumerState<MixVyLoginScreen> createState() => _MixVyLoginScreenState();
}

class _MixVyLoginScreenState extends ConsumerState<MixVyLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePassword() =>
      setState(() => _obscurePassword = !_obscurePassword);

  Future<void> _showmessage(String message, {bool isError = false}) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError
            ? const Color(0xFFFF6E84)
            : const Color(0xFFC45E7A),
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() != true) return;
    final authController = ref.read(authControllerProvider.notifier);
    await authController.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    if (authState.error != null) {
      await _showmessage(authState.error ?? '', isError: true);
    }
    if (authState.uid != null) {
      await AnalyticsService().logLogin(method: 'email_password');
    }
  }

  Future<void> _signInWithGoogle() async {
    final authController = ref.read(authControllerProvider.notifier);
    await authController.signInWithGoogle();
    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    if (authState.error != null) {
      await _showmessage(authState.error ?? '', isError: true);
      return;
    }
    if (authState.uid != null) {
      await AnalyticsService().logLogin(method: 'google');
    }
  }

  Future<void> _signInWithApple() async {
    final authController = ref.read(authControllerProvider.notifier);
    await authController.signInWithApple();
    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    if (authState.error != null) {
      await _showmessage(authState.error ?? '', isError: true);
      return;
    }
    if (authState.uid != null) {
      await AnalyticsService().logLogin(method: 'apple');
    }
  }

  bool _supportsAppleSignIn() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return AppPageScaffold(
      backgroundColor: _surface,
      safeArea: false,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // Ambient gradient blobs
            Positioned(
              top: -120,
              left: -120,
              child: _ambientBlob(_primary.withAlpha(25), 320),
            ),
            Positioned(
              bottom: -100,
              right: -100,
              child: _ambientBlob(_secondary.withAlpha(18), 280),
            ),
            // Main layout
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 760) {
                    return _wideLayout(authState);
                  }
                  return _narrowLayout(authState);
                },
              ),
            ),
            // System live indicator — bottom-left
            Positioned(
              bottom: 20,
              left: context.pageHorizontalPadding,
              child: _systemLiveIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  // ── ambient blob ─────────────────────────────────────────────────────────
  Widget _ambientBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: const SizedBox.expand(),
      ),
    );
  }

  // ── system live indicator ─────────────────────────────────────────────────
  Widget _systemLiveIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _secondary,
            boxShadow: [
              BoxShadow(
                color: _secondary.withAlpha(80),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'SYSTEM LIVE',
          style: GoogleFonts.raleway(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _secondary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // ── MIXVY logo block — monogram + wordmark ────────────────────────────────
  Widget _logoText({double size = 42}) {
    return MixvyLogoFull(size: size);
  }

  // ── wide two-column layout ────────────────────────────────────────────────
  Widget _wideLayout(dynamic authState) {
    return Row(
      children: [
        // Left panel – branding
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(context.isExpandedLayout ? 48 : 32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _logoText(size: 52),
                  const SizedBox(height: 32),
                  Text(
                    'Where chemistry\nmeets connection.',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: _onSurface,
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Curated connections. Real chemistry.\nVIP lounge energy — wherever you are.',
                    style: GoogleFonts.raleway(
                      fontSize: 15,
                      color: _onVariant,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Preview cards
                  _brandingCards(),
                ],
              ),
            ),
          ),
        ),
        // Right panel – auth card
        Container(
          width: context.isExpandedLayout ? 440 : 380,
          constraints: const BoxConstraints(maxWidth: 440),
          padding: EdgeInsets.symmetric(
            horizontal: context.isExpandedLayout ? 40 : 24,
            vertical: context.isExpandedLayout ? 56 : 32,
          ),
          child: Center(child: _authCard(authState)),
        ),
      ],
    );
  }

  // ── narrow single-column layout ───────────────────────────────────────────
  Widget _narrowLayout(dynamic authState) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        40,
        context.pageHorizontalPadding,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _logoText(size: 36),
          const SizedBox(height: 12),
          Text(
            'Where chemistry meets connection.',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _onSurface,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 36),
          _authCard(authState),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ── branding preview cards — Mix + Connect ───────────────────────────────
  Widget _brandingCards() {
    return Row(
      children: [
        _previewCard(
          label: 'MIX',
          sub: 'Find your vibe',
          icon: Icons.people_alt_rounded,
          accent: _primary,
        ),
        const SizedBox(width: 12),
        _previewCard(
          label: 'CONNECT',
          sub: 'Start something real',
          icon: Icons.videocam_rounded,
          accent: _secondaryBright,
        ),
      ],
    );
  }

  Widget _previewCard({
    required String label,
    required String sub,
    required IconData icon,
    required Color accent,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withAlpha(50), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.raleway(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: GoogleFonts.raleway(fontSize: 12, color: _onVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ── glassmorphic auth card ────────────────────────────────────────────────
  Widget _authCard(AuthState authState) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _surfaceCard.withAlpha(200),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _goldBorder),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome back',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue your experience.',
                    style: GoogleFonts.raleway(fontSize: 13, color: _onVariant),
                  ),
                  const SizedBox(height: 24),

                  // Google sign-in
                  _socialButton(
                    onPressed: authState.isLoading ? null : _signInWithGoogle,
                    icon: _googleIcon(),
                    label: 'Continue with Google',
                  ),

                  // Apple sign-in
                  if (_supportsAppleSignIn()) ...[
                    const SizedBox(height: 10),
                    _socialButton(
                      onPressed: authState.isLoading ? null : _signInWithApple,
                      icon: const Icon(
                        Icons.apple,
                        size: 20,
                        color: _onSurface,
                      ),
                      label: 'Continue with Apple',
                    ),
                  ],

                  const SizedBox(height: 20),
                  _orDivider(),
                  const SizedBox(height: 20),

                  // Email
                  _brandInput(
                    controller: _emailController,
                    hint: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline_rounded,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your email' : null,
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: GoogleFonts.raleway(color: _onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      filled: true,
                      fillColor: _surfaceHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(
                          color: _primary,
                          width: 1.5,
                        ),
                      ),
                      hintStyle: GoogleFonts.raleway(
                        color: _onVariant,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: _onVariant,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: _onVariant,
                        ),
                        onPressed: _togglePassword,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: authState.isLoading
                          ? null
                          : () => context.push('/forgot-password'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 4,
                        ),
                      ),
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.raleway(
                          fontSize: 12,
                          color: _primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── SIGN IN — gold solid button ───────────────────
                  _goldSolidButton(
                    onPressed: authState.isLoading ? null : _login,
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _surface,
                            ),
                          )
                        : Text(
                            'SIGN IN',
                            style: GoogleFonts.raleway(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _surface,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),

                  const SizedBox(height: 12),

                  // ── SIGN UP — gold outline button ─────────────────
                  _goldOutlineButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => context.go('/register'),
                    label: 'SIGN UP',
                  ),

                  const SizedBox(height: 8),

                  // ── ENTER AS GUEST — ghost link ───────────────────
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () async {
                            await GuestSessionService.enterAsGuest();
                            if (!context.mounted) return;
                            // ignore: use_build_context_synchronously
                            ref.read(guestModeProvider.notifier).state = true;
                            // ignore: use_build_context_synchronously
                            context.go('/home');
                          },
                    child: Text(
                      'ENTER AS GUEST',
                      style: GoogleFonts.raleway(
                        fontSize: 13,
                        color: _onVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _footerLink('Terms'),
                      Text(
                        ' · ',
                        style: GoogleFonts.raleway(
                          fontSize: 11,
                          color: _onVariant,
                        ),
                      ),
                      _footerLink('Privacy'),
                      Text(
                        ' · ',
                        style: GoogleFonts.raleway(
                          fontSize: 11,
                          color: _onVariant,
                        ),
                      ),
                      _footerLink('Support'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── social button ─────────────────────────────────────────────────────────
  Widget _socialButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _surfaceHigh,
          side: const BorderSide(color: _goldBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.raleway(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── brand text input ───────────────────────────────────────────────────────
  Widget _brandInput({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.raleway(color: _onSurface, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.raleway(color: _onVariant, fontSize: 14),
        prefixIcon: Icon(prefixIcon, size: 18, color: _onVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  // ── gold solid button (SIGN IN) ────────────────────────────────────────────
  Widget _goldSolidButton({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return SizedBox(
      height: 52,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: onPressed == null
                  ? null
                  : const LinearGradient(
                      colors: [_primary, _primaryDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: onPressed == null ? _surfaceHigh : null,
              borderRadius: BorderRadius.circular(999),
              boxShadow: onPressed == null
                  ? null
                  : [
                      BoxShadow(
                        color: _primary.withAlpha(60),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(999),
              child: Center(child: child),
            ),
          ),
        ],
      ),
    );
  }

  // ── gold outline button (SIGN UP) ──────────────────────────────────────────
  Widget _goldOutlineButton({
    required VoidCallback? onPressed,
    required String label,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          backgroundColor: Colors.transparent,
        ),
        child: Text(
          label,
          style: GoogleFonts.raleway(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: _primary,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  // ── or divider ────────────────────────────────────────────────────────────
  Widget _orDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _goldBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR EMAIL',
            style: GoogleFonts.raleway(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _onVariant,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: _goldBorder)),
      ],
    );
  }

  // ── google icon ───────────────────────────────────────────────────────────
  Widget _googleIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(2),
      child: const Icon(
        Icons.g_mobiledata_rounded,
        size: 16,
        color: Color(0xFF4285F4),
      ),
    );
  }

  // ── footer link ───────────────────────────────────────────────────────────
  Widget _footerLink(String label) {
    final route = switch (label) {
      'Terms' => '/legal/terms',
      'Privacy' => '/legal/privacy',
      'Support' => '/about',
      _ => null,
    };

    return GestureDetector(
      onTap: route == null ? null : () => context.go(route),
      child: Text(
        label,
        style: GoogleFonts.raleway(
          fontSize: 11,
          color: _onVariant,
          decoration: TextDecoration.underline,
          decorationColor: _onVariant,
        ),
      ),
    );
  }
}
