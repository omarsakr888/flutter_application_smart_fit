import 'package:flutter/material.dart';

/// Holds user-facing toggles (theme, locale) reachable from any screen via [of].
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.themeMode,
    required this.locale,
    required this.setThemeBrightness,
    required this.toggleLocaleEnAr,
    required super.child,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final ValueChanged<Brightness?> setThemeBrightness;

  /// Switches between English and Arabic (`Locale('ar')` without country code).
  final VoidCallback toggleLocaleEnAr;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found above context');
    return scope!;
  }

  bool get isDarkActive => themeMode == ThemeMode.dark;

  bool get isEnglish => locale.languageCode == 'en';

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      themeMode != oldWidget.themeMode || locale != oldWidget.locale;
}
