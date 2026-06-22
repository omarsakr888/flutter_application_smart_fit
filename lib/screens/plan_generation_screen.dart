import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../models/ocr_result.dart';
import '../models/plan_result.dart';
import '../router/app_routes.dart';
import '../services/scan_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_chat_fab.dart';
import '../widgets/laser_scanner.dart';

class PlanGenerationScreen extends StatefulWidget {
  const PlanGenerationScreen({super.key, this.ocrResult});

  final OcrExtractResult? ocrResult;

  static const _stepLabels = [
    'Reading InBody metrics',
    'Running ML focus-zone model',
    'Calculating calorie target',
    'Determining macro split',
    'Building workout split',
    'Assembling meal plan',
  ];

  @override
  State<PlanGenerationScreen> createState() => _PlanGenerationScreenState();
}

class _PlanGenerationScreenState extends State<PlanGenerationScreen> {
  PlanResult? _plan;
  String? _error;
  int _activeStep = 0;
  Timer? _stepTimer;

  bool get _loading => _plan == null && _error == null;

  @override
  void initState() {
    super.initState();
    _startStepAnimation();
    _generatePlan();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  void _startStepAnimation() {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted || !_loading) {
        t.cancel();
        return;
      }
      setState(() {
        if (_activeStep < PlanGenerationScreen._stepLabels.length - 1) {
          _activeStep++;
        }
      });
    });
  }

  Future<void> _generatePlan() async {
    final ocr = widget.ocrResult;
    if (ocr == null) {
      setState(() => _error = 'No scan data available.');
      return;
    }

    setState(() {
      _plan = null;
      _error = null;
      _activeStep = 0;
    });

    try {
      final plan = await ScanService.instance.generatePlan(ocr);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _activeStep = PlanGenerationScreen._stepLabels.length - 1;
      });
      _stepTimer?.cancel();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      _stepTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      bottomNavigationBar: isDark && !_loading ? const _BottomNav() : null,
      floatingActionButton: const AiChatFab(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              isDark: isDark,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.inBodyScan);
                }
              },
              onLight: () => scope.setThemeBrightness(Brightness.light),
              onDark: () => scope.setThemeBrightness(Brightness.dark),
            ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF262D2F) : const Color(0xFFEDEFF0),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, isDark ? 28 : 36, 20, 28),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  child: _loading
                      ? _LoadingBody(key: const ValueKey('loading'), activeStep: _activeStep, isDark: isDark)
                      : _error != null
                          ? _ErrorBody(
                              key: const ValueKey('error'),
                              message: _error!,
                              onRetry: _generatePlan,
                              isDark: isDark,
                            )
                          : _PlanBody(key: const ValueKey('plan'), plan: _plan!, isDark: isDark),
                ),
              ),
            ),
            if (!_loading && _plan != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  14 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isDark ? 8 : 7),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: () => context.go(AppRoutes.homeDashboard),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isDark ? 8 : 7),
                      ),
                    ),
                    child: const Text(
                      'Go to Dashboard',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({super.key, required this.activeStep, required this.isDark});

  final int activeStep;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = [
      for (var i = 0; i < PlanGenerationScreen._stepLabels.length; i++)
        _StepLabel(
          PlanGenerationScreen._stepLabels[i],
          i < activeStep
              ? _StepState.done
              : i == activeStep
                  ? _StepState.active
                  : _StepState.pending,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: LaserScanner(
            axis: LaserScanAxis.horizontal,
            width: 300,
            height: 88,
            icon: Icons.auto_awesome_outlined,
            iconSize: 40,
          ),
        ),
        const SizedBox(height: 40),
        Text(
          'Generating your plans',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Math engine, ML model, and matching engine are building your personalised workout and nutrition plans…',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white60 : const Color(0xFF7B7D85),
            height: 1.35,
          ),
        ),
        SizedBox(height: isDark ? 48 : 40),
        _StepsCard(steps: steps, isDark: isDark),
      ],
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({super.key, required this.plan, required this.isDark});

  final PlanResult plan;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StaggeredFade(
          delay: const Duration(milliseconds: 100),
          child: Text(
            'Your personalised plans',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _StaggeredFade(
          delay: const Duration(milliseconds: 200),
          child: Text(
            'Generated from your InBody scan and AI engines.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? Colors.white60 : const Color(0xFF7B7D85),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _StaggeredFade(
          delay: const Duration(milliseconds: 400),
          child: _SummaryCard(plan: plan, isDark: isDark),
        ),
        const SizedBox(height: 24),
        _StaggeredFade(
          delay: const Duration(milliseconds: 700),
          child: _SectionHeader(
            icon: Icons.restaurant_rounded,
            title: 'Nutrition Plan',
            subtitle: '${plan.dailyMeals.length} meals · ${plan.targetCaloriesKcal.round()} kcal/day',
          ),
        ),
        const SizedBox(height: 12),
        _StaggeredFade(
          delay: const Duration(milliseconds: 800),
          child: _NutritionCard(plan: plan, isDark: isDark),
        ),
        const SizedBox(height: 24),
        _StaggeredFade(
          delay: const Duration(milliseconds: 1000),
          child: _SectionHeader(
            icon: Icons.fitness_center_rounded,
            title: 'Workout Plan',
            subtitle: '${plan.preferredDays} days/week · ${plan.workoutSplit.length} sessions',
          ),
        ),
        const SizedBox(height: 12),
        _StaggeredFade(
          delay: const Duration(milliseconds: 1100),
          child: _WorkoutCard(plan: plan, isDark: isDark),
        ),
        if (plan.warnings.isNotEmpty) ...[
          const SizedBox(height: 20),
          _StaggeredFade(
            delay: const Duration(milliseconds: 1200),
            child: _WarningsCard(warnings: plan.warnings, isDark: isDark),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.plan, required this.isDark});

  final PlanResult plan;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Chip(label: plan.focusZone, color: AppColors.teal),
          const SizedBox(height: 16),
          Text(
            'Body Part Focus Zone: ${plan.focusZone}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1D2425),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _getFocusZoneExplanation(plan.focusZone),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : const Color(0xFF5A5E66),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 8),
          _TypewriterText(
            plan.intensityReason,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.white70 : const Color(0xFF5A5E66),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Calories',
                  value: '${plan.targetCaloriesKcal.round()}',
                  unit: 'kcal',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Training Advice',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.teal,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            _getIntensityExplanation(plan.intensityMultiplier),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : const Color(0xFF333A3C),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Macros — P ${plan.macros.proteinG.round()}g · C ${plan.macros.carbsG.round()}g · F ${plan.macros.fatG.round()}g',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isDark ? Colors.white54 : const Color(0xFF8A8D93),
                ),
          ),
        ],
      ),
    );
  }

  String _getFocusZoneExplanation(String zone) {
    final l = zone.toLowerCase();
    if (l.contains('upper')) return 'Focusing on upper body strength will help correct your muscle imbalances and improve posture.';
    if (l.contains('lower')) return 'Strengthening your lower body provides a solid foundation, boosting metabolism and athletic performance.';
    if (l.contains('core')) return 'Core-focused training stabilizes your spine and improves all-around athletic movements.';
    if (l.contains('recovery') || l.contains('rehab')) return 'Prioritizing recovery allows your central nervous system to heal, reducing injury risk.';
    return 'A balanced approach ensures holistic muscle development and optimal cardiovascular health.';
  }

  String _getIntensityExplanation(double multiplier) {
    if (multiplier < 0.8) {
      return 'Low Intensity: Your scan indicates high fatigue or recovery needs. We will focus on active recovery and light movements to protect your joints and CNS.';
    } else if (multiplier <= 1.0) {
      return 'Moderate Intensity: You are in a balanced state. Workouts will be challenging but manageable, optimizing steady progress without overtraining.';
    } else {
      return 'High Intensity: Your biomarkers show excellent recovery capacity. You are cleared for maximum effort training to push your limits and accelerate results.';
    }
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.plan, required this.isDark});

  final PlanResult plan;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      isDark: isDark,
      child: Column(
        children: [
          for (var i = 0; i < plan.dailyMeals.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _MealRow(meal: plan.dailyMeals[i], isDark: isDark),
          ],
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.plan, required this.isDark});

  final PlanResult plan;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < plan.workoutSplit.length; i++) ...[
            if (i > 0) const Divider(height: 28),
            Text(
              plan.workoutSplit[i].dayLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (plan.workoutSplit[i].note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                plan.workoutSplit[i].note,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white54 : const Color(0xFF8A8D93),
                    ),
              ),
            ],
            const SizedBox(height: 12),
            for (final exercise in plan.workoutSplit[i].exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.fitness_center_outlined,
                      size: 20,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            '${exercise.setsRepsLabel} · ${exercise.bodyPart}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.white54 : const Color(0xFF8A8D93),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    super.key,
    required this.message,
    required this.onRetry,
    required this.isDark,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade400),
        const SizedBox(height: 20),
        Text(
          'Plan generation failed',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDark ? Colors.white60 : const Color(0xFF7B7D85),
              ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

enum _StepState { done, active, pending }

class _StepLabel {
  const _StepLabel(this.label, this.state);
  final String label;
  final _StepState state;
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps, required this.isDark});

  final List<_StepLabel> steps;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 14 : 24),
        border: Border.all(
          color: isDark ? const Color(0xFF141C19) : const Color(0xFFECEEEF),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(isDark ? 24 : 32, 28, 20, 28),
        child: Column(
          children: [
            for (final step in steps) ...[
              _StepRow(step: step, isDark: isDark),
              if (step != steps.last) const SizedBox(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.isDark});

  final _StepLabel step;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final doneColor = isDark ? const Color(0xFF6ED8BE) : AppColors.teal;
    final muted = isDark ? const Color(0xFF676D7A) : const Color(0xFFD4D5D8);

    final icon = switch (step.state) {
      _StepState.done => Icon(Icons.check_circle_outline_rounded, color: doneColor, size: 26),
      _StepState.active => Icon(Icons.circle, color: AppColors.teal, size: 16),
      _StepState.pending => Icon(Icons.circle_outlined, color: muted, size: 15),
    };

    final textColor = switch (step.state) {
      _StepState.done => muted,
      _StepState.active => Theme.of(context).colorScheme.onSurface,
      _StepState.pending => muted,
    };

    return Row(
      children: [
        SizedBox(width: 32, child: Center(child: icon)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            step.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: step.state == _StepState.active ? FontWeight.w700 : FontWeight.w400,
                  decoration: step.state == _StepState.done ? TextDecoration.lineThrough : null,
                ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: AppColors.teal, size: 24),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white54
                          : const Color(0xFF8A8D93),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.isDark, required this.child});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121816) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 14 : 16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E2624) : const Color(0xFFECEEEF),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.isDark,
  });

  final String label;
  final String value;
  final String unit;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A211F) : const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isDark ? Colors.white54 : const Color(0xFF8A8D93),
                  ),
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: isDark ? Colors.white54 : const Color(0xFF8A8D93),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.isDark});

  final MealSlot meal;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.restaurant_outlined, color: AppColors.teal, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal.displayName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                meal.recipeName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white70 : const Color(0xFF5A5E66),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${meal.caloriesPerServing.round()} kcal · P ${meal.proteinG.round()}g · C ${meal.carbsG.round()}g · F ${meal.fatG.round()}g',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white54 : const Color(0xFF8A8D93),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings, required this.isDark});

  final List<String> warnings;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : const Color(0xFF7B7D85),
                          ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isDark,
    required this.onBack,
    required this.onLight,
    required this.onDark,
  });

  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isDark ? 52 : 72,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isDark ? 12 : 24, 6, isDark ? 18 : 28, 6),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const Spacer(),
            _ThemeSegment(isDark: isDark, onLight: onLight, onDark: onDark),
          ],
        ),
      ),
    );
  }
}

class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const _TypewriterText(this.text, {this.style});

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _lengthAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _lengthAnimation = IntTween(begin: 0, end: widget.text.length).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Opacity(
          opacity: 0,
          child: Text(widget.text, style: widget.style),
        ),
        AnimatedBuilder(
          animation: _lengthAnimation,
          builder: (context, child) {
            return Text(
              widget.text.substring(0, _lengthAnimation.value),
              style: widget.style,
            );
          },
        ),
      ],
    );
  }
}

class _StaggeredFade extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _StaggeredFade({required this.child, required this.delay});

  @override
  State<_StaggeredFade> createState() => _StaggeredFadeState();
}

class _StaggeredFadeState extends State<_StaggeredFade> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({
    required this.isDark,
    required this.onLight,
    required this.onDark,
  });

  final bool isDark;
  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF202927) : const Color(0xFFF1F3F4);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeButton(selected: !isDark, icon: Icons.wb_sunny_outlined, onTap: onLight),
            const SizedBox(width: 4),
            _ThemeButton(selected: isDark, icon: Icons.dark_mode_rounded, onTap: onDark),
          ],
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected ? AppColors.teal : Colors.transparent,
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
            color: selected ? Colors.white : (isDark ? Colors.white38 : const Color(0xFF9AA0A7)),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF111111)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _NavItem(Icons.dashboard_outlined, 'Dashboard', true),
            _NavItem(Icons.fitness_center_rounded, 'Workouts', false),
            _NavItem(Icons.smart_toy_outlined, 'AI Coach', false),
            _NavItem(Icons.restaurant_rounded, 'Nutrition', false),
            _NavItem(Icons.person_outline_rounded, 'Profile', false),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(this.icon, this.label, this.selected);

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2DB994) : const Color(0xFF5B5C67);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
