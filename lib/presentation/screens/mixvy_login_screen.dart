import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/layout/app_layout.dart';
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
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _ageConsentChecked = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  ProviderSubscription<AuthState>? _authStateSub;

  static const String _demoEmail = String.fromEnvironment(
    'DEMO_LOGIN_EMAIL',
    defaultValue: 'test_a_prod@example.com',
  );
  static const String _demoPassword = String.fromEnvironment(
    'DEMO_LOGIN_PASSWORD',
    defaultValue: 'ProdTest@2026!',
  );

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    _authStateSub = ref.listenManual<AuthState>(
      authControllerProvider,
      (previous, next) async {
        if (!mounted) return;

        if (previous?.uid == null && next.uid != null) {
          await AnalyticsService().logLogin(method: 'email_password');
        }

        final hasNewError = next.error != null && previous?.error != next.error;
        if (hasNewError) {
          await _showMessage(next.error!, isError: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _authStateSub?.close();
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _togglePassword() =>
      setState(() => _obscurePassword = !_obscurePassword);

  Future<void> _showMessage(String message, {bool isError = false}) async {
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
    final authState = ref.read(authControllerProvider);
    if (authState.isLoading) return;
    if (!_ageConsentChecked) {
      await _showMessage(
        'Please confirm 18+ age verification and community guidelines.',
        isError: true,
      );
      return;
    }
    if (_formKey.currentState?.validate() != true) return;

    FocusScope.of(context).unfocus();
    final authController = ref.read(authControllerProvider.notifier);
    await authController.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
  }

  Future<void> _signInWithGoogle() async {
    final authState = ref.read(authControllerProvider);
    if (authState.isLoading) return;
    if (!_ageConsentChecked) {
      await _showMessage(
        'Please confirm 18+ age verification and community guidelines.',
        isError: true,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  Future<void> _instantDemoLogin() async {
    final authState = ref.read(authControllerProvider);
    if (authState.isLoading) return;
    if (!_ageConsentChecked) {
      await _showMessage(
        'Please confirm 18+ age verification and community guidelines.',
        isError: true,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).login(
      _demoEmail,
      _demoPassword,
    );
  }

  String? _validateEmail(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'Enter your email';
    }

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(input)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final input = value ?? '';
    if (input.isEmpty) {
      return 'Enter your password';
    }
    return null;
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomSafePadding = MediaQuery.paddingOf(context).bottom;

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
              bottom: 20 + bottomSafePadding,
              left: context.pageHorizontalPadding,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: keyboardOpen ? 0 : 1,
                  child: _systemLiveIndicator(),
                ),
              ),
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
  Widget _wideLayout(AuthState authState) {
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
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Center(child: _authCard(authState)),
          ),
        ),
      ],
    );
  }

  // ── narrow single-column layout ───────────────────────────────────────────
  Widget _narrowLayout(AuthState authState) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _authCard(authState),
          ),
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
    final isLoading = authState.isLoading;

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
            autovalidateMode: AutovalidateMode.onUserInteraction,
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

                // OAuth
                _oauthGoogleButton(
                  onPressed: isLoading ? null : _signInWithGoogle,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: _onVariant.withAlpha(60),
                        thickness: 0.8,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'OR CONTINUE WITH EMAIL',
                        style: GoogleFonts.raleway(
                          fontSize: 10,
                          color: _onVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: _onVariant.withAlpha(60),
                        thickness: 0.8,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Email
                _brandInput(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  enabled: !isLoading,
                  hint: 'Email address',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline_rounded,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  validator: _validateEmail,
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                ),
                const SizedBox(height: 12),

                // Password
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  enabled: !isLoading,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.raleway(color: _onSurface, fontSize: 14),
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _login(),
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
                      borderSide: const BorderSide(color: _primary, width: 1.5),
                    ),
                    hintStyle: GoogleFonts.raleway(color: _onVariant, fontSize: 14),
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
                      onPressed: isLoading ? null : _togglePassword,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  validator: _validatePassword,
                ),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed:
                        isLoading ? null : () => context.push('/forgot-password'),
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
                  onPressed: isLoading ? null : _login,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: isLoading
                        ? const SizedBox(
                            key: ValueKey('signin_loading'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _surface,
                            ),
                          )
                        : Text(
                            key: const ValueKey('signin_label'),
                            'SIGN IN',
                            style: GoogleFonts.raleway(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _surface,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // 18+ consent
                _consentGate(
                  checked: _ageConsentChecked,
                  onChanged: isLoading
                      ? null
                      : (value) => setState(
                            () => _ageConsentChecked = value ?? false,
                          ),
                ),

                const SizedBox(height: 10),

                // ── SIGN UP — gold outline button ─────────────────
                _goldOutlineButton(
                  onPressed: isLoading ? null : () => context.go('/register'),
                  label: 'SIGN UP',
                ),

                const SizedBox(height: 10),

                // Demo utility login (developer testing)
                _demoUtilityButton(
                  onPressed: isLoading ? null : _instantDemoLogin,
                ),

                const SizedBox(height: 8),

                // Footer
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _footerLink('Terms'),
                    Text(
                      '·',
                      style: GoogleFonts.raleway(fontSize: 11, color: _onVariant),
                    ),
                    _footerLink('Privacy'),
                    Text(
                      '·',
                      style: GoogleFonts.raleway(fontSize: 11, color: _onVariant),
                    ),
                    _footerLink('Support'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _oauthGoogleButton({required VoidCallback? onPressed}) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _onSurface,
          side: BorderSide(color: _onVariant.withAlpha(80)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          backgroundColor: const Color(0xFFFFFFFF),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        icon: const _GoogleGlyph(size: 18),
        label: Text(
          'Continue with Google Sign-In',
          style: GoogleFonts.raleway(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: const Color(0xFF111318),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _demoUtilityButton({required VoidCallback? onPressed}) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _secondaryBright,
          side: BorderSide(color: _secondaryBright.withAlpha(150)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          backgroundColor: _secondary.withAlpha(25),
        ),
        icon: const Icon(Icons.flash_on_rounded, size: 16, color: _secondaryBright),
        label: Text(
          'Instant One-Click Demo Login',
          style: GoogleFonts.raleway(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: _secondaryBright,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _consentGate({
    required bool checked,
    required ValueChanged<bool?>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _goldBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: CheckboxListTile(
        value: checked,
        onChanged: onChanged,
        dense: true,
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: _primary,
        checkColor: _surface,
        title: RichText(
          text: TextSpan(
            style: GoogleFonts.raleway(
              color: _onVariant,
              fontSize: 11,
              height: 1.35,
            ),
            children: [
              const TextSpan(text: 'I confirm I am 18+ and agree to the '),
              TextSpan(
                text: 'Community Guidelines',
                style: GoogleFonts.raleway(
                  color: _primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: _primary,
                ),
              ),
              const TextSpan(text: ' and terms.'),
            ],
          ),
        ),
      ),
    );
  }

  // ── brand text input ───────────────────────────────────────────────────────
  Widget _brandInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool enabled,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
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

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FF),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      alignment: Alignment.center,
      child: Text(
        'G',
        style: GoogleFonts.raleway(
          color: const Color(0xFF4285F4),
          fontWeight: FontWeight.w800,
          fontSize: size * 0.75,
          height: 1,
        ),
      ),
    );
  }
}



