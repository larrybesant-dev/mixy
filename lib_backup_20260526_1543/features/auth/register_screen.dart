import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/core/layout/app_layout.dart';
import 'package:mixvy/services/analytics_service.dart';
import 'package:mixvy/shared/widgets/app_page_scaffold.dart';
import 'package:mixvy/widgets/brand_ui_kit.dart';

// ── Brand tokens (mirrors mixvy_login_screen.dart) ────────────────────────────
const _rSurface = Color(0xFF0B0B0B);
const _rSurfaceHigh = Color(0xFF1C1617);
const _rSurfaceCard = Color(0xFF161012);
const _rPrimary = Color(0xFFD4AF37);
const _rPrimaryDim = Color(0xFF9A7B1A);
const _rSecondary = Color(0xFF781E2B);
const _rSecondaryBright = Color(0xFF9B2535);
const _rOnSurface = Color(0xFFF7EDE2);
const _rOnVariant = Color(0xFFAD9585);
const _rGoldBorder = Color(0x40D4AF37);

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _localError;
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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _register() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (_formKey.currentState?.validate() != true) return;
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      setState(
        () => _localError = 'Username, email, and password are required.',
      );
      return;
    }
    setState(() => _localError = null);
    final controller = ref.read(authControllerProvider.notifier);
    await controller.signup(email, password, username);
    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    setState(() => _localError = authState.error);
    if (authState.error == null && authState.uid != null) {
      await AnalyticsService().logLogin(method: 'email_password');
    }
  }

  Future<void> _signInWithGoogle() async {
    final controller = ref.read(authControllerProvider.notifier);
    await controller.signInWithGoogle();
    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    setState(() => _localError = authState.error);
    if (authState.error == null && authState.uid != null) {
      await AnalyticsService().logLogin(method: 'google');
    }
  }

  Future<void> _signInWithApple() async {
    final controller = ref.read(authControllerProvider.notifier);
    await controller.signInWithApple();
    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    setState(() => _localError = authState.error);
    if (authState.error == null && authState.uid != null) {
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
      backgroundColor: _rSurface,
      safeArea: false,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // Ambient gold blob — top-right
            Positioned(
              top: -120,
              right: -120,
              child: _ambientBlob(_rPrimary.withAlpha(25), 300),
            ),
            // Ambient wine blob — bottom-left
            Positioned(
              bottom: -100,
              left: -100,
              child: _ambientBlob(_rSecondary.withAlpha(18), 260),
            ),
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

  // ── ambient blob ──────────────────────────────────────────────────────────
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
            color: _rSecondary,
            boxShadow: [
              BoxShadow(
                color: _rSecondary.withAlpha(80),
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
            color: _rSecondary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // ── MIXVY logo block ──────────────────────────────────────────────────────
  Widget _logoText({double size = 42}) {
    return MixvyLogoFull(size: size);
  }

  // ── wide two-column layout ────────────────────────────────────────────────
  Widget _wideLayout(AuthState authState) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(context.isExpandedLayout ? 48 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _logoText(size: 52),
                const SizedBox(height: 32),
                Text(
                  'Your journey\nstarts here.',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: _rOnSurface,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create your account and step into\na world of real connections.',
                  style: GoogleFonts.raleway(
                    fontSize: 15,
                    color: _rOnVariant,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 40),
                _brandingCards(),
              ],
            ),
          ),
        ),
        Container(
          width: 440,
          padding: EdgeInsets.symmetric(
            horizontal: context.isExpandedLayout ? 40 : 28,
            vertical: context.isExpandedLayout ? 56 : 40,
          ),
          child: Center(child: _registerCard(authState)),
        ),
      ],
    );
  }

  // ── narrow single-column layout ───────────────────────────────────────────
  Widget _narrowLayout(AuthState authState) {
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
            'Your journey starts here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _rOnSurface,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 36),
          _registerCard(authState),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ── branding preview cards ────────────────────────────────────────────────
  Widget _brandingCards() {
    return Row(
      children: [
        _previewCard(
          label: 'JOIN',
          sub: 'Be part of the vibe',
          icon: Icons.star_outline_rounded,
          accent: _rPrimary,
        ),
        const SizedBox(width: 12),
        _previewCard(
          label: 'INDULGE',
          sub: 'VIP lounge energy',
          icon: Icons.local_bar_rounded,
          accent: _rSecondaryBright,
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
          color: _rSurfaceCard,
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
              style: GoogleFonts.raleway(fontSize: 12, color: _rOnVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ── glassmorphic register card ────────────────────────────────────────────
  Widget _registerCard(AuthState authState) {
    final isLoading = authState.isLoading;
    final serverError = authState.error;
    final errorText = _localError ?? serverError;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _rSurfaceCard.withAlpha(200),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _rGoldBorder),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create account',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _rOnSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join the experience. It only takes a moment.',
                    style: GoogleFonts.raleway(
                      fontSize: 13,
                      color: _rOnVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Social buttons ───────────────────────────────────
                  _socialButton(
                    onPressed: isLoading ? null : _signInWithGoogle,
                    icon: _googleIcon(),
                    label: 'Continue with Google',
                  ),
                  if (_supportsAppleSignIn()) ...[
                    const SizedBox(height: 10),
                    _socialButton(
                      onPressed: isLoading ? null : _signInWithApple,
                      icon: const Icon(
                        Icons.apple,
                        size: 20,
                        color: _rOnSurface,
                      ),
                      label: 'Continue with Apple',
                    ),
                  ],

                  const SizedBox(height: 20),
                  _orDivider(),
                  const SizedBox(height: 20),

                  _brandInput(
                    controller: _usernameController,
                    hint: 'Username',
                    prefixIcon: Icons.alternate_email_rounded,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Username is required';
                      if (value.length < 3) return 'Minimum 3 characters';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  // ── Email ────────────────────────────────────────────
                  _brandInput(
                    controller: _emailController,
                    hint: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline_rounded,
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  // ── Password ─────────────────────────────────────────
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: isLoading ? null : (_) => _register(),
                    style: GoogleFonts.raleway(
                      color: _rOnSurface,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Password (min. 6 characters)',
                      filled: true,
                      fillColor: _rSurfaceHigh,
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
                          color: _rPrimary,
                          width: 1.5,
                        ),
                      ),
                      hintStyle: GoogleFonts.raleway(
                        color: _rOnVariant,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: _rOnVariant,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: _rOnVariant,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Minimum 6 characters'
                        : null,
                  ),

                  // ── Error message ────────────────────────────────────
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _rSecondaryBright.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _rSecondaryBright.withAlpha(80),
                        ),
                      ),
                      child: Text(
                        errorText,
                        style: GoogleFonts.raleway(
                          fontSize: 12,
                          color: const Color(0xFFFF6E84),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── CREATE ACCOUNT — gold solid button ───────────────
                  _goldSolidButton(
                    onPressed: isLoading ? null : _register,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _rSurface,
                            ),
                          )
                        : Text(
                            'CREATE ACCOUNT',
                            style: GoogleFonts.raleway(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _rSurface,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),

                  const SizedBox(height: 12),

                  // ── SIGN IN — gold outline button ─────────────────────
                  _goldOutlineButton(
                    onPressed: isLoading ? null : () => context.go('/auth'),
                    label: 'ALREADY HAVE AN ACCOUNT',
                  ),

                  const SizedBox(height: 16),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _footerLink('Terms'),
                      Text(
                        ' · ',
                        style: GoogleFonts.raleway(
                          fontSize: 11,
                          color: _rOnVariant,
                        ),
                      ),
                      _footerLink('Privacy'),
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
          backgroundColor: _rSurfaceHigh,
          side: const BorderSide(color: _rGoldBorder),
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
                color: _rOnSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── brand text input ──────────────────────────────────────────────────────
  Widget _brandInput({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool autofocus = false,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
      textInputAction: textInputAction,
      style: GoogleFonts.raleway(color: _rOnSurface, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _rSurfaceHigh,
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
          borderSide: const BorderSide(color: _rPrimary, width: 1.5),
        ),
        hintStyle: GoogleFonts.raleway(color: _rOnVariant, fontSize: 14),
        prefixIcon: Icon(prefixIcon, size: 18, color: _rOnVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  // ── gold solid button ─────────────────────────────────────────────────────
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
                      colors: [_rPrimary, _rPrimaryDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: onPressed == null ? _rSurfaceHigh : null,
              borderRadius: BorderRadius.circular(999),
              boxShadow: onPressed == null
                  ? null
                  : [
                      BoxShadow(
                        color: _rPrimary.withAlpha(60),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  // ── gold outline button ───────────────────────────────────────────────────
  Widget _goldOutlineButton({
    required VoidCallback? onPressed,
    required String label,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: onPressed == null ? _rGoldBorder : _rPrimary.withAlpha(120),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.raleway(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: onPressed == null ? _rOnVariant : _rPrimary,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  // ── or divider ────────────────────────────────────────────────────────────
  Widget _orDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: _rGoldBorder, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or register with email',
            style: GoogleFonts.raleway(fontSize: 11, color: _rOnVariant),
          ),
        ),
        const Expanded(child: Divider(color: _rGoldBorder, thickness: 1)),
      ],
    );
  }

  // ── footer link ───────────────────────────────────────────────────────────
  Widget _footerLink(String label) {
    final route = switch (label) {
      'Terms' => '/legal/terms',
      'Privacy' => '/legal/privacy',
      _ => null,
    };

    return TextButton(
      onPressed: route == null ? null : () => context.go(route),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.raleway(
          fontSize: 11,
          color: _rOnVariant,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  // ── Google icon (coloured G) ──────────────────────────────────────────────
  Widget _googleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'G',
            style: GoogleFonts.raleway(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4285F4),
            ),
          ),
        ],
      ),
    );
  }
}
