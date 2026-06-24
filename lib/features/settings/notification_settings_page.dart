import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/providers/all_providers.dart';
import '../../shared/widgets/async_value_view_enhanced.dart';

/// Notification settings model
class NotificationSettings {
  final bool pushNotifications;
  final bool emailNotifications;
  final bool messageNotifications;
  final bool matchNotifications;
  final bool eventNotifications;
  final bool roomNotifications;
  final bool followNotifications;
  final bool likeNotifications;
  final bool commentNotifications;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const NotificationSettings({
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.messageNotifications = true,
    this.matchNotifications = true,
    this.eventNotifications = true,
    this.roomNotifications = true,
    this.followNotifications = true,
    this.likeNotifications = true,
    this.commentNotifications = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      pushNotifications: map['pushNotifications'] ?? true,
      emailNotifications: map['emailNotifications'] ?? true,
      messageNotifications: map['messageNotifications'] ?? true,
      matchNotifications: map['matchNotifications'] ?? true,
      eventNotifications: map['eventNotifications'] ?? true,
      roomNotifications: map['roomNotifications'] ?? true,
      followNotifications: map['followNotifications'] ?? true,
      likeNotifications: map['likeNotifications'] ?? true,
      commentNotifications: map['commentNotifications'] ?? true,
      soundEnabled: map['soundEnabled'] ?? true,
      vibrationEnabled: map['vibrationEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pushNotifications': pushNotifications,
      'emailNotifications': emailNotifications,
      'messageNotifications': messageNotifications,
      'matchNotifications': matchNotifications,
      'eventNotifications': eventNotifications,
      'roomNotifications': roomNotifications,
      'followNotifications': followNotifications,
      'likeNotifications': likeNotifications,
      'commentNotifications': commentNotifications,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    };
  }

  NotificationSettings copyWith({
    bool? pushNotifications,
    bool? emailNotifications,
    bool? messageNotifications,
    bool? matchNotifications,
    bool? eventNotifications,
    bool? roomNotifications,
    bool? followNotifications,
    bool? likeNotifications,
    bool? commentNotifications,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return NotificationSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      messageNotifications: messageNotifications ?? this.messageNotifications,
      matchNotifications: matchNotifications ?? this.matchNotifications,
      eventNotifications: eventNotifications ?? this.eventNotifications,
      roomNotifications: roomNotifications ?? this.roomNotifications,
      followNotifications: followNotifications ?? this.followNotifications,
      likeNotifications: likeNotifications ?? this.likeNotifications,
      commentNotifications: commentNotifications ?? this.commentNotifications,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

/// Notification settings provider
final notificationSettingsProvider =
    StreamProvider<NotificationSettings>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value(const NotificationSettings());

  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.id)
      .collection('settings')
      .doc('notifications')
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists) return const NotificationSettings();
    return NotificationSettings.fromMap(snapshot.data() ?? {});
  });
});

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  Future<void> _updateSetting(String key, bool value) async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.id)
          .collection('settings')
          .doc('notifications')
          .set({key: value}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update setting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: AsyncValueViewEnhanced(
        value: settingsAsync,
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Master Switches
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Push Notifications'),
                    subtitle: const Text('Receive push notifications'),
                    value: settings.pushNotifications,
                    onChanged: (value) =>
                        _updateSetting('pushNotifications', value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Email Notifications'),
                    subtitle: const Text('Receive email updates'),
                    value: settings.emailNotifications,
                    onChanged: (value) =>
                        _updateSetting('emailNotifications', value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notification Types
            Text(
              'Notification Types',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Messages'),
                    subtitle: const Text('New messages and chats'),
                    value: settings.messageNotifications,
                    onChanged: (value) =>
                        _updateSetting('messageNotifications', value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Matches'),
                    subtitle: const Text('New matches and connections'),
                    value: settings.matchNotifications,
                    onChanged: (value) =>
                        _updateSetting('matchNotifications', value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Events'),
                    subtitle: const Text('Event invitations and updates'),
                    value: settings.eventNotifications,
                    onChanged: (value) =>
                        _updateSetting('eventNotifications', value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Rooms'),
                    subtitle: const Text('Room invitations and activity'),
                    value: settings.roomNotifications,
                    onChanged: (value) =>
                        _updateSetting('roomNotifications', value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Follows'),
                    subtitle: const Text('New followers'),
                    value: settings.followNotifications,
                    onChanged: (value) =>
                        _updateSetting('followNotifications', value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Likes'),
                    subtitle: const Text('Profile likes'),
                    value: settings.likeNotifications,
                    onChanged: (value) =>
                        _updateSetting('likeNotifications', value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Comments'),
                    subtitle: const Text('Comments on your posts'),
                    value: settings.commentNotifications,
                    onChanged: (value) =>
                        _updateSetting('commentNotifications', value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sound & Vibration
            Text(
              'Sound & Vibration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Sound'),
                    subtitle: const Text('Play sound for notifications'),
                    value: settings.soundEnabled,
                    onChanged: (value) => _updateSetting('soundEnabled', value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Vibration'),
                    subtitle: const Text('Vibrate for notifications'),
                    value: settings.vibrationEnabled,
                    onChanged: (value) =>
                        _updateSetting('vibrationEnabled', value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can manage notification permissions in your device settings',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
