import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/app_layout.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_page_scaffold.dart';

class FeatureDegradedScreen extends StatelessWidget {
  const FeatureDegradedScreen({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryRoute,
    this.secondaryLabel,
    this.secondaryRoute,
    this.icon = Icons.warning_amber_rounded,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final String primaryRoute;
  final String? secondaryLabel;
  final String? secondaryRoute;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(title: const Text('Service status')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(context.pageHorizontalPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x33D4AF37), Color(0x33781E2B)],
                    ),
                    border: Border.all(
                      color: VelvetNoir.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(icon, color: VelvetNoir.primary, size: 32),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: VelvetNoir.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VelvetNoir.onSurfaceVariant,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => context.go(primaryRoute),
                  child: Text(primaryLabel),
                ),
                if (secondaryLabel != null && secondaryRoute != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => context.go(secondaryRoute!),
                    child: Text(secondaryLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
