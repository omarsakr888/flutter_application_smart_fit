import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

ThemeData smartFitTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final textTheme = GoogleFonts.interTextTheme(
    isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
  );

  final scaffold = isDark ? const Color(0xFF121517) : Colors.white;
  final surfaceCard = isDark ? const Color(0xFF1C2225) : const Color(0xFFF3F6F5);
  final onBg = isDark ? const Color(0xFFECEFF1) : const Color(0xFF111827);
  final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  final inactiveGrey = isDark ? const Color(0xFF2A3236) : const Color(0xFFE8EBEA);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: scaffold,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
      primary: AppColors.teal,
      surface: scaffold,
      onSurface: onBg,
    ),
    textTheme: textTheme,
    dividerColor: isDark ? const Color(0xFF2F3A40) : const Color(0xFFE5E7EB),
    extensions: <ThemeExtension<dynamic>>[
      SmartFitThemeExt(
        cardBackground: surfaceCard,
        mutedText: muted,
        inactiveTint: inactiveGrey,
        primaryButtonFg: Colors.white,
      ),
    ],
  );
}

/// Custom tokens referenced from widgets (cards, inactive toggles, etc.).
@immutable
class SmartFitThemeExt extends ThemeExtension<SmartFitThemeExt> {
  const SmartFitThemeExt({
    required this.cardBackground,
    required this.mutedText,
    required this.inactiveTint,
    required this.primaryButtonFg,
  });

  final Color cardBackground;
  final Color mutedText;
  final Color inactiveTint;
  final Color primaryButtonFg;

  @override
  SmartFitThemeExt copyWith({
    Color? cardBackground,
    Color? mutedText,
    Color? inactiveTint,
    Color? primaryButtonFg,
  }) {
    return SmartFitThemeExt(
      cardBackground: cardBackground ?? this.cardBackground,
      mutedText: mutedText ?? this.mutedText,
      inactiveTint: inactiveTint ?? this.inactiveTint,
      primaryButtonFg: primaryButtonFg ?? this.primaryButtonFg,
    );
  }

  @override
  ThemeExtension<SmartFitThemeExt> lerp(
    covariant ThemeExtension<SmartFitThemeExt>? other,
    double t,
  ) {
    if (other is! SmartFitThemeExt) return this;
    return SmartFitThemeExt(
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      inactiveTint: Color.lerp(inactiveTint, other.inactiveTint, t)!,
      primaryButtonFg: Color.lerp(primaryButtonFg, other.primaryButtonFg, t)!,
    );
  }
}

extension SmartFitThemeContext on BuildContext {
  SmartFitThemeExt get smartFitExt =>
      Theme.of(this).extension<SmartFitThemeExt>() ??
      const SmartFitThemeExt(
        cardBackground: Color(0xFFF3F6F5),
        mutedText: Color(0xFF6B7280),
        inactiveTint: Color(0xFFE8EBEA),
        primaryButtonFg: Colors.white,
      );
}
