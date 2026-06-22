import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/plan_result.dart';
import '../router/app_routes.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_utils.dart';
import '../widgets/ai_chat_fab.dart';
import '../widgets/smart_fit_app_bar.dart';
import '../widgets/smart_fit_drawer.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  PlanResult? _plan;
  final _loggedMeals = <int, double>{};
  int _hydrationCups = 0;
  static const _hydrationTarget = 8;
  bool _loading = true;
  Timer? _countdownTimer;
  Duration _nextMealIn = Duration.zero;

  static const _fallbackLight = [
    _Meal('Breakfast', 'Oatmeal with Berries - 320 kcal', 'Fiber', Icons.rice_bowl_rounded, true),
    _Meal('Lunch', 'Grilled Chicken Salad - 450 kcal', 'High Protein', Icons.local_dining_rounded, true),
    _Meal('Dinner', 'Salmon & Asparagus - 580 kcal', 'Keto Friendly', Icons.set_meal_rounded, false),
    _Meal('Snack', 'Apple & Almond Butter - 180 kcal', 'Low Carb', Icons.eco_rounded, false),
  ];

  static const _fallbackDark = [
    _Meal('Breakfast', 'Berry Protein Oatmeal', '420 kcal', Icons.rice_bowl_rounded, true),
    _Meal('Lunch', 'Grilled Chicken Power Bowl', '580 kcal', Icons.local_dining_rounded, true),
    _Meal('Dinner', 'Lemon Herb Salmon', '450 kcal', Icons.set_meal_rounded, false),
    _Meal('Snack', 'Greek Yogurt & Almonds', '192 kcal', Icons.icecream_rounded, false),
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
    _loadHydration();
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _updateCountdown());
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Standard meal times (24h): breakfast 8h, lunch 13h, snack 16h, dinner 20h
  static const _mealHours = [8, 13, 16, 20];

  void _updateCountdown() {
    final now = DateTime.now();
    for (final h in _mealHours) {
      final meal = DateTime(now.year, now.month, now.day, h);
      if (meal.isAfter(now)) {
        _nextMealIn = meal.difference(now);
        return;
      }
    }
    // All meals passed — next is breakfast tomorrow
    final tomorrow = DateTime(now.year, now.month, now.day + 1, _mealHours.first);
    _nextMealIn = tomorrow.difference(now);
  }

  String get _countdownText {
    final h = _nextMealIn.inHours.toString().padLeft(2, '0');
    final m = (_nextMealIn.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_nextMealIn.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _fetch() async {
    try {
      final plan = await UserService.instance.getPlan();
      if (mounted) setState(() { _plan = plan; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load meal plan. Check your connection.')),
        );
      }
    }
  }

  Future<void> _loadHydration() async {
    try {
      final cups = await UserService.instance.getTodayHydrationCups();
      if (mounted) setState(() => _hydrationCups = cups);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load hydration data.')),
        );
      }
    }
  }

  Future<void> _addHydration() async {
    if (_hydrationCups >= _hydrationTarget) return;
    setState(() => _hydrationCups++);
    try {
      await UserService.instance.logHydration();
    } catch (_) {
      if (mounted) {
        setState(() => _hydrationCups--);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log hydration. Try again.')),
        );
      }
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatHeaderDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  Future<void> _logMeal(BuildContext ctx, int index, _Meal meal) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dlg) => AlertDialog(
        title: Text('Log ${meal.title}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Calories consumed (optional)',
            suffixText: 'kcal',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dlg, true),
            child: const Text('Log'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final calories = double.tryParse(controller.text) ?? 0;
    setState(() => _loggedMeals[index] = calories);
    try {
      await UserService.instance.logMeal(
        meal.title,
        planId: _plan?.planId,
        caloriesConsumed: calories,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _loggedMeals.remove(index));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log meal. Try again.')),
        );
      }
    }
  }

  List<_Meal> _buildMeals(bool isDark) {
    final plan = _plan;
    if (plan == null || plan.dailyMeals.isEmpty) {
      return isDark ? _fallbackDark : _fallbackLight;
    }
    return plan.dailyMeals.map((m) {
      final kcal = m.caloriesPerServing.round();
      final subtitle = isDark ? m.recipeName : '${m.recipeName} - $kcal kcal';
      final badge = isDark ? '$kcal kcal' : '${m.proteinG.round()}g protein';
      return _Meal(m.displayName, subtitle, badge, Icons.restaurant_rounded, false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final meals = _buildMeals(isDark);
    final caloriesConsumed =
        _loggedMeals.values.fold(0.0, (a, b) => a + b).round();
    final caloriesTarget = _plan?.targetCaloriesKcal.round() ?? 2240;
    final proteinG = _plan?.macros.proteinG.round() ?? 160;
    final carbsG = _plan?.macros.carbsG.round() ?? 224;
    final fatG = _plan?.macros.fatG.round() ?? 75;

    return Scaffold(
      appBar: const SmartFitAppBar(),
      drawer: const SmartFitDrawer(),
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF4F4F4),
      bottomNavigationBar: const _BottomNav(),
      floatingActionButton: const AiChatFab(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_loading)
              LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.teal,
                backgroundColor: AppColors.teal.withValues(alpha: 0.12),
              ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF2A2A2A) : Colors.transparent,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  context.widthPct(0.05),
                  isDark ? context.heightPct(0.04) : context.heightPct(0.06),
                  context.widthPct(0.05),
                  context.heightPct(0.04),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isDark)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Nutrition',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _formatHeaderDate(DateTime.now()),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF60666A),
                            ),
                          ),
                        ],
                      ),
                    if (!isDark) SizedBox(height: context.heightPct(0.06)),
                    _MacrosCard(
                      caloriesConsumed: caloriesConsumed,
                      caloriesTarget: caloriesTarget,
                      proteinG: proteinG,
                      carbsG: carbsG,
                      fatG: fatG,
                    ),
                    SizedBox(height: isDark ? context.heightPct(0.05) : context.heightPct(0.06)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Meal Plan',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isDark) const _TodayPill(),
                      ],
                    ),
                    SizedBox(height: context.heightPct(0.025)),
                    for (var i = 0; i < meals.length; i++) ...[
                      _MealTile(
                        meal: meals[i],
                        focused: !isDark && i == 2,
                        isLogged: _loggedMeals.containsKey(i),
                        onLog: () => _logMeal(context, i, meals[i]),
                        onTap: () => context.push(
                          AppRoutes.recipeDetail,
                          extra: _plan?.dailyMeals.elementAtOrNull(i),
                        ),
                      ),
                      SizedBox(height: context.heightPct(0.02)),
                    ],
                    if (isDark) ...[
                      SizedBox(height: context.heightPct(0.025)),
                      _HydrationPanel(
                        cups: _hydrationCups,
                        target: _hydrationTarget,
                        onAdd: _addHydration,
                      ),
                      SizedBox(height: context.heightPct(0.02)),
                      _NextMealPanel(countdown: _countdownText),
                    ],
                    SizedBox(height: context.heightPct(0.03)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meal {
  const _Meal(this.title, this.subtitle, this.badge, this.icon, this.done);

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final bool done;
}

class _MacrosCard extends StatelessWidget {
  const _MacrosCard({
    required this.caloriesConsumed,
    required this.caloriesTarget,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int caloriesConsumed;
  final int caloriesTarget;
  final int proteinG;
  final int carbsG;
  final int fatG;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fraction = caloriesTarget > 0
        ? (caloriesConsumed / caloriesTarget).clamp(0.0, 1.0)
        : 0.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1F) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 12 : 15),
        border: Border.all(color: isDark ? const Color(0xFF303033) : const Color(0xFFE9EAEB)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(isDark ? 30 : 38, isDark ? 28 : 38, isDark ? 30 : 38, 32),
        child: isDark
            ? _DarkMacros(
                consumed: caloriesConsumed,
                target: caloriesTarget,
                fraction: fraction,
                proteinG: proteinG,
                carbsG: carbsG,
                fatG: fatG,
              )
            : _LightMacros(
                consumed: caloriesConsumed,
                target: caloriesTarget,
                fraction: fraction,
                proteinG: proteinG,
                carbsG: carbsG,
                fatG: fatG,
              ),
      ),
    );
  }
}

class _LightMacros extends StatelessWidget {
  const _LightMacros({
    required this.consumed,
    required this.target,
    required this.fraction,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int consumed;
  final int target;
  final double fraction;
  final int proteinG;
  final int carbsG;
  final int fatG;

  @override
  Widget build(BuildContext context) {
    final proteinTarget = (target * 0.30 / 4).round();
    final carbsTarget = (target * 0.40 / 4).round();
    final fatTarget = (target * 0.30 / 9).round();
    final proteinProgress = proteinTarget > 0 ? (proteinG / proteinTarget).clamp(0.0, 1.0) : 0.0;
    final carbsProgress = carbsTarget > 0 ? (carbsG / carbsTarget).clamp(0.0, 1.0) : 0.0;
    final fatProgress = fatTarget > 0 ? (fatG / fatTarget).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Macros",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF6A7372),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$consumed / $target kcal',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 74,
              height: 74,
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 7,
                color: AppColors.teal,
                backgroundColor: const Color(0xFFE9FFF5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 42),
        _MacroLine(label: 'Protein', value: '${proteinG}g / ${proteinTarget}g', progress: proteinProgress, color: AppColors.teal),
        const SizedBox(height: 28),
        _MacroLine(label: 'Carbs', value: '${carbsG}g / ${carbsTarget}g', progress: carbsProgress, color: const Color(0xFFFFA414)),
        const SizedBox(height: 28),
        _MacroLine(label: 'Fat', value: '${fatG}g / ${fatTarget}g', progress: fatProgress, color: const Color(0xFFFF3E68)),
      ],
    );
  }
}

class _DarkMacros extends StatelessWidget {
  const _DarkMacros({
    required this.consumed,
    required this.target,
    required this.fraction,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int consumed;
  final int target;
  final double fraction;
  final int proteinG;
  final int carbsG;
  final int fatG;

  @override
  Widget build(BuildContext context) {
    final proteinTarget = (target * 0.30 / 4).round();
    final carbsTarget = (target * 0.40 / 4).round();
    final fatTarget = (target * 0.30 / 9).round();
    final proteinProgress = proteinTarget > 0 ? (proteinG / proteinTarget).clamp(0.0, 1.0) : 0.0;
    final carbsProgress = carbsTarget > 0 ? (carbsG / carbsTarget).clamp(0.0, 1.0) : 0.0;
    final fatProgress = fatTarget > 0 ? (fatG / fatTarget).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Macros",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'GOAL\nPROGRESS',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$consumed', style: const TextStyle(fontSize: 38, color: Color(0xFF31D39E))),
                  TextSpan(text: ' / $target\n'),
                  TextSpan(
                    text: 'kcal',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ],
              ),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _MacroLine(label: 'Protein', value: '${proteinG}g / ${proteinTarget}g', progress: proteinProgress, color: const Color(0xFF31D39E)),
        const SizedBox(height: 18),
        _MacroLine(label: 'Carbs', value: '${carbsG}g / ${carbsTarget}g', progress: carbsProgress, color: const Color(0xFFFFA414)),
        const SizedBox(height: 18),
        _MacroLine(label: 'Fat', value: '${fatG}g / ${fatTarget}g', progress: fatProgress, color: const Color(0xFFFF4F58)),
      ],
    );
  }
}

class _MacroLine extends StatelessWidget {
  const _MacroLine({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDark ? Colors.white70 : const Color(0xFF60666A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: isDark ? 9 : 10,
            color: color,
            backgroundColor: isDark ? const Color(0xFF2A2A2C) : color.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = '${_months[now.month - 1]} ${now.day}, Today';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF31D39E),
          ),
        ),
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({
    required this.meal,
    required this.focused,
    required this.isLogged,
    required this.onLog,
    required this.onTap,
  });

  final _Meal meal;
  final bool focused;
  final bool isLogged;
  final VoidCallback onLog;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isDark ? 10 : 14),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D1D1E) : Colors.white,
            borderRadius: BorderRadius.circular(isDark ? 10 : 14),
            border: Border.all(
              color: focused
                  ? AppColors.teal
                  : (isDark ? (isLogged ? AppColors.teal.withValues(alpha: 0.18) : const Color(0xFF2B2B2D)) : const Color(0xFFF0F1F1)),
              width: focused ? 2 : 1,
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
            padding: EdgeInsets.fromLTRB(isDark ? 20 : 24, isDark ? 18 : 26, 22, isDark ? 18 : 26),
            child: Row(
              children: [
                _MealIcon(icon: meal.icon, done: isLogged),
                SizedBox(width: isDark ? 22 : 26),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              meal.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isDark && isLogged) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF31D39E), size: 20),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        meal.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isDark ? Colors.white70 : const Color(0xFF7A8080),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isDark)
                        Text(
                          meal.badge,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isLogged ? const Color(0xFF31D39E) : const Color(0xFF777A80),
                          ),
                        )
                      else
                        _MealBadge(label: meal.badge, active: focused),
                    ],
                  ),
                ),
                if (isLogged)
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF31B690), size: 30)
                else
                  _LogButton(compact: isDark, onTap: onLog),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MealIcon extends StatelessWidget {
  const _MealIcon({
    required this.icon,
    required this.done,
  });

  final IconData icon;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102321) : AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(isDark ? 8 : 15),
      ),
      child: SizedBox(
        width: isDark ? 76 : 86,
        height: isDark ? 76 : 86,
        child: Icon(
          icon,
          color: isDark ? const Color(0xFF31D39E) : AppColors.teal,
          size: isDark ? 38 : 42,
        ),
      ),
    );
  }
}

class _MealBadge extends StatelessWidget {
  const _MealBadge({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? AppColors.teal.withValues(alpha: 0.1) : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: active ? AppColors.teal : const Color(0xFF7D8282),
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogButton extends StatelessWidget {
  const _LogButton({required this.compact, required this.onTap});

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF31D39E),
          side: const BorderSide(color: Color(0xFF31D39E)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        ),
        child: const Text('Log'),
      );
    }

    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: AppColors.teal),
      icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
      label: const Text('Log', style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _HydrationPanel extends StatelessWidget {
  const _HydrationPanel({
    required this.cups,
    required this.target,
    required this.onAdd,
  });

  final int cups;
  final int target;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final fraction = target > 0 ? (cups / target).clamp(0.0, 1.0) : 0.0;
    final litres = (cups * 0.25).toStringAsFixed(1);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101C18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stay Hydrated',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF31D39E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Drink ${(target * 0.25).toStringAsFixed(1)}L daily for optimal\nmetabolism',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF31D39E),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: cups < target ? onAdd : null,
                        style: OutlinedButton.styleFrom(
                          shape: const CircleBorder(),
                          side: BorderSide(color: AppColors.teal.withValues(alpha: 0.45)),
                          padding: const EdgeInsets.all(18),
                        ),
                        child: const Icon(Icons.add_rounded, color: Color(0xFF31D39E), size: 30),
                      ),
                      const SizedBox(width: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${litres}L\n',
                              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                            ),
                            TextSpan(
                              text: '$cups / $target cups',
                              style: TextStyle(fontSize: 11, color: AppColors.teal.withValues(alpha: 0.9)),
                            ),
                          ],
                        ),
                        style: const TextStyle(color: Color(0xFF31D39E), height: 1.25),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 10,
                    color: const Color(0xFF31D39E),
                    backgroundColor: const Color(0xFF333236),
                  ),
                  Icon(
                    cups >= target
                        ? Icons.water_drop_rounded
                        : Icons.water_drop_outlined,
                    color: const Color(0xFF31D39E),
                    size: 32,
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

class _NextMealPanel extends StatelessWidget {
  const _NextMealPanel({required this.countdown});

  final String countdown;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF18181A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2D)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Row(
          children: [
            Icon(Icons.restaurant_rounded, color: Colors.white.withValues(alpha: 0.45), size: 36),
            const SizedBox(width: 18),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Next Meal in\n',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                  ),
                  TextSpan(
                    text: countdown,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
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

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      _NavSpec(Icons.home_outlined, 'Home', false, () => context.go(AppRoutes.homeDashboard)),
      _NavSpec(Icons.fitness_center_rounded, 'Workouts', false, () => context.go(AppRoutes.workoutHub)),
      _NavSpec(Icons.restaurant_rounded, 'Nutrition', true, () {}),
      _NavSpec(Icons.insert_chart_outlined_rounded, 'Progress', false, () => context.go(AppRoutes.progress)),
      _NavSpec(Icons.person_outline_rounded, 'Profile', false, () => context.push(AppRoutes.settings)),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF242426) : const Color(0xFFEDEFF0))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: isDark ? 86 : 84,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in items) _NavItem(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.icon, this.label, this.selected, this.onTap);

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.item});

  final _NavSpec item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = isDark ? const Color(0xFF31D39E) : AppColors.teal;
    final idle = isDark ? const Color(0xFF6E7078) : const Color(0xFFA0A2AA);
    final color = item.selected ? active : idle;

    return Material(
      color: item.selected ? active.withValues(alpha: isDark ? 0.13 : 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 86,
          height: 66,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 28),
              const SizedBox(height: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
