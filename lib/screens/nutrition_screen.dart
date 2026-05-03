import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  static const _lightMeals = [
    _Meal('Breakfast', 'Oatmeal with Berries - 320 kcal', 'Fiber', Icons.rice_bowl_rounded, true),
    _Meal('Lunch', 'Grilled Chicken Salad - 450 kcal', 'High Protein', Icons.local_dining_rounded, true),
    _Meal('Dinner', 'Salmon & Asparagus - 580 kcal', 'Keto Friendly', Icons.set_meal_rounded, false),
    _Meal('Snack', 'Apple & Almond Butter - 180 kcal', 'Low Carb', Icons.eco_rounded, false),
  ];

  static const _darkMeals = [
    _Meal('Breakfast', 'Berry Protein Oatmeal', '420 kcal', Icons.rice_bowl_rounded, true),
    _Meal('Lunch', 'Grilled Chicken Power Bowl', '580 kcal', Icons.local_dining_rounded, true),
    _Meal('Dinner', 'Lemon Herb Salmon', '450 kcal', Icons.set_meal_rounded, false),
    _Meal('Snack', 'Greek Yogurt & Almonds', '192 kcal', Icons.icecream_rounded, false),
  ];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final meals = isDark ? _darkMeals : _lightMeals;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            _NutritionHeader(
              isDark: isDark,
              onLight: () => scope.setThemeBrightness(Brightness.light),
              onDark: () => scope.setThemeBrightness(Brightness.dark),
            ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF2A2A2A) : Colors.transparent,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, isDark ? 30 : 54, 20, 32),
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
                            'May 24, 2024',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF60666A),
                            ),
                          ),
                        ],
                      ),
                    if (!isDark) const SizedBox(height: 54),
                    const _MacrosCard(),
                    SizedBox(height: isDark ? 48 : 54),
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
                    const SizedBox(height: 22),
                    for (var i = 0; i < meals.length; i++) ...[
                      _MealTile(meal: meals[i], focused: !isDark && i == 2),
                      const SizedBox(height: 16),
                    ],
                    if (isDark) ...[
                      const SizedBox(height: 22),
                      const _HydrationPanel(),
                      const SizedBox(height: 20),
                      const _NextMealPanel(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const _BottomNav(),
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

class _NutritionHeader extends StatelessWidget {
  const _NutritionHeader({
    required this.isDark,
    required this.onLight,
    required this.onDark,
  });

  final bool isDark;
  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isDark ? 76 : 98,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, isDark ? 8 : 14, 24, 12),
        child: Row(
          children: [
            if (isDark)
              Expanded(
                child: Text(
                  'Nutrition',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF31D39E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else ...[
              IconButton(
                tooltip: 'Menu',
                onPressed: () {},
                icon: const Icon(Icons.menu_rounded, color: AppColors.teal, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Smart Fit',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            _ThemeSegment(
              isDark: isDark,
              onLight: onLight,
              onDark: onDark,
            ),
          ],
        ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202124) : const Color(0xFFEFF4EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeButton(
              selected: !isDark,
              icon: Icons.wb_sunny_outlined,
              onTap: onLight,
            ),
            const SizedBox(width: 4),
            _ThemeButton(
              selected: isDark,
              icon: Icons.dark_mode_rounded,
              onTap: onDark,
            ),
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
    final idle = isDark ? Colors.white38 : const Color(0xFF899098);

    return Material(
      color: selected ? AppColors.teal : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: isDark ? 46 : 54,
          height: isDark ? 46 : 54,
          child: Icon(icon, color: selected ? Colors.white : idle, size: isDark ? 25 : 28),
        ),
      ),
    );
  }
}

class _MacrosCard extends StatelessWidget {
  const _MacrosCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        child: isDark ? const _DarkMacros() : const _LightMacros(),
      ),
    );
  }
}

class _LightMacros extends StatelessWidget {
  const _LightMacros();

  @override
  Widget build(BuildContext context) {
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
                    '1,642 / 2,240 kcal',
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
                value: 0.73,
                strokeWidth: 7,
                color: AppColors.teal,
                backgroundColor: const Color(0xFFE9FFF5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 42),
        const _MacroLine(label: 'Protein', value: '120g / 160g', progress: 0.75, color: AppColors.teal),
        const SizedBox(height: 28),
        const _MacroLine(label: 'Carbs', value: '180g / 250g', progress: 0.72, color: Color(0xFFFFA414)),
        const SizedBox(height: 28),
        const _MacroLine(label: 'Fat', value: '42g / 70g', progress: 0.6, color: Color(0xFFFF3E68)),
      ],
    );
  }
}

class _DarkMacros extends StatelessWidget {
  const _DarkMacros();

  @override
  Widget build(BuildContext context) {
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
                  const TextSpan(text: '1,642', style: TextStyle(fontSize: 38, color: Color(0xFF31D39E))),
                  const TextSpan(text: ' / 2,240\n'),
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
        const _MacroLine(label: 'Protein', value: '128g / 180g', progress: 0.71, color: Color(0xFF31D39E)),
        const SizedBox(height: 18),
        const _MacroLine(label: 'Carbs', value: '142g / 220g', progress: 0.65, color: Color(0xFFFFA414)),
        const SizedBox(height: 18),
        const _MacroLine(label: 'Fat', value: '54g / 75g', progress: 0.72, color: Color(0xFFFF4F58)),
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

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Text(
          'August 24, Today',
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
  });

  final _Meal meal;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(AppRoutes.recipeDetail),
        borderRadius: BorderRadius.circular(isDark ? 10 : 14),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D1D1E) : Colors.white,
            borderRadius: BorderRadius.circular(isDark ? 10 : 14),
            border: Border.all(
              color: focused
                  ? AppColors.teal
                  : (isDark ? (meal.done ? AppColors.teal.withValues(alpha: 0.18) : const Color(0xFF2B2B2D)) : const Color(0xFFF0F1F1)),
              width: focused ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(isDark ? 20 : 24, isDark ? 18 : 26, 22, isDark ? 18 : 26),
            child: Row(
              children: [
                _MealIcon(icon: meal.icon, done: meal.done),
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
                          if (isDark && meal.done) ...[
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
                            color: meal.done ? const Color(0xFF31D39E) : const Color(0xFF777A80),
                          ),
                        )
                      else
                        _MealBadge(label: meal.badge, active: focused),
                    ],
                  ),
                ),
                if (meal.done && !isDark)
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF31B690), size: 30)
                else if (!meal.done)
                  _SwapButton(compact: isDark),
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

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF31D39E),
          side: const BorderSide(color: Color(0xFF31D39E)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        ),
        child: const Text('Swap'),
      );
    }

    return TextButton.icon(
      onPressed: () {},
      style: TextButton.styleFrom(foregroundColor: AppColors.teal),
      icon: const Icon(Icons.cached_rounded, size: 19),
      label: const Text('Swap', style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _HydrationPanel extends StatelessWidget {
  const _HydrationPanel();

  @override
  Widget build(BuildContext context) {
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
                    'Drink 2.5L daily for optimal\nmetabolism',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF31D39E),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {},
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
                            const TextSpan(text: '1.8L\n', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                            TextSpan(text: 'CURRENT', style: TextStyle(fontSize: 11, color: AppColors.teal.withValues(alpha: 0.9))),
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
                children: const [
                  CircularProgressIndicator(
                    value: 0.72,
                    strokeWidth: 10,
                    color: Color(0xFF31D39E),
                    backgroundColor: Color(0xFF333236),
                  ),
                  Icon(Icons.water_drop_outlined, color: Color(0xFF31D39E), size: 32),
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
  const _NextMealPanel();

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
                  TextSpan(text: 'Next Meal in\n', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16)),
                  const TextSpan(text: '02:15:00', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
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
      _NavSpec(Icons.person_outline_rounded, isDark ? 'Profile' : 'Profile', false, () {}),
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
