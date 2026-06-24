import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/responsive/responsive_utils.dart';
import 'package:mixvy/core/accessibility/accessibility_utils.dart';

class ThemeToggleWidget extends ConsumerWidget {
  const ThemeToggleWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get brightness from MediaQuery instead
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return ResponsiveContainer(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: Responsive.responsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveText(
                'Theme',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              SizedBox(height: Responsive.responsiveSpacing(context, 16)),
              Responsive.isMobile(context)
                  ? Column(
                      children: [
                        _ThemeOption(
                          title: 'Light',
                          subtitle: 'Bright and clean',
                          icon: Icons.light_mode,
                          isSelected: !isDark,
                          onTap: () {},
                        ),
                        const SizedBox(height: 12),
                        _ThemeOption(
                          title: 'Dark',
                          subtitle: 'Easy on the eyes',
                          icon: Icons.dark_mode,
                          isSelected: isDark,
                          onTap: () {},
                        ),
                        const SizedBox(height: 12),
                        _ThemeOption(
                          title: 'System',
                          subtitle: 'Follow device',
                          icon: Icons.settings_system_daydream,
                          isSelected: true,
                          onTap: () {},
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _ThemeOption(
                            title: 'Light',
                            subtitle: 'Bright and clean',
                            icon: Icons.light_mode,
                            isSelected: !isDark,
                            onTap: () {},
                          ),
                        ),
                        SizedBox(
                            width: Responsive.responsiveSpacing(context, 12)),
                        Expanded(
                          child: _ThemeOption(
                            title: 'Dark',
                            subtitle: 'Easy on the eyes',
                            icon: Icons.dark_mode,
                            isSelected: isDark,
                            onTap: () {},
                          ),
                        ),
                        SizedBox(
                            width: Responsive.responsiveSpacing(context, 12)),
                        Expanded(
                          child: _ThemeOption(
                            title: 'System',
                            subtitle: 'Follow device',
                            icon: Icons.settings_system_daydream,
                            isSelected: true,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label: AccessibilityUtils.createSemanticLabel(
        primaryLabel: title,
        secondaryLabel: subtitle,
        hint: 'Double tap to select this theme',
        isSelected: isSelected,
      ),
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : theme.colorScheme.primary.withValues(alpha: 0.1))
                : theme.cardColor,
            border: Border.all(
              color:
                  isSelected ? theme.colorScheme.primary : theme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: Responsive.responsiveIconSize(context, 24),
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              SizedBox(height: Responsive.responsiveSpacing(context, 8)),
              ResponsiveText(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Responsive.responsiveSpacing(context, 4)),
              ResponsiveText(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ).ensureMinimumTouchTarget(),
    );
  }
}

