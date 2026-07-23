import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../providers/verification_provider.dart';

/// Screen where a user can submit a verification request and see its status.
///
/// Route: /verification
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please explain why you should be verified.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(firestoreProvider)
          .collection('verification_requests')
          .doc(uid)
          .set({
            'userId': uid,
            'reason': reason,
            'status': 'pending',
            'submittedAt': FieldValue.serverTimestamp(),
            'reviewedAt': null,
            'reviewNote': null,
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification request submitted!')),
      );
      _reasonController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isVerifiedAsync = ref.watch(userVerificationProvider(uid));
    final requestAsync = ref.watch(verificationRequestProvider);
    final theme = Theme.of(context);

    return AppPageScaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.pageHorizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            isVerifiedAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (__, _) => const SizedBox.shrink(),
              data: (isVerified) {
                if (isVerified) {
                  return _StatusBanner(
                    icon: Icons.verified,
                    color: const Color(0xFFC45E7A),
                    title: 'You are verified!',
                    subtitle: 'Your account has the verified badge.',
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            Text(
              'Get Verified',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verified accounts receive a blue checkmark badge, increased trust in live rooms, and priority matching in speed dating.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Requirements list
            Text(
              'Requirements',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...[
              'Real name or brand name on your profile',
              'Profile photo that clearly shows your face',
              'At least 10 followers',
              'Account at least 30 days old',
            ].map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),

            // Request form / existing request status
            AppAsyncValueView<Map<String, dynamic>?>(
              value: requestAsync,
              fallbackContext: 'verification requests',
              data: (request) {
                if (request != null) {
                  final status = request['status'] as String? ?? 'pending';
                  final note = request['reviewNote'] as String?;
                  return _ExistingRequestView(
                    status: status,
                    reviewNote: note,
                    onResubmit: status == 'rejected'
                        ? () async {
                            await ref
                                .read(firestoreProvider)
                                .collection('verification_requests')
                                .doc(uid)
                                .delete();
                            setState(() {});
                          }
                        : null,
                  );
                }

                // No request yet — show form
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submit a Request',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reasonController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Why should your account be verified?',
                        hintText:
                            'Describe your account, content, or public presence…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submitRequest,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_user_outlined),
                        label: const Text('Submit Verification Request'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingRequestView extends StatelessWidget {
  final String status;
  final String? reviewNote;
  final VoidCallback? onResubmit;

  const _ExistingRequestView({
    required this.status,
    this.reviewNote,
    this.onResubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, title, subtitle) = switch (status) {
      'approved' => (
        Icons.verified,
        const Color(0xFFC45E7A),
        'Request approved',
        'You have been granted verified status.',
      ),
      'rejected' => (
        Icons.cancel_outlined,
        theme.colorScheme.error,
        'Request rejected',
        reviewNote ??
            'Your request did not meet our requirements. You may submit again.',
      ),
      _ => (
        Icons.hourglass_top_outlined,
        const Color(0xFFFFB74D),
        'Request pending',
        'Your request is under review. This usually takes 3–5 business days.',
      ),
    };

    return Column(
      children: [
        _StatusBanner(
          icon: icon,
          color: color,
          title: title,
          subtitle: subtitle,
        ),
        if (status == 'rejected' && onResubmit != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onResubmit,
              icon: const Icon(Icons.refresh),
              label: const Text('Submit a new request'),
            ),
          ),
        ],
      ],
    );
  }
}



