import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mixvy/widgets/brand_ui_kit.dart';

/// Empty state shown when no rooms exist
class EmptyStateNoRooms extends StatelessWidget {
  final VoidCallback? onCreateRoom;
  final String title;
  final String description;
  final String? iconPath;

  const EmptyStateNoRooms({
    Key? key,
    this.onCreateRoom,
    this.title = 'No Rooms Yet',
    this.description = 'Create your first room or join one from your network',
    this.iconPath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon or placeholder
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xD4AF37).withOpacity(0.1), // Gold 10%
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: iconPath != null
                    ? SvgPicture.asset(
                        iconPath!,
                        width: 64,
                        height: 64,
                        color: const Color(0xD4AF37), // Gold
                      )
                    : const Icon(
                        Icons.video_library_outlined,
                        size: 64,
                        color: Color(0xD4AF37), // Gold
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xF7EDE2), // Soft Cream
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xF7EDE2).withOpacity(0.7), // Soft Cream 70%
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // CTA Button
            if (onCreateRoom != null)
              MixvyGoldButton(
                onPressed: onCreateRoom,
                label: 'Create Room',
                icon: Icons.add,
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty state for no buddies/connections
class EmptyStateNoBuddies extends StatelessWidget {
  final VoidCallback? onAddBuddy;

  const EmptyStateNoBuddies({
    Key? key,
    this.onAddBuddy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0x9B2535).withOpacity(0.1), // Wine Red 10%
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Color(0x9B2535), // Wine Red
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Buddies Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xF7EDE2),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect with friends to see their rooms and activity',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xF7EDE2).withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (onAddBuddy != null)
              MixvyGoldButton(
                onPressed: onAddBuddy,
                label: 'Add Friends',
                icon: Icons.person_add,
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty state for no messages
class EmptyStateNoMessages extends StatelessWidget {
  const EmptyStateNoMessages({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xD4AF37).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(
                  Icons.mail_outline,
                  size: 64,
                  color: Color(0xD4AF37),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Messages',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xF7EDE2),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start a conversation with your buddies',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xF7EDE2).withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state for room members/participants
class EmptyStateNoParticipants extends StatelessWidget {
  const EmptyStateNoParticipants({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0x9B2535).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  size: 48,
                  color: Color(0x9B2535),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Waiting for Participants',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xF7EDE2),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share room link with friends to get started',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xF7EDE2).withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
