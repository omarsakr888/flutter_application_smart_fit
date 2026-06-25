import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/plan_result.dart';
import '../../models/exercise_view_data.dart';
import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.plan, required this.isDark});

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
          Text(
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

class NutritionCard extends StatelessWidget {
  const NutritionCard({super.key, required this.plan, required this.isDark});

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

class WorkoutCard extends StatelessWidget {
  const WorkoutCard({super.key, required this.plan, required this.isDark});

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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final notes = 'Equipment: ${exercise.equipment}\nMovement Pattern: ${exercise.movementPattern}\nFocus Zone: ${exercise.focusZone}';
                      context.push(
                        AppRoutes.exerciseDetail,
                        extra: ExerciseViewData(
                          name: exercise.name,
                          setsRepsLabel: exercise.setsRepsLabel,
                          targetMuscle: exercise.targetMuscle.isNotEmpty ? exercise.targetMuscle : exercise.bodyPart,
                          notes: notes,
                          dayLabel: plan.workoutSplit[i].dayLabel,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class WarningsCard extends StatelessWidget {
  const WarningsCard({super.key, required this.warnings, required this.isDark});

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

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
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
