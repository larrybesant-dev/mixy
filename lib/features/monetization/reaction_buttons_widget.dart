import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reactions_provider.dart';

class ReactionButtonsWidget extends ConsumerWidget {
  const ReactionButtonsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.favorite),
          onPressed: () {
            ref.read(reactionsProvider.notifier).update((map) {
              map['heart'] = (map['heart'] ?? 0) + 1;
              return map;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.whatshot),
          onPressed: () {
            ref.read(reactionsProvider.notifier).update((map) {
              map['fire'] = (map['fire'] ?? 0) + 1;
              return map;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.emoji_events),
          onPressed: () {
            ref.read(reactionsProvider.notifier).update((map) {
              map['clap'] = (map['clap'] ?? 0) + 1;
              return map;
            });
          },
        ),
      ],
    );
  }
}
