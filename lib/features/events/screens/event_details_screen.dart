import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/core/responsive/responsive_utils.dart';
import 'package:mixmingle/core/animations/app_animations.dart';
import 'package:mixmingle/shared/providers/all_providers.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';
import 'package:mixmingle/shared/widgets/async_value_view_enhanced.dart';
import 'package:mixmingle/shared/widgets/skeleton_loaders.dart';
import 'package:mixmingle/shared/models/event.dart';

class EventDetailsPage extends ConsumerWidget {
  final String eventId;

  const EventDetailsPage({
    super.key,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final currentUser = ref.watch(currentUserProvider).value;

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AsyncValueViewEnhanced(
          value: eventAsync,
          maxRetries: 3,
          skeleton: const SkeletonCard(),
          screenName: 'EventDetailsScreen',
          providerName: 'eventProvider',
          onRetry: () => ref.invalidate(eventProvider(eventId)),
          data: (event) {
            if (event == null) {
              return const Center(child: Text('Event not found'));
            }

            return CustomScrollView(
              slivers: [
                // App bar with image
                SliverAppBar(
                  expandedHeight: Responsive.responsiveValue(
                    context: context,
                    mobile: 250.0,
                    tablet: 300.0,
                    desktop: 350.0,
                  ),
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      event.title,
                      style: const TextStyle(
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3.0,
                            color: Colors.black87,
                          ),
                        ],
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          event.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2),
                              child: Icon(
                                Icons.event,
                                size:
                                    Responsive.responsiveIconSize(context, 80),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Event details
                SliverToBoxAdapter(
                  child: Padding(
                    padding: Responsive.responsivePadding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date and time
                        AppAnimations.slideInFromBottom(
                          beginOffset: 20,
                          child: _buildInfoCard(
                            context,
                            icon: Icons.calendar_today,
                            title: 'Date & Time',
                            content: _formatEventDateTime(event.date),
                          ),
                        ),
                        SizedBox(
                            height: Responsive.responsiveSpacing(context, 16)),

                        // Location
                        AppAnimations.slideInFromBottom(
                          beginOffset: 30,
                          child: _buildInfoCard(
                            context,
                            icon: Icons.location_on,
                            title: 'Location',
                            content: event.location,
                          ),
                        ),
                        SizedBox(
                            height: Responsive.responsiveSpacing(context, 16)),

                        // Description
                        AppAnimations.slideInFromBottom(
                          beginOffset: 40,
                          child: _buildInfoCard(
                            context,
                            icon: Icons.description,
                            title: 'Description',
                            content: event.description,
                          ),
                        ),
                        SizedBox(
                            height: Responsive.responsiveSpacing(context, 16)),

                        // Attendees
                        AppAnimations.slideInFromBottom(
                          beginOffset: 50,
                          child: _buildAttendeesSection(
                            context,
                            ref,
                            event,
                          ),
                        ),
                        SizedBox(
                            height: Responsive.responsiveSpacing(context, 100)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: eventAsync.maybeWhen(
          data: (event) {
            if (event == null) return null;

            final isAttending = currentUser != null &&
                event.attendeeIds.contains(currentUser.id);
            final isCreator =
                currentUser != null && event.creatorId == currentUser.id;
            final isFull = event.attendeeIds.length >= event.maxAttendees;
            final isPast = event.date.isBefore(DateTime.now());

            return Container(
              padding: Responsive.responsivePadding(context),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: _buildActionButtons(
                  context,
                  ref,
                  event,
                  isAttending,
                  isCreator,
                  isFull,
                  isPast,
                ),
              ),
            );
          },
          orElse: () => null,
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      child: Padding(
        padding: Responsive.responsivePadding(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: Responsive.responsiveIconSize(context, 24),
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: Responsive.responsiveSpacing(context, 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 14),
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: Responsive.responsiveSpacing(context, 4)),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: Responsive.responsiveFontSize(context, 16),
                      fontWeight: FontWeight.w500,
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

  Widget _buildAttendeesSection(
    BuildContext context,
    WidgetRef ref,
    Event event,
  ) {
    return Card(
      child: Padding(
        padding: Responsive.responsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: Responsive.responsiveIconSize(context, 24),
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: Responsive.responsiveSpacing(context, 16)),
                Text(
                  'Attendees',
                  style: TextStyle(
                    fontSize: Responsive.responsiveFontSize(context, 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${event.attendeeIds.length}${'/${event.maxAttendees}'}',
                  style: TextStyle(
                    fontSize: Responsive.responsiveFontSize(context, 16),
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (event.attendeeIds.isNotEmpty) ...[
              SizedBox(height: Responsive.responsiveSpacing(context, 16)),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: event.attendeeIds.take(10).length,
                  itemBuilder: (context, index) {
                    final userId = event.attendeeIds[index];
                    final profileAsync = ref.watch(userProfileProvider(userId));

                    return profileAsync.when(
                      data: (profile) {
                        if (profile == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: profile.profileImageUrl != null
                                    ? NetworkImage(profile.profileImageUrl!)
                                    : null,
                                child: profile.profileImageUrl == null
                                    ? const Icon(Icons.person, size: 20)
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.username ?? 'User',
                                style: const TextStyle(fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const CircleAvatar(radius: 20),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    Event event,
    bool isAttending,
    bool isCreator,
    bool isFull,
    bool isPast,
  ) {
    if (isPast) {
      return const SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          child: Text('Event Ended'),
        ),
      );
    }

    if (isCreator) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                // TODO: Edit event
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
          ),
          SizedBox(width: Responsive.responsiveSpacing(context, 16)),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Event'),
                    content: const Text(
                        'Are you sure you want to delete this event?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await ref
                      .read(eventsControllerProvider.notifier)
                      .deleteEvent(event.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isFull && !isAttending
            ? null
            : () async {
                if (isAttending) {
                  await ref
                      .read(eventsControllerProvider.notifier)
                      .leaveEvent(event.id);
                } else {
                  await ref
                      .read(eventsControllerProvider.notifier)
                      .joinEvent(event.id);
                }
              },
        icon: Icon(isAttending ? Icons.check_circle : Icons.add_circle),
        label: Text(
          isAttending
              ? 'Attending'
              : isFull
                  ? 'Event Full'
                  : 'Join Event',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isAttending ? Colors.green : null,
        ),
      ),
    );
  }

  String _formatEventDateTime(DateTime date) {
    final weekday =
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    final month = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][date.month - 1];
    final time = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

    return '$weekday, $month ${date.day}, ${date.year} at $time';
  }
}
