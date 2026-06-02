import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../providers/after_dark_provider.dart';
import '../theme/after_dark_theme.dart';

/// After Dark profile screen — stage name, adult bio, privacy settings.
class AfterDarkProfileScreen extends ConsumerStatefulWidget {
  const AfterDarkProfileScreen({super.key});

  @override
  ConsumerState<AfterDarkProfileScreen> createState() =>
      _AfterDarkProfileScreenState();
}

class _AfterDarkProfileScreenState
    extends ConsumerState<AfterDarkProfileScreen> {
  final _stageNameCtrl = TextEditingController();
  final _adultBioCtrl = TextEditingController();
  final _lookingForCtrl = TextEditingController();
  bool _profilePrivate = false;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await ref.read(firestoreProvider).collection('users').doc(uid).get();
    if (!mounted) return;
    final data = doc.data() ?? {};
    setState(() {
      _stageNameCtrl.text = (data['adultStageName'] as String?) ?? '';
      _adultBioCtrl.text = (data['adultBio'] as String?) ?? '';
      _lookingForCtrl.text = (data['adultLookingFor'] as String?) ?? '';
      _profilePrivate = (data['adultProfilePrivate'] as bool?) ?? false;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(firestoreProvider).collection('users').doc(uid).set({
        'adultStageName': _stageNameCtrl.text.trim(),
        'adultBio': _adultBioCtrl.text.trim(),
        'adultLookingFor': _lookingForCtrl.text.trim(),
        'adultProfilePrivate': _profilePrivate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('After Dark profile saved'),
          backgroundColor: EmberDark.primaryDim,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _disable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: EmberDark.surfaceHigh,
        title: const Text(
          'Disable After Dark',
          style: TextStyle(color: EmberDark.onSurface),
        ),
        content: const Text(
          'This will remove your After Dark access and clear your PIN. You can re-enable it anytime.',
          style: TextStyle(color: EmberDark.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: EmberDark.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Disable',
              style: TextStyle(color: EmberDark.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(afterDarkControllerProvider).disable();
    if (!mounted) return;
    context.go('/settings');
  }

  @override
  void dispose() {
    _stageNameCtrl.dispose();
    _adultBioCtrl.dispose();
    _lookingForCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const AppPageScaffold(
        backgroundColor: EmberDark.surface,
        body: AppLoadingView(label: 'Loading After Dark profile'),
      );
    }

    return AppPageScaffold(
      backgroundColor: EmberDark.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.pageHorizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    EmberDark.primaryDim.withValues(alpha: 0.2),
                    EmberDark.surfaceHigh,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: EmberDark.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: EmberDark.bannerGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'After Dark Profile',
                        style: TextStyle(
                          color: EmberDark.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Visible to adults inside your late-night circle',
                        style: TextStyle(
                          color: EmberDark.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _sectionLabel('Stage Name'),
            const SizedBox(height: 8),
            _darkField(
              controller: _stageNameCtrl,
              hint: 'Your midnight alias…',
              icon: Icons.theater_comedy_outlined,
            ),

            const SizedBox(height: 20),
            _sectionLabel('Adult Bio'),
            const SizedBox(height: 8),
            _darkField(
              controller: _adultBioCtrl,
              hint: 'Describe your vibe, energy, and boundaries…',
              icon: Icons.edit_note_outlined,
              maxLines: 4,
              isRound: false,
            ),

            const SizedBox(height: 20),
            _sectionLabel('Looking For'),
            const SizedBox(height: 8),
            _darkField(
              controller: _lookingForCtrl,
              hint: 'e.g. flirtation, romance, private conversation…',
              icon: Icons.favorite_outline_rounded,
            ),

            const SizedBox(height: 20),

            // Privacy toggle
            DecoratedBox(
              decoration: BoxDecoration(
                color: EmberDark.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: EmberDark.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: SwitchListTile(
                value: _profilePrivate,
                onChanged: (v) => setState(() => _profilePrivate = v),
                title: const Text(
                  'Private Profile',
                  style: TextStyle(color: EmberDark.onSurface),
                ),
                subtitle: Text(
                  _profilePrivate
                      ? 'Only people you trust can see your After Dark profile.'
                      : 'Your After Dark profile is visible to all eligible 18+ users.',
                  style: const TextStyle(
                    color: EmberDark.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                activeThumbColor: EmberDark.primary,
                secondary: const Icon(
                  Icons.visibility_outlined,
                  color: EmberDark.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: _saving
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: EmberDark.primary,
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: EmberDark.primaryGradient,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: EmberDark.primary.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'Save Midnight Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // Danger zone
            const Divider(color: EmberDark.outlineVariant, height: 40),
            _sectionLabel('Danger Zone'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _disable,
                icon: const Icon(
                  Icons.power_off_outlined,
                  size: 18,
                  color: EmberDark.error,
                ),
                label: const Text(
                  'Disable After Dark',
                  style: TextStyle(color: EmberDark.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: EmberDark.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.raleway(
        color: EmberDark.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool isRound = true,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.raleway(color: EmberDark.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.raleway(color: EmberDark.onSurfaceVariant),
        filled: true,
        fillColor: EmberDark.surfaceHigh,
        prefixIcon: Icon(icon, color: EmberDark.onSurfaceVariant, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isRound ? 999 : 14),
          borderSide: BorderSide(color: EmberDark.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isRound ? 999 : 14),
          borderSide: BorderSide(color: EmberDark.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isRound ? 999 : 14),
          borderSide: const BorderSide(color: EmberDark.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
    );
  }
}
