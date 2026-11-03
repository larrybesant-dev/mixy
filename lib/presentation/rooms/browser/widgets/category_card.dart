import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';

class CategoryCard extends StatefulWidget {
  const CategoryCard({
    super.key,
    required this.label,
    required this.emoji,
    required this.gradientColors,
    required this.accent,
    required this.imageAsset,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final List<Color> gradientColors;
  final Color accent;
  final String imageAsset;
  final VoidCallback onTap;

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final radius = BorderRadius.circular(16);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: _isHovered ? 0.22 : 0.12),
              blurRadius: _isHovered ? 22 : 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: DecorationImage(
                image: AssetImage(widget.imageAsset),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  const Color(0xFF000000).withValues(alpha: 0.18),
                  BlendMode.darken,
                ),
              ),
              borderRadius: radius,
              border: Border.all(
                color: accent.withValues(alpha: _isHovered ? 0.55 : 0.28),
              ),
            ),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: radius,
              splashColor: accent.withValues(alpha: 0.14),
              highlightColor: accent.withValues(alpha: 0.08),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x11000000),
                            Color(0x44000000),
                            Color(0xD9000000),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, 0.52, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -30,
                    right: -18,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.035),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              widget.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.label,
                                style: GoogleFonts.raleway(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: VelvetNoir.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AnimatedSlide(
                              duration: const Duration(milliseconds: 160),
                              offset: _isHovered
                                  ? Offset.zero
                                  : const Offset(-0.2, 0),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: accent.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: _isHovered ? 34 : 20,
                          height: 2,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
