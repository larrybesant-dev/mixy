// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/event.dart';

/// Vertical event card for list layout
class EventCardVertical extends ConsumerWidget {
  final Event event;

  const EventCardVertical(this.event, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');
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
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event image (left side)
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: Stack(
                children: [
                  Image.network(
                    event.imageUrl,
                    width: 120,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholderImage();
                    },
                  ),

                  // Category badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Event details (right side)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
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

                    // Description
                    Text(
                      event.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateFormat.format(event.startTime),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Time
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeFormat.format(event.startTime),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Bottom row: Attendees + RSVP button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Attendee count
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${event.attendeeCount} going',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),

                        // RSVP button
                        ElevatedButton(
                          onPressed: () => _handleRSVP(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: const Text(
                            'RSVP',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildPlaceholderImage() {
    return Container(
      width: 120,
      height: 160,
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
          size: 32,
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
