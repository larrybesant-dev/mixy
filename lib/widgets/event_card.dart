import 'package:flutter/material.dart';
import 'tile_card.dart';

class EventCard extends StatelessWidget {
  final String title;
  final String description;
  const EventCard({super.key, required this.title, required this.description});
  @override
  Widget build(BuildContext context) {
    return TileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
