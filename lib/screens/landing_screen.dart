import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../localization/landing_strings.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/smart_fit_theme.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = scope.locale;
    final ext = context.smartFitExt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _TopBar(
                isDark: isDark,
                isEnglish: scope.isEnglish,
                onLight: () => scope.setThemeBrightness(Brightness.light),
                onDark: () => scope.setThemeBrightness(Brightness.dark),
                onToggleLang: scope.toggleLocaleEnAr,
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _LogoBubble(isDark: isDark),
                      const SizedBox(height: 22),
                      Text(
                        LandingStrings.title(l),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        LandingStrings.tagline(l),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: ext.mutedText,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 32),
                      _FeatureCard(
                        icon: Icons.biotech_rounded,
                        label: LandingStrings.feature1(l),
                      ),
                      const SizedBox(height: 12),
                      _FeatureCard(
                        icon: Icons.smart_toy_outlined,
                        label: LandingStrings.feature2(l),
                      ),
                      const SizedBox(height: 12),
                      _FeatureCard(
                        icon: Icons.lock_rounded,
                        iconColor: AppColors.accentGold,
                        label: LandingStrings.feature3(l),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => context.push(AppRoutes.getStarted),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: ext.primaryButtonFg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(LandingStrings.getStarted(l)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.push(AppRoutes.logIn),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    side: const BorderSide(color: AppColors.teal, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(LandingStrings.logIn(l)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isDark,
    required this.isEnglish,
    required this.onLight,
    required this.onDark,
    required this.onToggleLang,
  });

  final bool isDark;
  final bool isEnglish;
  final VoidCallback onLight;
  final VoidCallback onDark;
  final VoidCallback onToggleLang;

  @override
  Widget build(BuildContext context) {
    final ext = context.smartFitExt;
    final inactive = ext.inactiveTint;
    final inactiveIcon =
        Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black45;

    return Row(
      children: [
        _ThemeOrb(
          selected: !isDark,
          activeBg: AppColors.teal,
          inactiveBg: inactive,
          icon: Icons.wb_sunny_rounded,
          iconWhenActive: Colors.white,
          iconWhenIdle: inactiveIcon,
          onTap: onLight,
        ),
        const SizedBox(width: 10),
        _ThemeOrb(
          selected: isDark,
          activeBg: AppColors.teal,
          inactiveBg: inactive,
          icon: Icons.dark_mode_rounded,
          iconWhenActive: Colors.white,
          iconWhenIdle: inactiveIcon,
          onTap: onDark,
        ),
        const Spacer(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggleLang,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  children: [
                    TextSpan(
                      text: 'EN',
                      style: TextStyle(
                        color: isEnglish ? AppColors.teal : ext.mutedText,
                      ),
                    ),
                    TextSpan(
                      text: ' | ',
                      style: TextStyle(color: ext.mutedText),
                    ),
                    TextSpan(
                      text: 'AR',
                      style: TextStyle(
                        color: !isEnglish ? AppColors.teal : ext.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeOrb extends StatelessWidget {
  const _ThemeOrb({
    required this.selected,
    required this.activeBg,
    required this.inactiveBg,
    required this.icon,
    required this.iconWhenActive,
    required this.iconWhenIdle,
    required this.onTap,
  });

  final bool selected;
  final Color activeBg;
  final Color inactiveBg;
  final IconData icon;
  final Color iconWhenActive;
  final Color iconWhenIdle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? activeBg : inactiveBg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: selected ? iconWhenActive : iconWhenIdle,
          ),
        ),
      ),
    );
  }
}

class _LogoBubble extends StatelessWidget {
  const _LogoBubble({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withOpacity(isDark ? 0.35 : 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Transform.rotate(
        angle: -0.45,
        child: const Icon(
          Icons.fitness_center_rounded,
          color: Colors.white,
          size: 44,
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final ext = context.smartFitExt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 28,
            color: iconColor ?? AppColors.teal,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
