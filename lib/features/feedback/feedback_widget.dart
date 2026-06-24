// Basic UI widget for Feedback submission
import 'feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feedback_provider.dart';

class FeedbackWidget extends ConsumerWidget {
  final TextEditingController _controller = TextEditingController();

  FeedbackWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const Text('Submit Feedback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(hintText: 'Your feedback'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            final message = _controller.text;
            if (message.isNotEmpty) {
              final feedbackItem = FeedbackItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                userId: 'currentUser', // Replace with actual user ID
                message: message,
                timestamp: DateTime.now(),
              );
              ref.read(feedbackProvider.notifier).addFeedback(feedbackItem);
              _controller.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback submitted')));
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
