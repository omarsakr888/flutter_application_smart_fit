import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'app/app_scope.dart';
import 'router/app_router.dart';
import 'theme/smart_fit_theme.dart';

void main() {
  runApp(const SmartFitApp());
}

class SmartFitApp extends StatefulWidget {
  const SmartFitApp({super.key});

  @override
  State<SmartFitApp> createState() => _SmartFitAppState();
}

class _SmartFitAppState extends State<SmartFitApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en');

  late final GoRouter _router = createAppRouter();

  void _setThemeBrightness(Brightness? mode) {
    setState(() {
      if (mode == Brightness.dark) {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.light;
      }
    });
  }

  void _toggleLocaleEnAr() {
    setState(() {
      _locale =
          _locale.languageCode == 'en' ? const Locale('ar') : const Locale('en');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      themeMode: _themeMode,
      locale: _locale,
      setThemeBrightness: _setThemeBrightness,
      toggleLocaleEnAr: _toggleLocaleEnAr,
      child: MaterialApp.router(
        title: 'Smart Fit',
        debugShowCheckedModeBanner: false,
        theme: smartFitTheme(Brightness.light),
        darkTheme: smartFitTheme(Brightness.dark),
        themeMode: _themeMode,
        locale: _locale,
        supportedLocales: const [
          Locale('en'),
          Locale('ar'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
      ),
    );
  }
}
