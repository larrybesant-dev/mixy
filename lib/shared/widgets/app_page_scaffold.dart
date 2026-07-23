import 'package:flutter/material.dart';

import '../../core/layout/app_layout.dart';
import '../../core/theme.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.floatingActionButton,
    this.safeArea = true,
    this.padContent = false,
    this.padding,
    this.maxContentWidth,
    this.resizeToAvoidBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final bool safeArea;
  final bool padContent;
  final EdgeInsetsGeometry? padding;
  final double? maxContentWidth;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    final scaffoldColor =
        backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    if (padContent) {
      content = Padding(
        padding: padding ?? context.pagePadding,
        child: content,
      );
    }

    content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxContentWidth ?? context.contentMaxWidth,
        ),
        child: content,
      ),
    );

    if (safeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      appBar: appBar,
      backgroundColor: scaffoldColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: BoxDecoration(color: scaffoldColor)),
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -40,
                  child: _BackdropOrb(
                    size: 260,
                    color: VelvetNoir.primary.withValues(alpha: 0.08),
                  ),
                ),
                Positioned(
                  top: 120,
                  left: -120,
                  child: _BackdropOrb(
                    size: 280,
                    color: VelvetNoir.secondary.withValues(alpha: 0.08),
                  ),
                ),
                Positioned(
                  bottom: -140,
                  right: 40,
                  child: _BackdropOrb(
                    size: 320,
                    color: VelvetNoir.surfaceBright.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          content,
        ],
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}



