import 'package:flutter/material.dart';

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  // Breakpoints
  bool get isSmallPhone => screenWidth < 360;
  bool get isTablet => screenWidth >= 600;

  // Fluid scaling helpers
  double heightPct(double percent) => screenHeight * percent;
  double widthPct(double percent) => screenWidth * percent;

  // Responsive typography
  double responsiveFontSize(double baseSize) {
    if (isTablet) return baseSize * 1.2;
    if (isSmallPhone) return baseSize * 0.9;
    return baseSize;
  }
}
