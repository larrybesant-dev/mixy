import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/providers.dart';
import '../../shared/club_background.dart';
import '../../shared/glow_text.dart';
import '../../core/services/music_settings_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final themeMode = ref.watch(themeProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const GlowText(
            text: 'Settings',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          children: [
            const SizedBox(height: 16),
            _buildSectionHeader('Account'),
            _buildSettingTile(
              title: 'Privacy Settings',
              icon: Icons.lock,
              onTap: () => Navigator.of(context).pushNamed('/privacy-settings'),
            ),
            _buildSettingTile(
              title: 'Notification Settings',
              icon: Icons.notifications,
              onTap: () => _showNotificationDialog(context),
            ),
            const Divider(color: Colors.white24),
            _buildSectionHeader('Sound & Music'),
            const _SoundSettingsSection(),
            const Divider(color: Colors.white24),
            _buildSectionHeader('Developer'),
            _buildSettingTile(
              title: 'Agora Video Test',
              icon: Icons.videocam,
              onTap: () => Navigator.of(context).pushNamed('/agora-test'),
            ),
            const Divider(color: Colors.white24),
            _buildSectionHeader('Support'),
            _buildSettingTile(
              title: 'Help & Support',
              icon: Icons.help,
              onTap: () => _showHelpDialog(context),
            ),
            _buildSettingTile(
              title: 'About',
              icon: Icons.info,
              onTap: () => _showAboutDialog(context),
            ),
            const Divider(color: Colors.white24),
            _buildSettingTile(
              title: 'Logout',
              icon: Icons.logout,
              textColor: Colors.red,
              onTap: () => _showLogoutDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlowText(
        text: title,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFFFD700),
        glowColor: const Color(0xFFFF4C4C).withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    String? subtitle,
    required IconData icon,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor ?? Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(color: Colors.white70),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right,
          color: textColor ?? Colors.white70,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: const Text('Notification settings will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text('Support features will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Mix & Mingle'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('A social video chat platform'),
            SizedBox(height: 8),
            Text('Built with Flutter & Firebase'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/splash');
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Sound & Music toggle section (stateful sub-widget)
// ─────────────────────────────────────────────────────────────────
class _SoundSettingsSection extends ConsumerStatefulWidget {
  const _SoundSettingsSection();
  @override
  ConsumerState<_SoundSettingsSection> createState() =>
      _SoundSettingsSectionState();
}

class _SoundSettingsSectionState extends ConsumerState<_SoundSettingsSection> {
  bool _landingMusic = true;
  bool _profileMusic = true;
  bool _microSounds = true;
  bool _globalMute = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svcAsync = ref.read(musicSettingsProvider);
    svcAsync.whenData((svc) {
      if (mounted) {
        setState(() {
          _landingMusic = svc.landingMusicEnabled;
          _profileMusic = svc.profileMusicEnabled;
          _microSounds = svc.microSoundsEnabled;
          _globalMute = svc.globalMute;
          _loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final svcAsync = ref.watch(musicSettingsProvider);
    return svcAsync.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (svc) {
        if (!_loaded) {
          _landingMusic = svc.landingMusicEnabled;
          _profileMusic = svc.profileMusicEnabled;
          _microSounds = svc.microSoundsEnabled;
          _globalMute = svc.globalMute;
          _loaded = true;
        }
        return Column(children: [
          _toggle(
            icon: Icons.volume_off,
            title: 'Mute all sounds',
            subtitle: 'Overrides all audio settings',
            value: _globalMute,
            onChanged: (v) async {
              setState(() => _globalMute = v);
              await svc.setGlobalMute(v);
            },
          ),
          _toggle(
            icon: Icons.music_note,
            title: 'Landing page music',
            subtitle: 'Intro sting + ambient loop on start screen',
            value: _landingMusic && !_globalMute,
            enabled: !_globalMute,
            onChanged: (v) async {
              setState(() => _landingMusic = v);
              await svc.setLandingMusicEnabled(v);
            },
          ),
          _toggle(
            icon: Icons.person,
            title: 'Profile music',
            subtitle: 'Play track preview when viewing profiles',
            value: _profileMusic && !_globalMute,
            enabled: !_globalMute,
            onChanged: (v) async {
              setState(() => _profileMusic = v);
              await svc.setProfileMusicEnabled(v);
            },
          ),
          _toggle(
            icon: Icons.notifications_active,
            title: 'Micro-sounds',
            subtitle: 'Subtle sounds for joins, reactions, energy spikes',
            value: _microSounds && !_globalMute,
            enabled: !_globalMute,
            onChanged: (v) async {
              setState(() => _microSounds = v);
              await svc.setMicroSoundsEnabled(v);
            },
          ),
        ]);
      },
    );
  }

  Widget _toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    bool enabled = true,
    required Future<void> Function(bool) onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
          ),
        ),
        child: SwitchListTile(
          secondary: Icon(icon, color: Colors.white70),
          title: Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          value: value,
          onChanged: enabled ? onChanged : null,
          activeThumbColor: const Color(0xFFFF7A3C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
