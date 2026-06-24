// Riverpod provider for Feedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feedback.dart';

// Feedback state notifier
class FeedbackNotifier extends Notifier<List<FeedbackItem>> {
  @override
  List<FeedbackItem> build() => [];

  void addFeedback(FeedbackItem feedback) {
    state = [...state, feedback];
  }

  void removeFeedback(String feedbackId) {
    state = state.where((f) => f.id != feedbackId).toList();
  }

  void clear() {
    state = [];
  }
}

final feedbackProvider = NotifierProvider<FeedbackNotifier, List<FeedbackItem>>(
  () => FeedbackNotifier(),
);
