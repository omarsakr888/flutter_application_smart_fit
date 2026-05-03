import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key});

  static const _ingredientsLight = [
    _Ingredient('Chicken breast (150g)', 'Grilled'),
    _Ingredient('Whole wheat tortilla', '1 large'),
    _Ingredient('Fresh Romaine lettuce', 'Shredded'),
    _Ingredient('Ripe cherry tomatoes', 'Quartered'),
    _Ingredient('Greek yogurt sauce', '2 tbsp'),
    _Ingredient('Fresh avocado', 'Slices'),
  ];

  static const _ingredientsDark = [
    _Ingredient('200g Chicken breast, sliced', ''),
    _Ingredient('1 Whole wheat tortilla', ''),
    _Ingredient('Handful of fresh lettuce', ''),
    _Ingredient('1 Medium tomato diced', ''),
    _Ingredient('2 tbsp Greek yogurt sauce', ''),
    _Ingredient('1/2 Ripe avocado', ''),
  ];

  static const _instructionsLight = [
    'Season chicken breast with salt and pepper. Grill over medium-high heat for 6-7 minutes per side until cooked through.',
    'Briefly warm the tortilla in a dry pan or microwave for 10 seconds to make it more pliable.',
    'Spread the yogurt sauce down the center. Layer lettuce, tomatoes, sliced grilled chicken, and avocado.',
    'Fold the sides inward, then roll tightly from the bottom. Slice diagonally to serve.',
  ];

  static const _instructionsDark = [
    _PrepStep('Grill the chicken', 'Season chicken with salt, pepper, and paprika. Grill over medium-high heat until cooked through (6-8 minutes).'),
    _PrepStep('Warm the tortilla', 'Lightly toast the whole wheat tortilla on a dry pan for 30 seconds on each side until pliable.'),
    _PrepStep('Assemble layers', 'Spread yogurt sauce, layer lettuce, diced tomatoes, sliced avocado, and the grilled chicken.'),
    _PrepStep('Roll and serve', 'Fold in the sides and roll tightly. Slice diagonally and enjoy while warm.'),
  ];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF6FCF6),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              isDark: isDark,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.nutrition);
                }
              },
              onLight: () => scope.setThemeBrightness(Brightness.light),
              onDark: () => scope.setThemeBrightness(Brightness.dark),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF272729) : const Color(0xFFEDEFF0)),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: isDark ? 28 : 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isDark)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                        child: _DarkHero(),
                      )
                    else
                      const _LightHero(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, isDark ? 24 : 32, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isDark) const _DarkTags() else const _NutritionCard(),
                          if (!isDark) ...[
                            const SizedBox(height: 30),
                            const _HealthPills(),
                          ],
                          SizedBox(height: isDark ? 28 : 34),
                          Text(
                            'Ingredients',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (final ingredient in isDark ? _ingredientsDark : _ingredientsLight) ...[
                            _IngredientTile(ingredient: ingredient),
                            const SizedBox(height: 8),
                          ],
                          SizedBox(height: isDark ? 30 : 34),
                          Text(
                            isDark ? 'Preparation' : 'Instructions',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isDark)
                            for (var i = 0; i < _instructionsDark.length; i++)
                              _DarkPrepStep(index: i + 1, step: _instructionsDark[i], last: i == _instructionsDark.length - 1)
                          else
                            for (var i = 0; i < _instructionsLight.length; i++) ...[
                              _LightInstruction(index: i + 1, text: _instructionsLight[i]),
                              const SizedBox(height: 22),
                            ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _BottomActions(),
          ],
        ),
      ),
    );
  }
}

class _Ingredient {
  const _Ingredient(this.name, this.amount);

  final String name;
  final String amount;
}

class _PrepStep {
  const _PrepStep(this.title, this.body);

  final String title;
  final String body;
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
      height: isDark ? 50 : 60,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDark ? 8 : 12),
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_rounded, color: isDark ? const Color(0xFF31D39E) : AppColors.teal),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                isDark ? 'Meal Details' : 'Recipe Detail',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            IconButton(
              tooltip: isDark ? 'Light theme' : 'Dark theme',
              onPressed: isDark ? onLight : onDark,
              icon: Icon(isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_outlined, color: isDark ? Colors.white70 : const Color(0xFF575B64)),
            ),
            IconButton(
              tooltip: 'Save',
              onPressed: () {},
              icon: Icon(Icons.bookmark_border_rounded, color: isDark ? const Color(0xFF31D39E) : const Color(0xFF575B64)),
            ),
            IconButton(
              tooltip: 'More',
              onPressed: () {},
              icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white70 : const Color(0xFF575B64)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightHero extends StatelessWidget {
  const _LightHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 282,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFEFF7F0)),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: SizedBox(width: 150, height: 120, child: CustomPaint(painter: _BowlPainter())),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.54),
                ],
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grilled Chicken Wrap',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 8,
                  children: [
                    _HeroTag(label: 'High Protein', icon: Icons.local_fire_department_rounded),
                    _HeroTag(label: 'High Fiber', icon: Icons.eco_rounded),
                    _HeroTag(label: 'Quick', icon: Icons.timer_outlined),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkHero extends StatelessWidget {
  const _DarkHero();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111112),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2B2B2D)),
      ),
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            Center(
              child: SizedBox(width: 140, height: 120, child: CustomPaint(painter: _BowlPainter())),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grilled Chicken Wrap',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Wrap(
                    spacing: 8,
                    children: [
                      _HeroTag(label: '15 min', icon: Icons.timer_outlined),
                      _HeroTag(label: 'Easy Prep', icon: Icons.eco_rounded, filled: true),
                    ],
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

class _HeroTag extends StatelessWidget {
  const _HeroTag({
    required this.label,
    required this.icon,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? AppColors.teal.withValues(alpha: 0.22) : Colors.white.withValues(alpha: isDark ? 0.08 : 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? AppColors.teal.withValues(alpha: 0.35) : Colors.white.withValues(alpha: isDark ? 0.08 : 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: filled ? const Color(0xFF31D39E) : Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: filled ? const Color(0xFF31D39E) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E5E3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('610', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 8),
                Text('kcal', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  'PER SERVING',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF5F6268),
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Row(
              children: [
                Expanded(child: _MacroText(label: 'Protein', value: '38g', color: AppColors.teal)),
                Expanded(child: _MacroText(label: 'Carbs', value: '52g', color: Color(0xFFFF761D))),
                Expanded(child: _MacroText(label: 'Fat', value: '22g', color: Color(0xFFFF3D65))),
              ],
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const Row(
                children: [
                  Expanded(flex: 38, child: ColoredBox(color: AppColors.teal, child: SizedBox(height: 8))),
                  Expanded(flex: 40, child: ColoredBox(color: Color(0xFFFF761D), child: SizedBox(height: 8))),
                  Expanded(flex: 22, child: ColoredBox(color: Color(0xFFFF3D65), child: SizedBox(height: 8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkTags extends StatelessWidget {
  const _DarkTags();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DarkInfoChip(label: 'High Protein', icon: Icons.local_fire_department_rounded),
            _DarkInfoChip(label: 'High Fiber', icon: Icons.eco_rounded),
            _DarkInfoChip(label: 'Dairy-Free', icon: Icons.breakfast_dining_rounded),
            _DarkInfoChip(label: 'Quick', icon: Icons.timer_outlined),
          ],
        ),
        SizedBox(height: 26),
        _DarkNutritionCard(),
      ],
    );
  }
}

class _DarkInfoChip extends StatelessWidget {
  const _DarkInfoChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F20),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _DarkNutritionCard extends StatelessWidget {
  const _DarkNutritionCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1F),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Calories',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF7E8088)),
                  ),
                ),
                Text(
                  'Daily Goal\n2,400 kcal',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: '610', style: TextStyle(fontSize: 38, color: Color(0xFF31D39E), fontWeight: FontWeight.w800)),
                  TextSpan(text: ' kcal'),
                ],
              ),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(child: _DarkMacroBox(label: 'PROTEIN', value: '38g')),
                SizedBox(width: 10),
                Expanded(child: _DarkMacroBox(label: 'CARBS', value: '52g')),
                SizedBox(width: 10),
                Expanded(child: _DarkMacroBox(label: 'FAT', value: '22g')),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const Row(
                children: [
                  Expanded(flex: 38, child: ColoredBox(color: Color(0xFF31D39E), child: SizedBox(height: 10))),
                  Expanded(flex: 40, child: ColoredBox(color: Color(0xFFFF761D), child: SizedBox(height: 10))),
                  Expanded(flex: 22, child: ColoredBox(color: Color(0xFFFF3D65), child: SizedBox(height: 10))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PROTEIN', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF7E8088), letterSpacing: 1)),
                Text('CARBS', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF7E8088), letterSpacing: 1)),
                Text('FAT', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF7E8088), letterSpacing: 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroText extends StatelessWidget {
  const _MacroText({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _DarkMacroBox extends StatelessWidget {
  const _DarkMacroBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF7E8088))),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _HealthPills extends StatelessWidget {
  const _HealthPills();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      children: [
        _HealthPill(label: 'Dairy-Free', icon: Icons.eco_outlined),
        _HealthPill(label: 'Energy Boost', icon: Icons.bolt_outlined),
      ],
    );
  }
}

class _HealthPill extends StatelessWidget {
  const _HealthPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E9E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.teal, size: 17),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: const Color(0xFF4B5353))),
          ],
        ),
      ),
    );
  }
}

class _IngredientTile extends StatelessWidget {
  const _IngredientTile({required this.ingredient});

  final _Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F20) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 8 : 5),
        border: Border.all(color: isDark ? const Color(0xFF2A2A2D) : const Color(0xFFE1E5E3)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDark ? 14 : 16, vertical: isDark ? 15 : 13),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: false,
                onChanged: (_) {},
                side: BorderSide(color: isDark ? const Color(0xFF4A4C52) : const Color(0xFF8D9692)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                ingredient.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (ingredient.amount.isNotEmpty)
              Text(
                ingredient.amount,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isDark ? const Color(0xFF7E8088) : const Color(0xFF5F6268),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LightInstruction extends StatelessWidget {
  const _LightInstruction({
    required this.index,
    required this.text,
  });

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: AppColors.teal.withValues(alpha: 0.08),
          child: Text('$index', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.teal)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _DarkPrepStep extends StatelessWidget {
  const _DarkPrepStep({
    required this.index,
    required this.step,
    required this.last,
  });

  final int index;
  final _PrepStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: index == 1 ? const Color(0xFF31D39E) : const Color(0xFF2A2A2D),
                child: Text('$index', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 1, color: const Color(0xFF2A2A2D)),
                ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(step.body, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF777A80), height: 1.35)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: Checkbox(value: false, onChanged: (_) {}, side: const BorderSide(color: Color(0xFF4A4C52))),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'MARK STEP COMPLETE',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: const Color(0xFF31D39E), fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090A) : Colors.white,
        borderRadius: isDark ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(8)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
        child: Row(
          children: [
            _ActionIconButton(icon: Icons.favorite_border_rounded, label: isDark ? null : 'Favorite'),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF31D39E) : AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isDark ? 8 : 9)),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Log Meal'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (isDark)
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF45464B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Swap'),
                  ),
                ),
              )
            else
              _ActionIconButton(icon: Icons.swap_horiz_rounded, label: 'Swap'),
          ],
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({required this.icon, required this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: isDark ? 42 : 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {},
            style: IconButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF222225) : Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(icon, color: isDark ? Colors.white70 : const Color(0xFF5D6068)),
          ),
          if (label != null)
            Text(label!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF5D6068))),
        ],
      ),
    );
  }
}

class _BowlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bowlPaint = Paint()..color = Colors.white;
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.08);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, size.height * 0.68), width: size.width * 0.9, height: size.height * 0.22), shadow);
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.36, size.width * 0.8, size.height * 0.48),
      0,
      3.14,
      false,
      bowlPaint..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.18, size.height * 0.5, size.width * 0.64, size.height * 0.28),
        const Radius.circular(40),
      ),
      bowlPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.14, size.height * 0.34, size.width * 0.72, size.height * 0.22),
      0,
      3.14,
      false,
      Paint()
        ..color = const Color(0xFFE8ECEC)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke,
    );

    final greens = Paint()
      ..color = const Color(0xFF69C63B)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    for (final p in [
      Offset(size.width * 0.24, size.height * 0.38),
      Offset(size.width * 0.36, size.height * 0.28),
      Offset(size.width * 0.52, size.height * 0.34),
      Offset(size.width * 0.68, size.height * 0.3),
      Offset(size.width * 0.78, size.height * 0.42),
    ]) {
      canvas.drawCircle(p, 13, Paint()..color = const Color(0xFF69C63B));
      canvas.drawLine(p.translate(-10, 10), p.translate(10, -10), greens);
    }

    final tomato = Paint()..color = const Color(0xFFFF3D3D);
    for (final p in [
      Offset(size.width * 0.44, size.height * 0.36),
      Offset(size.width * 0.62, size.height * 0.42),
    ]) {
      canvas.drawCircle(p, 13, tomato);
      canvas.drawCircle(p.translate(-4, -2), 2, Paint()..color = Colors.white);
      canvas.drawCircle(p.translate(5, 4), 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
