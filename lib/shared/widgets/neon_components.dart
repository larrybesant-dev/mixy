import 'package:flutter/material.dart';
import '../../core/theme/neon_colors.dart';

/// ============================================================================
/// NEON GLOW COMPONENTS - Electric Lounge Design System
/// Mix & Mingle Brand-Aligned Components with Glow Effects
/// ============================================================================

/// Neon-styled card with colorful glowing border
class NeonGlowCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double glowRadius;
  final double borderRadius;
  final double elevation;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const NeonGlowCard({
    super.key,
    required this.child,
    this.glowColor = NeonColors.neonBlue,
    this.glowRadius = 16,
    this.borderRadius = 16,
    this.elevation = 12,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            // Outer glow effect
            BoxShadow(
              color: glowColor.withValues(alpha: 0.6),
              blurRadius: glowRadius,
              spreadRadius: 2,
            ),
            // Inner shadow for depth
            BoxShadow(
              color: glowColor.withValues(alpha: 0.3),
              blurRadius: glowRadius / 2,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: NeonColors.darkCard,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: glowColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Animated neon button with glow effect
class NeonButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final Color glowColor;
  final Color textColor;
  final double width;
  final double height;
  final IconData? icon;
  final bool isLoading;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.glowColor = NeonColors.neonOrange,
    this.textColor = Colors.white,
    this.width = double.infinity,
    this.height = 48,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(
                  alpha: 0.4 * _glowAnimation.value,
                ),
                blurRadius: 16 * _glowAnimation.value,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: widget.isLoading ? null : widget.onPressed,
            icon: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.glowColor,
                      ),
                    ),
                  )
                : (widget.icon != null ? Icon(widget.icon) : const SizedBox()),
            label: Text(widget.label),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.glowColor,
              foregroundColor: widget.textColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Neon text with glow effect
class NeonText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color textColor;
  final Color glowColor;
  final double glowRadius;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final double letterSpacing;

  const NeonText(
    this.text, {
    super.key,
    this.fontSize = 24,
    this.fontWeight = FontWeight.bold,
    this.textColor = NeonColors.textPrimary,
    this.glowColor = NeonColors.neonOrange,
    this.glowRadius = 8,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.letterSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: textColor,
        letterSpacing: letterSpacing > 0 ? letterSpacing : null,
        shadows: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.6),
            blurRadius: glowRadius,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Neon gradient container with ambient glow
class NeonGradientContainer extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  final BorderRadius borderRadius;
  final double glowOpacity;
  final EdgeInsets padding;

  const NeonGradientContainer({
    super.key,
    required this.child,
    this.colors = const [NeonColors.neonOrange, NeonColors.neonBlue],
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.glowOpacity = 0.2,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0.0, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: glowOpacity),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Animated glow effect container (ambient/breathing effect)
class AmbientGlowContainer extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double maxGlowRadius;
  final Duration duration;
  final BorderRadius borderRadius;

  const AmbientGlowContainer({
    super.key,
    required this.child,
    this.glowColor = NeonColors.neonBlue,
    this.maxGlowRadius = 20,
    this.duration = const Duration(seconds: 3),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<AmbientGlowContainer> createState() => _AmbientGlowContainerState();
}

class _AmbientGlowContainerState extends State<AmbientGlowContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(
                  alpha: 0.5 * _glowAnimation.value,
                ),
                blurRadius: widget.maxGlowRadius * _glowAnimation.value,
                spreadRadius: 2 * _glowAnimation.value,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              color: NeonColors.darkCard,
              border: Border.all(
                color: widget.glowColor
                    .withValues(alpha: 0.3 * _glowAnimation.value),
                width: 1,
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Neon input field with glow
class NeonInputField extends StatefulWidget {
  final TextEditingController? controller;
  final String hint;
  final String? label;
  final Color focusGlowColor;
  final IconData? prefixIcon;
  final int maxLines;
  final int? maxLength;
  final TextInputType keyboardType;
  final bool obscureText;

  const NeonInputField({
    super.key,
    this.controller,
    required this.hint,
    this.label,
    this.focusGlowColor = NeonColors.neonBlue,
    this.prefixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
  });

  @override
  State<NeonInputField> createState() => _NeonInputFieldState();
}

class _NeonInputFieldState extends State<NeonInputField>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _glowController.forward();
    } else {
      _glowController.reverse();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.focusGlowColor
                    .withValues(alpha: 0.4 * _glowAnimation.value),
                blurRadius: 12 * _glowAnimation.value,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            minLines: widget.maxLines > 1 ? 1 : null,
            obscureText: widget.obscureText,
            maxLength: widget.maxLength,
            buildCounter: widget.maxLength != null
                ? null
                : (_, {required currentLength, required isFocused, maxLength}) => null,
            style: const TextStyle(
              color: NeonColors.textPrimary,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              labelText: widget.label,
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: widget.focusGlowColor,
                    )
                  : null,
              filled: true,
              fillColor: NeonColors.darkCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: NeonColors.divider,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: NeonColors.divider.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.focusGlowColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintStyle: const TextStyle(
                color: NeonColors.textTertiary,
              ),
              labelStyle: TextStyle(
                color: widget.focusGlowColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Neon divider with gradient
class NeonDivider extends StatelessWidget {
  final Color startColor;
  final Color endColor;
  final double height;
  final double thickness;

  const NeonDivider({
    super.key,
    this.startColor = NeonColors.neonOrange,
    this.endColor = NeonColors.neonBlue,
    this.height = 1,
    this.thickness = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [startColor, endColor],
        ),
        boxShadow: [
          BoxShadow(
            color: startColor.withValues(alpha: 0.3),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

/// Badge with neon styling
class NeonBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;

  const NeonBadge({
    super.key,
    required this.label,
    this.backgroundColor = NeonColors.neonOrange,
    this.textColor = Colors.white,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
