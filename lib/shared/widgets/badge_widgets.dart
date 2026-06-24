import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/services/gamification/badge_service.dart';

/// Badge display widget
class BadgeWidget extends ConsumerWidget {
  final String badgeId;
  final double size;
  final bool showTooltip;
  final bool showName;

  const BadgeWidget({
    super.key,
    required this.badgeId,
    this.size = 32.0,
    this.showTooltip = true,
    this.showName = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeAsync = ref.watch(badgeDefinitionProvider(badgeId));

    return badgeAsync.when(
      data: (badge) {
        if (badge == null) {
          return const SizedBox.shrink();
        }

        final widget = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _getRarityColor(badge.rarity),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getRarityColor(badge.rarity).withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.network(
              badge.iconUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: _getRarityColor(badge.rarity).withValues(alpha: 0.2),
                  child: Icon(
                    _getBadgeIcon(badge.type),
                    color: _getRarityColor(badge.rarity),
                    size: size * 0.6,
                  ),
                );
              },
            ),
          ),
        );

        if (showTooltip) {
          return Tooltip(
            message: '${badge.name}\n${badge.description}',
            child: widget,
          );
        }

        if (showName) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget,
              const SizedBox(height: 4),
              Text(
                badge.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _getRarityColor(badge.rarity),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        }

        return widget;
      },
      loading: () => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[500]!),
        ),
      ),
      error: (error, stackTrace) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: Icon(
          Icons.error,
          color: Colors.red,
          size: size * 0.6,
        ),
      ),
    );
  }

  Color _getRarityColor(BadgeRarity rarity) {
    switch (rarity) {
      case BadgeRarity.common:
        return Colors.grey;
      case BadgeRarity.uncommon:
        return Colors.green;
      case BadgeRarity.rare:
        return Colors.blue;
      case BadgeRarity.epic:
        return Colors.purple;
      case BadgeRarity.legendary:
        return Colors.orange;
    }
  }

  IconData _getBadgeIcon(BadgeType type) {
    switch (type) {
      case BadgeType.social:
        return Icons.people;
      case BadgeType.engagement:
        return Icons.chat;
      case BadgeType.monetization:
        return Icons.monetization_on;
      case BadgeType.achievement:
        return Icons.star;
      case BadgeType.seasonal:
        return Icons.calendar_today;
    }
  }
}

/// Badge collection display widget
class BadgeCollectionWidget extends ConsumerWidget {
  final List<String> badgeIds;
  final double badgeSize;
  final int maxDisplay;
  final bool showOverflowCount;
  final Axis direction;

  const BadgeCollectionWidget({
    super.key,
    required this.badgeIds,
    this.badgeSize = 24.0,
    this.maxDisplay = 5,
    this.showOverflowCount = true,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (badgeIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayBadges = badgeIds.take(maxDisplay).toList();
    final overflowCount = badgeIds.length - maxDisplay;

    final badgeWidgets = <Widget>[];

    for (final badgeId in displayBadges) {
      badgeWidgets.add(BadgeWidget(
        badgeId: badgeId,
        size: badgeSize,
        showTooltip: true,
        showName: false,
      ));
    }

    if (overflowCount > 0 && showOverflowCount) {
      badgeWidgets.add(
        Container(
          width: badgeSize,
          height: badgeSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[300],
            border: Border.all(color: Colors.grey[500]!, width: 1),
          ),
          child: Center(
            child: Text(
              '+$overflowCount',
              style: TextStyle(
                fontSize: badgeSize * 0.3,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
      );
    }

    if (direction == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: badgeWidgets,
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: badgeWidgets,
      );
    }
  }
}

/// Badge showcase dialog
class BadgeShowcaseDialog extends ConsumerWidget {
  final List<String> badgeIds;

  const BadgeShowcaseDialog({
    super.key,
    required this.badgeIds,
  });

  static void show(BuildContext context, List<String> badgeIds) {
    showDialog(
      context: context,
      builder: (context) => BadgeShowcaseDialog(badgeIds: badgeIds),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBadgesAsync = ref.watch(allBadgesProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Badges',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: allBadgesAsync.when(
                data: (allBadges) {
                  final userBadges = allBadges
                      .where((badge) => badgeIds.contains(badge.id))
                      .toList();

                  if (userBadges.isEmpty) {
                    return const Center(
                      child: Text('No badges earned yet'),
                    );
                  }

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: userBadges.length,
                    itemBuilder: (context, index) {
                      final badge = userBadges[index];
                      return BadgeWidget(
                        badgeId: badge.id,
                        size: 60,
                        showTooltip: false,
                        showName: true,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => const Center(
                  child: Text('Error loading badges'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

