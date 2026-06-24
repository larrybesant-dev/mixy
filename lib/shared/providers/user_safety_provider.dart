/// User Safety Provider
/// Report and block users
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// User Safety State
class UserSafetyState {
  final List<String> blockedUserIds;
  final bool isLoading;

  const UserSafetyState({
    this.blockedUserIds = const [],
    this.isLoading = false,
  });

  UserSafetyState copyWith({
    List<String>? blockedUserIds,
    bool? isLoading,
  }) {
    return UserSafetyState(
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// User Safety Controller
class UserSafetyController extends Notifier<UserSafetyState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  UserSafetyState build() {
    return const UserSafetyState();
  }

  /// Load blocked users
  Future<void> loadBlockedUsers(String userId) async {
    try {
      state = state.copyWith(isLoading: true);

      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      final blockedUsers = List<String>.from(data?['blockedUsers'] ?? []);

      state = state.copyWith(
        blockedUserIds: blockedUsers,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('âŒ Error loading blocked users: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Block a user
  Future<void> blockUser(String currentUserId, String targetUserId) async {
    try {
      state = state.copyWith(isLoading: true);

      // Add to blocked list
      await _firestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayUnion([targetUserId]),
      });

      // Remove any existing chat rooms
      final chats = await _firestore
          .collection('chatRooms')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (final chat in chats.docs) {
        final data = chat.data();
        final participants = List<String>.from(data['participants'] ?? []);
        if (participants.contains(targetUserId)) {
          await chat.reference.delete();
        }
      }

      // Update local state
      state = state.copyWith(
        blockedUserIds: [...state.blockedUserIds, targetUserId],
        isLoading: false,
      );

      debugPrint('âœ… User blocked: $targetUserId');
    } catch (e) {
      debugPrint('âŒ Error blocking user: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    try {
      state = state.copyWith(isLoading: true);

      await _firestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayRemove([targetUserId]),
      });

      state = state.copyWith(
        blockedUserIds:
            state.blockedUserIds.where((id) => id != targetUserId).toList(),
        isLoading: false,
      );

      debugPrint('âœ… User unblocked: $targetUserId');
    } catch (e) {
      debugPrint('âŒ Error unblocking user: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Report a user
  Future<void> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    required String category,
    String? description,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'category': category,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('âœ… User reported: $reportedUserId');
    } catch (e) {
      debugPrint('âŒ Error reporting user: $e');
      rethrow;
    }
  }
}

/// Provider
final userSafetyProvider =
    NotifierProvider<UserSafetyController, UserSafetyState>(
  UserSafetyController.new,
);

/// Show report dialog
Future<void> showReportDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentUserId,
  required String targetUserId,
  required String targetUserName,
}) async {
  String? selectedCategory;
  String? selectedReason;
  final descriptionController = TextEditingController();

  final categories = {
    'harassment': 'Harassment',
    'inappropriate_content': 'Inappropriate Content',
    'spam': 'Spam',
    'fake_profile': 'Fake Profile',
    'underage': 'Underage User',
    'other': 'Other',
  };

  final reasons = {
    'harassment': [
      'Abusive language',
      'Threats',
      'Bullying',
      'Hate speech',
    ],
    'inappropriate_content': [
      'Nudity',
      'Sexual content',
      'Violence',
      'Illegal activity',
    ],
    'spam': [
      'Promotional content',
      'Repetitive messages',
      'Scam attempt',
    ],
    'fake_profile': [
      'Impersonation',
      'Fake photos',
      'Bot account',
    ],
    'underage': [
      'User appears underage',
    ],
    'other': [
      'Other violation',
    ],
  };

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: const Color(0xFF1A0B2E),
        title: Text(
          'Report $targetUserName',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Category',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1A0B2E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white
                      .withValues(alpha: 255, red: 255, green: 255, blue: 255),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: categories.entries
                    .map((entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                    selectedReason = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (selectedCategory != null) ...[
                const Text(
                  'Reason',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF1A0B2E),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(
                        alpha: 255, red: 255, green: 255, blue: 255),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: (reasons[selectedCategory] ?? [])
                      .map((reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(reason),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Additional Details (Optional)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(
                        alpha: 255, red: 255, green: 255, blue: 255),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'Provide more context...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(
                          alpha: 255, red: 255, green: 255, blue: 255),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: selectedCategory != null && selectedReason != null
                ? () async {
                    try {
                      await ref.read(userSafetyProvider.notifier).reportUser(
                            reporterId: currentUserId,
                            reportedUserId: targetUserId,
                            reason: selectedReason!,
                            category: selectedCategory!,
                            description:
                                descriptionController.text.trim().isEmpty
                                    ? null
                                    : descriptionController.text.trim(),
                          );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report submitted. Thank you.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  }
                : null,
            child: const Text('Submit Report'),
          ),
        ],
      ),
    ),
  );
}

/// Show block confirmation dialog
Future<void> showBlockDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentUserId,
  required String targetUserId,
  required String targetUserName,
}) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A0B2E),
      title: Text(
        'Block $targetUserName?',
        style: const TextStyle(color: Colors.white),
      ),
      content: const Text(
        'You won\'t be able to see each other\'s profiles or message each other.',
        style: TextStyle(color: Colors.white),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          onPressed: () async {
            await ref
                .read(userSafetyProvider.notifier)
                .blockUser(currentUserId, targetUserId);

            if (context.mounted) {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$targetUserName has been blocked')),
              );
            }
          },
          child: const Text('Block'),
        ),
      ],
    ),
  );
}
