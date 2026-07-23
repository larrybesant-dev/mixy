import 'package:flutter/material.dart';

/// Responsive grid that adapts form layout based on screen size.
/// Mobile (< 600dp): Single column
/// Tablet (>= 600dp): Two columns
/// Desktop (>= 1200dp): Optimized spacing
class ResponsiveFormGrid extends StatelessWidget {
  final List<ResponsiveGridItem> children;
  final double spacing;
  final double runSpacing;

  const ResponsiveFormGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    if (isMobile) {
      // Single column on mobile
      return Column(
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...[
            children[i].child,
            if (i < children.length - 1) SizedBox(height: spacing),
          ],
        ],
      );
    }

    if (isTablet) {
      // Two-column layout on tablet
      final rows = <List<ResponsiveGridItem>>[];
      for (int i = 0; i < children.length; i += 2) {
        final row = [
          children[i],
          if (i + 1 < children.length) children[i + 1],
        ];
        rows.add(row);
      }

      return Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int j = 0; j < rows[i].length; j++) ...[
                  Expanded(
                    flex: rows[i][j].flex,
                    child: rows[i][j].child,
                  ),
                  if (j < rows[i].length - 1) SizedBox(width: spacing),
                ],
              ],
            ),
            if (i < rows.length - 1) SizedBox(height: runSpacing),
          ],
        ],
      );
    }

    // Desktop layout (max width 860px typically)
    return Column(
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...[
          children[i].child,
          if (i < children.length - 1) SizedBox(height: runSpacing),
        ],
      ],
    );
  }
}

/// Individual grid item with flex specification.
class ResponsiveGridItem {
  final Widget child;
  final int flex;

  ResponsiveGridItem({required this.child, this.flex = 1});
}
