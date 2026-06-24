import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mixvy/shared/models/event.dart';
import 'package:mixvy/shared/models/user_profile.dart';
import 'package:mixvy/shared/providers/events_providers.dart';
import 'package:mixvy/shared/providers/auth_providers.dart';

/// Event card widget showing event info with friends attending
class EventCard extends ConsumerWidget {
  final Event event;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    final friendsAttendingAsync = currentUser != null
        ? ref.watch(friendsAttendingEventProvider(
            (userId: currentUser.id, eventId: event.id)))
        : const AsyncValue<List<UserProfile>>.data([]);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and time
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                color: Color(0xFFFFD700), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM d, h:mm a')
                                  .format(event.startTime),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (event.isOnline)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFD700)),
                      ),
                      child: const Text(
                        'ONLINE',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Location
              Row(
                children: [
                  Icon(
                    event.isOnline ? Icons.videocam : Icons.location_on,
                    color: const Color(0xFFFFD700),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Stats and friends attending
              Row(
                children: [
                  // Attendees count
                  Row(
                    children: [
                      const Icon(Icons.people, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${event.attendeesCount} going',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Interested count
                  if (event.interestedCount > 0) ...[
                    Row(
                      children: [
                        const Icon(Icons.star_outline,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${event.interestedCount} interested',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],

                  // Friends attending
                  Expanded(
                    child: friendsAttendingAsync.when(
                      data: (friends) {
                        if (friends.isEmpty) return const SizedBox.shrink();
                        return EventAttendeesStrip(
                            profiles: friends, maxDisplay: 3);
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip showing attendee avatars
class EventAttendeesStrip extends StatelessWidget {
  final List<UserProfile> profiles;
  final int maxDisplay;
  final double avatarSize;

  const EventAttendeesStrip({
    super.key,
    required this.profiles,
    this.maxDisplay = 3,
    this.avatarSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) return const SizedBox.shrink();

    final displayProfiles = profiles.take(maxDisplay).toList();
    final remainingCount = profiles.length - maxDisplay;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: avatarSize,
          child: Stack(
            children: [
              for (int i = 0; i < displayProfiles.length; i++)
                Positioned(
                  right: i * (avatarSize * 0.7),
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                      image: displayProfiles[i].photoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(displayProfiles[i].photoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: displayProfiles[i].photoUrl == null
                          ? const Color(0xFFFFD700)
                          : null,
                    ),
                    child: displayProfiles[i].photoUrl == null
                        ? Center(
                            child: Text(
                              displayProfiles[i].displayName?.isNotEmpty == true
                                  ? displayProfiles[i]
                                      .displayName![0]
                                      .toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              if (remainingCount > 0)
                Positioned(
                  right: displayProfiles.length * (avatarSize * 0.7),
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '+$remainingCount',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// RSVP buttons for event (Going / Interested / Not going)
class EventRsvpButtons extends ConsumerWidget {
  final String eventId;

  const EventRsvpButtons({
    super.key,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) return const SizedBox.shrink();

    final rsvpStatusAsync = ref.watch(
        userRsvpStatusProvider((userId: currentUser.id, eventId: eventId)));

    return rsvpStatusAsync.when(
      data: (currentStatus) {
        return Row(
          children: [
            Expanded(
              child: _RsvpButton(
                label: 'Going',
                icon: Icons.check_circle,
                isSelected: currentStatus == 'going',
                onTap: () async {
                  try {
                    if (currentStatus == 'going') {
                      await ref.read(eventsServiceProvider).removeRsvp(eventId);
                    } else {
                      if (currentStatus != null) {
                        await ref
                            .read(eventsServiceProvider)
                            .removeRsvp(eventId);
                      }
                      await ref
                          .read(eventsServiceProvider)
                          .rsvpToEvent(eventId, 'going');
                    }
                    ref.invalidate(eventDetailsProvider(eventId));
                    ref.invalidate(userRsvpStatusProvider(
                        (userId: currentUser.id, eventId: eventId)));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RsvpButton(
                label: 'Interested',
                icon: Icons.star_outline,
                isSelected: currentStatus == 'interested',
                onTap: () async {
                  try {
                    if (currentStatus == 'interested') {
                      await ref.read(eventsServiceProvider).removeRsvp(eventId);
                    } else {
                      if (currentStatus != null) {
                        await ref
                            .read(eventsServiceProvider)
                            .removeRsvp(eventId);
                      }
                      await ref
                          .read(eventsServiceProvider)
                          .rsvpToEvent(eventId, 'interested');
                    }
                    ref.invalidate(eventDetailsProvider(eventId));
                    ref.invalidate(userRsvpStatusProvider(
                        (userId: currentUser.id, eventId: eventId)));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            if (currentStatus != null)
              IconButton(
                onPressed: () async {
                  try {
                    await ref.read(eventsServiceProvider).removeRsvp(eventId);
                    ref.invalidate(eventDetailsProvider(eventId));
                    ref.invalidate(userRsvpStatusProvider(
                        (userId: currentUser.id, eventId: eventId)));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.close, color: Colors.white70),
                tooltip: 'Remove RSVP',
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? const Color(0xFFFFD700)
            : Colors.white.withValues(alpha: 0.1),
        foregroundColor: isSelected ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFFFFD700)
                : Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
    );
  }
}

/// Banner showing friends attending an event
class FriendsAttendingBanner extends ConsumerWidget {
  final String eventId;
  final VoidCallback? onTap;

  const FriendsAttendingBanner({
    super.key,
    required this.eventId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) return const SizedBox.shrink();

    final friendsAsync = ref.watch(friendsAttendingEventProvider(
        (userId: currentUser.id, eventId: eventId)));

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) return const SizedBox.shrink();

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                EventAttendeesStrip(
                    profiles: friends, maxDisplay: 5, avatarSize: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${friends.length} ${friends.length == 1 ? 'friend' : 'friends'} going',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (friends.isNotEmpty)
                        Text(
                          friends
                                  .map((f) =>
                                      f.displayName ?? f.nickname ?? 'User')
                                  .take(2)
                                  .join(', ') +
                              (friends.length > 2
                                  ? ' and ${friends.length - 2} more'
                                  : ''),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFFFFD700),
                    size: 16,
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

