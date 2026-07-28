import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import 'profile_completion_form.dart';

class ProfileCompletionDialog extends StatelessWidget {
  const ProfileCompletionDialog({
    super.key,
    required this.userId,
    this.initialUsername,
  });

  final String userId;
  final String? initialUsername;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 920),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VelvetNoir.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: VelvetNoir.primary.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ProfileCompletionForm(
              userId: userId,
              initialUsername: initialUsername,
              onCompleted: () {
                if (context.mounted) {
                  context.go('/home');
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the profile completion dialog after signup
void showProfileCompletionDialog(
  BuildContext context,
  String userId, {
  String? initialUsername,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ProfileCompletionDialog(
      userId: userId,
      initialUsername: initialUsername,
    ),
  );
}
