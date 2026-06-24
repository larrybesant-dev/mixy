import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/privacy_settings.dart';
import '../../shared/club_background.dart';
import '../../shared/glow_text.dart';
import '../../shared/neon_button.dart';

class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  ConsumerState<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  late Map<String, PrivacyLevel> _privacySettings;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  void _loadPrivacySettings() {
    final privacySettingsAsync = ref.read(privacySettingsProvider);
    privacySettingsAsync.whenData((settings) {
      if (settings != null) {
        setState(() {
          _privacySettings = {
            'displayName': settings.displayName,
            'avatar': settings.avatar,
            'bio': settings.bio,
            'location': settings.location,
            'interests': settings.interests,
            'socialLinks': settings.socialLinks,
            'recentMedia': settings.recentMedia,
            'roomsCreated': settings.roomsCreated,
            'tipsReceived': settings.tipsReceived,
          };
        });
      } else {
        // Default settings
        setState(() {
          _privacySettings = {
            'displayName': PrivacyLevel.public,
            'avatar': PrivacyLevel.public,
            'bio': PrivacyLevel.public,
            'location': PrivacyLevel.public,
            'interests': PrivacyLevel.public,
            'socialLinks': PrivacyLevel.public,
            'recentMedia': PrivacyLevel.public,
            'roomsCreated': PrivacyLevel.public,
            'tipsReceived': PrivacyLevel.public,
          };
        });
      }
    });
  }

  Future<void> _savePrivacySettings() async {
    setState(() => _isLoading = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      final privacySettings = PrivacySettings(
        userId: currentUser.id,
        displayName: _privacySettings['displayName']!,
        avatar: _privacySettings['avatar']!,
        bio: _privacySettings['bio']!,
        location: _privacySettings['location']!,
        interests: _privacySettings['interests']!,
        socialLinks: _privacySettings['socialLinks']!,
        recentMedia: _privacySettings['recentMedia']!,
        roomsCreated: _privacySettings['roomsCreated']!,
        tipsReceived: _privacySettings['tipsReceived']!,
      );

      await firestoreService.updatePrivacySettings(privacySettings);

      // Refresh the provider
      ref.invalidate(privacySettingsProvider);

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy settings saved successfully')),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e')),
      );
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
          title: const GlowText(
            text: 'Privacy Settings',
            fontSize: 24,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _privacySettings.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4C4C)),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GlowText(
                      text: 'Control who can see your profile information',
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 24),
                    _buildPrivacySection(
                      'Profile Information',
                      [
                        _buildPrivacySetting(
                          'Display Name',
                          'displayName',
                          'Your username and display name',
                        ),
                        _buildPrivacySetting(
                          'Profile Picture',
                          'avatar',
                          'Your avatar image',
                        ),
                        _buildPrivacySetting(
                          'Bio',
                          'bio',
                          'Your personal description',
                        ),
                        _buildPrivacySetting(
                          'Location',
                          'location',
                          'Your location information',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildPrivacySection(
                      'Interests & Links',
                      [
                        _buildPrivacySetting(
                          'Interests',
                          'interests',
                          'Your hobbies and interests',
                        ),
                        _buildPrivacySetting(
                          'Social Links',
                          'socialLinks',
                          'Links to your social media profiles',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildPrivacySection(
                      'Activity & Stats',
                      [
                        _buildPrivacySetting(
                          'Recent Media',
                          'recentMedia',
                          'Recently uploaded photos and videos',
                        ),
                        _buildPrivacySetting(
                          'Rooms Created',
                          'roomsCreated',
                          'Number of live rooms you\'ve hosted',
                        ),
                        _buildPrivacySetting(
                          'Tips Received',
                          'tipsReceived',
                          'Total tips received from viewers',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    NeonButton(
                      onPressed: _isLoading ? null : _savePrivacySettings,
                      isLoading: _isLoading,
                      child: const Text('Save Settings'),
                    ),
                    const SizedBox(height: 16),
                    _buildPrivacyInfo(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPrivacySection(String title, List<Widget> settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x4DFFFF4C),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlowText(
            text: title,
            fontSize: 18,
            color: const Color(0xFFFFD700),
            glowColor: const Color(0xFFFF4C4C),
          ),
          const SizedBox(height: 16),
          ...settings,
        ],
      ),
    );
  }

  Widget _buildPrivacySetting(String label, String key, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildPrivacyDropdown(key),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyDropdown(String key) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0x4DFFFF4C),
          width: 1,
        ),
      ),
      child: DropdownButton<PrivacyLevel>(
        value: _privacySettings[key],
        dropdownColor: const Color(0xFF1A1A2E),
        style: const TextStyle(color: Colors.white),
        underline: Container(),
        icon: const Icon(
          Icons.arrow_drop_down,
          color: Color(0xFFFFD700),
        ),
        items: PrivacyLevel.values.map((level) {
          return DropdownMenuItem<PrivacyLevel>(
            value: level,
            child: Text(
              _getPrivacyLevelText(level),
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _privacySettings[key] = value;
            });
          }
        },
      ),
    );
  }

  String _getPrivacyLevelText(PrivacyLevel level) {
    switch (level) {
      case PrivacyLevel.public:
        return 'Public';
      case PrivacyLevel.friendsOnly:
        return 'Friends Only';
      case PrivacyLevel.private:
        return 'Private';
    }
  }

  Widget _buildPrivacyInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x4DFFFF4C),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlowText(
            text: 'Privacy Information',
            fontSize: 16,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          const SizedBox(height: 12),
          _buildInfoItem(
            'Public',
            'Visible to everyone, including non-registered users',
          ),
          const SizedBox(height: 8),
          _buildInfoItem(
            'Friends Only',
            'Only visible to users you follow and who follow you back',
          ),
          const SizedBox(height: 8),
          _buildInfoItem(
            'Private',
            'Only visible to you',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'â€¢ ',
          style: TextStyle(
            color: Color(0xFFFF4C4C),
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
