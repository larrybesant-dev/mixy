import 'package:flutter/material.dart';

class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 960;
  static const double expanded = 1280;
}

extension AppLayoutContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;

  bool get isCompactLayout => screenWidth < AppBreakpoints.compact;
  bool get isMediumLayout =>
      screenWidth >= AppBreakpoints.compact &&
      screenWidth < AppBreakpoints.medium;
  bool get isExpandedLayout => screenWidth >= AppBreakpoints.medium;

  double get contentMaxWidth {
    if (screenWidth >= AppBreakpoints.expanded) return 1120;
    if (screenWidth >= AppBreakpoints.medium) return 960;
    return screenWidth;
  }

  double get pageHorizontalPadding {
    if (screenWidth >= AppBreakpoints.expanded) return 32;
    if (screenWidth >= AppBreakpoints.compact) return 24;
    return 16;
  }

  double get sectionSpacing {
    if (screenWidth >= AppBreakpoints.expanded) return 28;
    if (screenWidth >= AppBreakpoints.compact) return 24;
    return 16;
  }

  EdgeInsets get pagePadding =>
      EdgeInsets.symmetric(horizontal: pageHorizontalPadding);
}



