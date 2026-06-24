// Basic UI widget for Feed
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feed_provider.dart';

class FeedWidget extends ConsumerWidget {
  const FeedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    if (feed.isEmpty) {
      return const Center(child: Text('No posts yet'));
    }
    return ListView.builder(
      itemCount: feed.length,
      itemBuilder: (context, index) {
        final post = feed[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: ${post.userId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(post.content),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.thumb_up),
                    const SizedBox(width: 4),
                    Text('${post.likes}'),
                    const SizedBox(width: 16),
                    const Icon(Icons.comment),
                    const SizedBox(width: 4),
                    Text('${post.comments}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
