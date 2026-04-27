import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_layout.dart';
import '../providers/app_settings_provider.dart';
import '../../features/beta/beta_tester_provider.dart';
import '../../features/after_dark/providers/after_dark_provider.dart';
import '../../features/profile/widgets/device_settings_panel.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/async_state_view.dart';

// ── Velvet Noir brand tokens ──────────────────────────────────────────────────
const _svHigh      = Color(0xFF1A1A1A);
const _svCard      = Color(0xFF141414);
const _svPrimary   = Color(0xFFD4AF37);
const _svCream     = Color(0xFFF7EDE2);
const _svMuted     = Color(0xFF7A6830);
const _svDanger    = Color(0xFFE05252);
const _svOutline   = Color(0x22D4AF37);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);

    return AppPageScaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Settings',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _svCream,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: _svPrimary.withValues(alpha: 0.15)),
        ),
      ),
      body: AppAsyncValueView(
        value: settingsAsync,
        fallbackContext: 'settings',
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            // ── ACCOUNT ──────────────────────────────────────────────────
            _SettingsGroupLabel('ACCOUNT'),
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              label: 'Edit Profile',
              onTap: () => context.go('/edit-profile'),
            ),
            _SettingsTile(
              icon: Icons.manage_accounts_outlined,
              label: 'Account & Security',
              onTap: () => context.go('/account'),
            ),
            _SettingsTile(
              icon: Icons.shield_outlined,
              label: 'Privacy',
              onTap: () => context.go('/legal/privacy'),
            ),
            _SettingsTile(
              icon: Icons.verified_outlined,
              label: 'Verify Account',
              onTap: () => context.go('/verification'),
            ),

            const SizedBox(height: 24),
            // ── PREFERENCES ──────────────────────────────────────────────
            _SettingsGroupLabel('PREFERENCES'),
            _SettingsSwitchTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              value: settings.notificationsEnabled,
              onChanged: controller.setNotificationsEnabled,
            ),

            // Appearance sub-section
            Container(
              margin: EdgeInsets.symmetric(
                  horizontal: context.pageHorizontalPadding, vertical: 4),
              decoration: BoxDecoration(
                color: _svCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _svOutline),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.brightness_4_outlined,
                            color: _svPrimary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Appearance',
                          style: GoogleFonts.raleway(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _svCream,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<ThemeMode>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: _svHigh,
                        foregroundColor: _svMuted,
                        selectedForegroundColor: Colors.black,
                        selectedBackgroundColor: _svPrimary,
                        side: const BorderSide(color: _svOutline),
                      ),
                      segments: const [
                        ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto, size: 16),
                            label: Text('System')),
                        ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode, size: 16),
                            label: Text('Light')),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode, size: 16),
                            label: Text('Dark')),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (s) =>
                          controller.updateThemeMode(s.first),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.language_outlined,
                            color: _svPrimary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Language',
                          style: GoogleFonts.raleway(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _svCream,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: settings.localeCode,
                      dropdownColor: _svCard,
                      style: GoogleFonts.raleway(
                          color: _svCream, fontSize: 14),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _svOutline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _svPrimary),
                        ),
                        filled: true,
                        fillColor: _svHigh,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(
                            value: 'es', child: Text('Español')),
                        DropdownMenuItem(
                            value: 'fr', child: Text('Français')),
                      ],
                      onChanged: (v) {
                        if (v == null || v.isEmpty) return;
                        controller.setLocaleCode(v);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Camera & Mic sub-section
            Container(
              margin: EdgeInsets.symmetric(
                  horizontal: context.pageHorizontalPadding, vertical: 4),
              decoration: BoxDecoration(
                color: _svCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _svOutline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.videocam_outlined,
                            color: _svPrimary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Camera & Microphone',
                          style: GoogleFonts.raleway(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _svCream,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const DeviceSettingsPanel(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            // ── PAYMENTS ─────────────────────────────────────────────────
            _SettingsGroupLabel('PAYMENTS'),
            _SettingsTile(
              icon: Icons.credit_card_outlined,
              label: 'Payment Methods',
              onTap: () => context.go('/payments'),
            ),
            _SettingsTile(
              icon: Icons.workspace_premium_rounded,
              label: 'VIP Subscription',
              accent: _svPrimary,
              onTap: () => context.go('/payments'),
            ),
            _SettingsTile(
              icon: Icons.receipt_long_outlined,
              label: 'Purchase History',
              onTap: () => context.go('/payments'),
            ),

            const SizedBox(height: 24),
            // ── LEGAL ────────────────────────────────────────────────────
            _SettingsGroupLabel('LEGAL'),
            _SettingsTile(
              icon: Icons.gavel_outlined,
              label: 'Terms of Service',
              sub: settings.hasAcceptedCurrentLegal
                  ? 'Accepted v${settings.legalAcceptedVersion}'
                  : 'Not accepted',
              onTap: () => context.go('/legal/terms'),
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              label: 'App Info & Diagnostics',
              onTap: () => context.go('/about'),
            ),

            // After Dark
            const SizedBox(height: 12),
            _AfterDarkSettingsCard(),

            // Beta tester
            Builder(builder: (ctx) {
              final isBeta =
                  ref.watch(isBetaTesterProvider).valueOrNull ?? false;
              if (!isBeta) return const SizedBox.shrink();
              return Column(
                children: [
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: Icons.science_outlined,
                    label: 'Beta Feedback',
                    accent: const Color(0xFF9C27B0),
                    onTap: () => context.go('/beta-feedback'),
                  ),
                ],
              );
            }),

            const SizedBox(height: 32),
            // ── LOG OUT ───────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                icon: const Icon(Icons.logout_rounded, color: _svDanger),
                label: Text(
                  'Log Out',
                  style: GoogleFonts.raleway(
                    color: _svDanger,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _svDanger, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _svCard,
        title: Text('Log out?',
            style: GoogleFonts.playfairDisplay(color: _svCream)),
        content: Text(
          'You will be returned to the login screen.',
          style: GoogleFonts.raleway(color: _svCream.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.raleway(color: _svMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Log out',
                style:
                    GoogleFonts.raleway(color: _svDanger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) context.go('/auth');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared settings widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsGroupLabel extends StatelessWidget {
  final String label;
  const _SettingsGroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
      child: Text(
        label,
        style: GoogleFonts.raleway(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _svMuted,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final Color? accent;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.sub,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = accent ?? _svPrimary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: _svCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _svOutline),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          label,
          style: GoogleFonts.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _svCream,
          ),
        ),
        subtitle: sub != null
            ? Text(sub!,
                style: GoogleFonts.raleway(
                    fontSize: 11, color: _svMuted))
            : null,
        trailing: const Icon(Icons.chevron_right_rounded,
            color: _svMuted, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsSwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: _svCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _svOutline),
      ),
      child: SwitchListTile(
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _svPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _svPrimary, size: 18),
        ),
        title: Text(
          label,
          style: GoogleFonts.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _svCream,
          ),
        ),
        value: value,
        activeThumbColor: _svPrimary,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// After Dark settings card
// ─────────────────────────────────────────────────────────────────────────────

class _AfterDarkSettingsCard extends ConsumerWidget {
  const _AfterDarkSettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync  = ref.watch(afterDarkEnabledProvider);
    final sessionActive = ref.watch(afterDarkSessionProvider);
    final controller    = ref.read(afterDarkControllerProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E0D16), Color(0xFF0B0B0B)],
        ),
        border: Border.all(
            color: const Color(0xFFE0142A).withValues(alpha: 0.3)),
      ),
      child: enabledAsync.when(
        loading: () => const ListTile(
          leading:
              Icon(Icons.local_fire_department_rounded, color: Color(0xFFE0142A)),
          title: Text('MixVy After Dark',
              style: TextStyle(color: Color(0xFFF5E8EE))),
          trailing:
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => const ListTile(
          leading:
              Icon(Icons.local_fire_department_rounded, color: Color(0xFFE0142A)),
          title: Text('MixVy After Dark',
              style: TextStyle(color: Color(0xFFF5E8EE))),
          subtitle: Text('Unavailable'),
        ),
        data: (enabled) {
          if (!enabled) {
            return ListTile(
              leading: const Icon(Icons.local_fire_department_rounded,
                  color: Color(0xFFE0142A)),
              title: Text('MixVy After Dark',
                  style: GoogleFonts.raleway(
                      color: const Color(0xFFF5E8EE),
                      fontWeight: FontWeight.w600)),
              subtitle: Text('18+ adult content. Tap to enable.',
                  style: GoogleFonts.raleway(
                      color: const Color(0xFFBB96A4), fontSize: 12)),
              trailing: FilledButton(
                onPressed: () => context.go('/after-dark/setup'),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE0142A)),
                child: const Text('Enable'),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Color(0xFFE0142A), size: 22),
                    const SizedBox(width: 10),
                    Text('MixVy After Dark',
                        style: GoogleFonts.raleway(
                            color: const Color(0xFFF5E8EE),
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0142A).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: const Color(0xFFE0142A)
                                .withValues(alpha: 0.5)),
                      ),
                      child: const Text('ON',
                          style: TextStyle(
                              color: Color(0xFFE0142A),
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'PIN-protected adult mode. Keep it locked when not in use.',
                  style: GoogleFonts.raleway(
                      color: const Color(0xFFBB96A4), fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go(
                          sessionActive ? '/after-dark' : '/after-dark/unlock'),
                      icon: const Icon(Icons.door_front_door_outlined, size: 18),
                      label: Text(sessionActive ? 'Enter' : 'Unlock'),
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE0142A)),
                    ),
                    const SizedBox(width: 10),
                    if (sessionActive)
                      OutlinedButton.icon(
                        onPressed: () => controller.lock(),
                        icon: const Icon(Icons.lock_outline_rounded,
                            size: 18, color: Color(0xFFBB96A4)),
                        label: const Text('Lock',
                            style: TextStyle(color: Color(0xFFBB96A4))),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF5A2A3A))),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          _confirmDisable(context, ref, controller),
                      child: Text('Disable',
                          style: GoogleFonts.raleway(
                              color: const Color(0xFF9E9E9E), fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDisable(
    BuildContext context,
    WidgetRef ref,
    AfterDarkController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disable After Dark?'),
        content: const Text(
            'Your PIN and settings will be cleared. You can re-enable anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable',
                style: TextStyle(color: Color(0xFFE0142A))),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.disable();
  }
}

