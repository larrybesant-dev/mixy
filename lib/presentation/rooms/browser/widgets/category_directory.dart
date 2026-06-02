import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/layout/app_layout.dart';
import '../../../../widgets/brand_ui_kit.dart';
import 'category_card.dart';
import 'go_live_banner.dart';

class CategoryDirectory extends StatelessWidget {
  const CategoryDirectory({
    super.key,
    required this.categories,
    required this.onCategorySelected,
  });

  final List<({String label, String emoji, String? value})> categories;
  final void Function(String? value) onCategorySelected;

  static const Map<String?, List<Color>> _gradients = {
    null: [Color(0xFF1A1210), Color(0xFF3D2B10), Color(0xFFD4A853)],
    'music': [Color(0xFF140D14), Color(0xFF3A0F28), Color(0xFFC45E7A)],
    'talk': [Color(0xFF110E0A), Color(0xFF332208), Color(0xFFFFB74D)],
    'gaming': [Color(0xFF0B1410), Color(0xFF0D3020), Color(0xFF4CAF50)],
    'dance': [Color(0xFF140A14), Color(0xFF350A30), Color(0xFFFF6EB4)],
    'dating': [Color(0xFF140A0D), Color(0xFF3D0A1A), Color(0xFFFF6E84)],
    'study': [Color(0xFF0A0F18), Color(0xFF0D2040), Color(0xFF64B5F6)],
    'art': [Color(0xFF14100A), Color(0xFF3A2808), Color(0xFFFFCA28)],
  };

  static const Map<String?, Color> _accents = {
    null: Color(0xFFD4A853),
    'music': Color(0xFFC45E7A),
    'talk': Color(0xFFFFB74D),
    'gaming': Color(0xFF4CAF50),
    'dance': Color(0xFFFF6EB4),
    'dating': Color(0xFFFF6E84),
    'study': Color(0xFF64B5F6),
    'art': Color(0xFFFFCA28),
  };

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return CustomScrollView(
      key: const PageStorageKey('category_scroll_position'),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(20, topPadding + 24, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B1216), VelvetNoir.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MixvyAppBarLogo(fontSize: 18),
                const SizedBox(height: 10),
                Text(
                  'Find Your Vibe',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: VelvetNoir.onSurface,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a room, join the moment.',
                  style: GoogleFonts.raleway(
                    fontSize: 13,
                    color: VelvetNoir.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.pageHorizontalPadding, 0,
                context.pageHorizontalPadding, 8),
            child: const GoLiveBanner(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.pageHorizontalPadding + 4, 24,
                context.pageHorizontalPadding + 4, 12),
            child: Text(
              'BROWSE BY VIBE',
              style: GoogleFonts.raleway(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.primary.withValues(alpha: 0.7),
                letterSpacing: 2.0,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(context.pageHorizontalPadding, 0,
              context.pageHorizontalPadding, 32),
          sliver: SliverLayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.crossAxisExtent;
              final cols = w > 900 ? 4 : (w > 600 ? 3 : 2);
              return SliverGrid(
                delegate: SliverChildBuilderDelegate((_, i) {
                  final cat = categories[i];
                  final grads = _gradients[cat.value] ?? _gradients[null]!;
                  final accent = _accents[cat.value] ?? VelvetNoir.primary;
                  return CategoryCard(
                    label: cat.label,
                    emoji: cat.emoji,
                    gradientColors: grads,
                    accent: accent,
                    onTap: () => onCategorySelected(cat.value),
                  );
                }, childCount: categories.length),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
