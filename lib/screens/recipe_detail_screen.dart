import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../models/plan_result.dart';
import '../router/app_routes.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_chat_fab.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, this.meal});

  final MealSlot? meal;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _checkedIngredients = <int>{};
  final _checkedSteps = <int>{};
  bool _isFavorited = false;
  bool _loggingMeal = false;

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

  static List<String> _parseLines(String raw) => raw
      .split(RegExp(r'[\n;]'))
      .map((s) => s.replaceAll(RegExp(r'^\d+[\.\)]\s*'), '').trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _logMeal() async {
    if (_loggingMeal) return;
    setState(() => _loggingMeal = true);
    try {
      await UserService.instance.logMeal(
        widget.meal?.displayName ?? 'Meal',
        caloriesConsumed: widget.meal?.caloriesPerServing ?? 0,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.meal?.displayName ?? 'Meal'} logged!'),
            backgroundColor: AppColors.teal,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log meal. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingMeal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final meal = widget.meal;

    final recipeName = meal?.recipeName.isNotEmpty == true
        ? meal!.recipeName
        : 'Grilled Chicken Wrap';
    final kcal = meal?.caloriesPerServing.round();
    final proteinG = meal?.proteinG.round();
    final carbsG = meal?.carbsG.round();
    final fatG = meal?.fatG.round();
    final dietType = meal?.dietType ?? '';

    final rawIngredients = meal?.ingredients ?? '';
    final parsedIngredients = rawIngredients.isNotEmpty
        ? _parseLines(rawIngredients).map((s) => _Ingredient(s, '')).toList()
        : (isDark ? _ingredientsDark : _ingredientsLight);

    final rawInstructions = meal?.instructions ?? '';
    final parsedInstructionsLight = rawInstructions.isNotEmpty
        ? _parseLines(rawInstructions)
        : _instructionsLight;
    final parsedInstructionsDark = rawInstructions.isNotEmpty
        ? _parseLines(rawInstructions).map((s) => _PrepStep(s, '')).toList()
        : _instructionsDark;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF6FCF6),
      floatingActionButton: const AiChatFab(),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              isDark: isDark,
              isFavorited: _isFavorited,
              onBack: () {
                if (context.canPop()) context.pop();
                else context.go(AppRoutes.nutrition);
              },
              onLight: () => scope.setThemeBrightness(Brightness.light),
              onDark: () => scope.setThemeBrightness(Brightness.dark),
              onFavorite: () {
                setState(() => _isFavorited = !_isFavorited);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isFavorited ? 'Added to favorites' : 'Removed from favorites'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              onMore: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => _MoreSheet(recipeName: recipeName),
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF272729) : const Color(0xFFEDEFF0)),
            _StickyMacroBar(
              proteinG: proteinG ?? 38,
              carbsG: carbsG ?? 52,
              fatG: fatG ?? 22,
              isDark: isDark,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: isDark ? 28 : 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isDark)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        child: _DarkHero(title: recipeName),
                      )
                    else
                      _LightHero(title: recipeName, dietType: dietType),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, isDark ? 24 : 32, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isDark)
                            _DarkTags(dietType: dietType)
                          else
                            _NutritionCard(
                              kcal: kcal ?? 610,
                              proteinG: proteinG ?? 38,
                              carbsG: carbsG ?? 52,
                              fatG: fatG ?? 22,
                            ),
                          if (!isDark) ...[
                            const SizedBox(height: 30),
                            const _HealthPills(),
                          ],
                          SizedBox(height: isDark ? 28 : 34),
                          Text(
                            'Ingredients',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          for (var i = 0; i < parsedIngredients.length; i++) ...[
                            _IngredientTile(
                              ingredient: parsedIngredients[i],
                              checked: _checkedIngredients.contains(i),
                              onToggle: () => setState(() {
                                if (!_checkedIngredients.remove(i)) _checkedIngredients.add(i);
                              }),
                            ),
                            const SizedBox(height: 8),
                          ],
                          SizedBox(height: isDark ? 30 : 34),
                          Text(
                            isDark ? 'Preparation' : 'Instructions',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          if (isDark)
                            for (var i = 0; i < parsedInstructionsDark.length; i++)
                              _DarkPrepStep(
                                index: i + 1,
                                step: parsedInstructionsDark[i],
                                last: i == parsedInstructionsDark.length - 1,
                                checked: _checkedSteps.contains(i),
                                onToggle: () => setState(() {
                                  if (!_checkedSteps.remove(i)) _checkedSteps.add(i);
                                }),
                              )
                          else
                            for (var i = 0; i < parsedInstructionsLight.length; i++) ...[
                              _LightInstruction(index: i + 1, text: parsedInstructionsLight[i]),
                              const SizedBox(height: 22),
                            ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _BottomActions(
              meal: meal,
              loggingMeal: _loggingMeal,
              onLog: _logMeal,
              onSwap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Meal swap coming soon.')),
              ),
            ),
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
    required this.isFavorited,
    required this.onBack,
    required this.onLight,
    required this.onDark,
    required this.onFavorite,
    required this.onMore,
  });

  final bool isDark;
  final bool isFavorited;
  final VoidCallback onBack;
  final VoidCallback onLight;
  final VoidCallback onDark;
  final VoidCallback onFavorite;
  final VoidCallback onMore;

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
              tooltip: isFavorited ? 'Remove from favorites' : 'Save to favorites',
              onPressed: onFavorite,
              icon: Icon(
                isFavorited ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: isFavorited ? AppColors.teal : (isDark ? const Color(0xFF31D39E) : const Color(0xFF575B64)),
              ),
            ),
            IconButton(
              tooltip: 'More options',
              onPressed: onMore,
              icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white70 : const Color(0xFF575B64)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.recipeName});
  final String recipeName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share Recipe'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share coming soon.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Print Recipe'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Print coming soon.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.report_outlined),
            title: const Text('Report an issue'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for the feedback!')),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StickyMacroBar extends StatelessWidget {
  const _StickyMacroBar({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.isDark,
  });

  final int proteinG;
  final int carbsG;
  final int fatG;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E1F) : const Color(0xFFF9FAFB);
    final textC = isDark ? Colors.white70 : const Color(0xFF4B5563);
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MacroDot(label: '${proteinG}g Protein', color: const Color(0xFFEF4444), textColor: textC),
          _MacroDot(label: '${carbsG}g Carbs', color: const Color(0xFFF59E0B), textColor: textC),
          _MacroDot(label: '${fatG}g Fat', color: const Color(0xFF3B82F6), textColor: textC),
        ],
      ),
    );
  }
}

class _MacroDot extends StatelessWidget {
  const _MacroDot({required this.label, required this.color, required this.textColor});
  final String label;
  final Color color;
  final Color textColor;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: textColor, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _LightHero extends StatelessWidget {
  const _LightHero({required this.title, required this.dietType});
  final String title;
  final String dietType;

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
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.54)],
              ),
            ),
          ),
          Positioned(
            left: 22, right: 22, bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (dietType.isNotEmpty)
                      _HeroTag(label: dietType, icon: Icons.eco_rounded)
                    else ...[
                      const _HeroTag(label: 'High Protein', icon: Icons.local_fire_department_rounded),
                      const _HeroTag(label: 'High Fiber', icon: Icons.eco_rounded),
                    ],
                    const _HeroTag(label: 'Quick', icon: Icons.timer_outlined),
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
  const _DarkHero({required this.title});
  final String title;

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
            Center(child: SizedBox(width: 140, height: 120, child: CustomPaint(painter: _BowlPainter()))),
            Positioned(
              left: 22, right: 22, bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
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
  const _HeroTag({required this.label, required this.icon, this.filled = false});
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
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: filled ? const Color(0xFF31D39E) : Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.kcal, required this.proteinG, required this.carbsG, required this.fatG});
  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;

  @override
  Widget build(BuildContext context) {
    final total = proteinG + carbsG + fatG;
    final pFlex = total > 0 ? proteinG : 38;
    final cFlex = total > 0 ? carbsG : 40;
    final fFlex = total > 0 ? fatG : 22;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E5E3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('$kcal', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 8),
                Text('kcal', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('PER SERVING', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: const Color(0xFF5F6268), letterSpacing: 0.7)),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: _MacroText(label: 'Protein', value: '${proteinG}g', color: AppColors.teal)),
                Expanded(child: _MacroText(label: 'Carbs', value: '${carbsG}g', color: const Color(0xFFFF761D))),
                Expanded(child: _MacroText(label: 'Fat', value: '${fatG}g', color: const Color(0xFFFF3D65))),
              ],
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Row(
                children: [
                  Expanded(flex: pFlex, child: const ColoredBox(color: AppColors.teal, child: SizedBox(height: 8))),
                  Expanded(flex: cFlex, child: const ColoredBox(color: Color(0xFFFF761D), child: SizedBox(height: 8))),
                  Expanded(flex: fFlex, child: const ColoredBox(color: Color(0xFFFF3D65), child: SizedBox(height: 8))),
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
  const _DarkTags({required this.dietType});
  final String dietType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            const _DarkInfoChip(label: 'High Protein', icon: Icons.local_fire_department_rounded),
            if (dietType.isNotEmpty)
              _DarkInfoChip(label: dietType, icon: Icons.eco_rounded)
            else
              const _DarkInfoChip(label: 'High Fiber', icon: Icons.eco_rounded),
            const _DarkInfoChip(label: 'Quick', icon: Icons.timer_outlined),
          ],
        ),
        const SizedBox(height: 26),
        const _DarkNutritionCard(),
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
      decoration: BoxDecoration(color: const Color(0xFF1F1F20), borderRadius: BorderRadius.circular(5)),
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
      decoration: BoxDecoration(color: const Color(0xFF1E1E1F), borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Total Calories', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF7E8088)))),
                Text('Daily Goal\n2,400 kcal', textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              const TextSpan(children: [
                TextSpan(text: '610', style: TextStyle(fontSize: 38, color: Color(0xFF31D39E), fontWeight: FontWeight.w800)),
                TextSpan(text: ' kcal'),
              ]),
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
  const _MacroText({required this.label, required this.value, required this.color});
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
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(8)),
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
  const _IngredientTile({required this.ingredient, required this.checked, required this.onToggle});
  final _Ingredient ingredient;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onToggle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F20) : Colors.white,
          borderRadius: BorderRadius.circular(isDark ? 8 : 5),
          border: Border.all(
            color: checked
                ? AppColors.teal.withValues(alpha: 0.45)
                : (isDark ? const Color(0xFF2A2A2D) : const Color(0xFFE1E5E3)),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDark ? 14 : 16, vertical: isDark ? 15 : 13),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ingredient.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: checked
                        ? (isDark ? Colors.white38 : const Color(0xFFAAAAAA))
                        : Theme.of(context).colorScheme.onSurface,
                    decoration: checked ? TextDecoration.lineThrough : null,
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
              const SizedBox(width: 16),
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: checked,
                  onChanged: (_) => onToggle(),
                  activeColor: AppColors.teal,
                  side: BorderSide(color: isDark ? const Color(0xFF4A4C52) : const Color(0xFF8D9692)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LightInstruction extends StatelessWidget {
  const _LightInstruction({required this.index, required this.text});
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
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(height: 1.35))),
      ],
    );
  }
}

class _DarkPrepStep extends StatelessWidget {
  const _DarkPrepStep({
    required this.index,
    required this.step,
    required this.last,
    required this.checked,
    required this.onToggle,
  });
  final int index;
  final _PrepStep step;
  final bool last;
  final bool checked;
  final VoidCallback onToggle;

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
                backgroundColor: checked ? AppColors.teal : (index == 1 ? const Color(0xFF31D39E) : const Color(0xFF2A2A2D)),
                child: checked
                    ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                    : Text('$index', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
              ),
              if (!last)
                Expanded(child: Container(width: 1, color: const Color(0xFF2A2A2D))),
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
                  GestureDetector(
                    onTap: onToggle,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: Checkbox(
                            value: checked,
                            onChanged: (_) => onToggle(),
                            activeColor: AppColors.teal,
                            side: const BorderSide(color: Color(0xFF4A4C52)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          checked ? 'STEP COMPLETE' : 'MARK STEP COMPLETE',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: checked ? AppColors.teal : const Color(0xFF31D39E),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
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
  const _BottomActions({
    required this.meal,
    required this.loggingMeal,
    required this.onLog,
    required this.onSwap,
  });
  final MealSlot? meal;
  final bool loggingMeal;
  final VoidCallback onLog;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090A) : Colors.white,
        borderRadius: isDark ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(8)),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
        child: Row(
          children: [
            _ActionIconButton(icon: Icons.favorite_border_rounded, label: isDark ? null : 'Favorite', onTap: onSwap),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: loggingMeal ? null : onLog,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF31D39E) : AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isDark ? 8 : 9)),
                  ),
                  icon: loggingMeal
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(meal != null ? 'Log ${meal!.displayName}' : 'Log Meal'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (isDark)
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: onSwap,
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
              _ActionIconButton(icon: Icons.swap_horiz_rounded, label: 'Swap', onTap: onSwap),
          ],
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: isDark ? 42 : 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onTap,
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
      0, 3.14, false,
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
      0, 3.14, false,
      Paint()..color = const Color(0xFFE8ECEC)..strokeWidth = 5..style = PaintingStyle.stroke,
    );
    final greens = Paint()..color = const Color(0xFF69C63B)..strokeWidth = 10..strokeCap = StrokeCap.round;
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
