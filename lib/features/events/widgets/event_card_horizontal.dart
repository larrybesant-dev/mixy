// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/event.dart';

/// Horizontal event card for carousel/scroll layout
class EventCardHorizontal extends ConsumerWidget {
  final Event event;

  const EventCardHorizontal(this.event, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/event-details',
          arguments: {'eventId': event.id},
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  // Image
                  Image.network(
                    event.imageUrl,
                    width: 280,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholderImage();
                    },
                  ),

                  // Category badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Attendee count
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${event.attendeeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Event details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    event.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Date and time
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                            alpha: 255, red: 255, green: 255, blue: 255),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(event.startTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                            alpha: 255, red: 255, green: 255, blue: 255),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeFormat.format(event.startTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // RSVP button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _handleRSVP(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'RSVP',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 280,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade300,
            Colors.blue.shade300,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.event,
          size: 48,
          color: Colors.white,
        ),
      ),
    );
  }

  void _handleRSVP(BuildContext context, WidgetRef ref) {
    // TODO: Navigate to event detail or show RSVP modal
    // Navigator.pushNamed(context, '/events/${event.id}');
  }
}
