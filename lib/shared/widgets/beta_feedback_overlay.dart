import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';

class BetaFeedbackOverlay extends StatelessWidget {
  const BetaFeedbackOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class BetaFeedbackSheet extends ConsumerStatefulWidget {
  const BetaFeedbackSheet({super.key});

  /// Convenience method to open the sheet from any context.
  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const BetaFeedbackSheet(),
    );
  }

  @override
  ConsumerState<BetaFeedbackSheet> createState() => _BetaFeedbackSheetState();
}

class _BetaFeedbackSheetState extends ConsumerState<BetaFeedbackSheet> {
  final TextEditingController _messageController = TextEditingController();
  String _category = 'bug';
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      String route = 'unknown';
      try {
        route = GoRouterState.of(context).uri.toString();
      } catch (_) {
        route = ModalRoute.of(context)?.settings.name ?? 'unknown';
      }

      final callable = FirebaseFunctions.instance.httpsCallable('submitBetaFeedback');
      await callable.call<Map<String, dynamic>>({
        'category': _category,
        'message': message,
        'route': route,
        'platform': defaultTargetPlatform.name,
        'isWeb': kIsWeb,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks. Feedback submitted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit feedback: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Beta Issue',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(value: 'bug', child: Text('Bug')),
              DropdownMenuItem(value: 'ux', child: Text('UX Issue')),
              DropdownMenuItem(
                value: 'performance',
                child: Text('Performance'),
              ),
              DropdownMenuItem(
                value: 'feature-request',
                child: Text('Feature request'),
              ),
            ],
            onChanged: _submitting
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _category = value);
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            minLines: 4,
            maxLines: 6,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              hintText: 'Describe what you did and what you expected.',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_submitting ? 'Submitting...' : 'Submit feedback'),
            ),
          ),
        ],
      ),
    );
  }
}
