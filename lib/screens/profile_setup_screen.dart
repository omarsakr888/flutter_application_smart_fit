import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../localization/profile_setup_strings.dart';
import '../router/app_routes.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/smart_fit_theme.dart';

enum _Gender { male, female, other }

enum _FitnessGoal { loseFat, buildMuscle, maintain }

/// Profile onboarding step 1 of 2 (page 4).
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _age = TextEditingController(text: '25');
  final _height = TextEditingController(text: '180');
  final _weight = TextEditingController(text: '75');
  final _target = TextEditingController(text: '80');

  _Gender _gender = _Gender.male;
  _FitnessGoal _goal = _FitnessGoal.buildMuscle;

  void _rebadge() => setState(() {});

  @override
  void initState() {
    super.initState();
    _weight.addListener(_rebadge);
    _target.addListener(_rebadge);
  }

  @override
  void dispose() {
    _weight.removeListener(_rebadge);
    _target.removeListener(_rebadge);
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _target.dispose();
    super.dispose();
  }

  void _snack(Locale l, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  double? _parseDouble(String raw) => double.tryParse(raw.trim());

  int? _parseDeltaBadge() {
    final w = _parseDouble(_weight.text);
    final t = _parseDouble(_target.text);
    if (w == null || t == null) return null;
    final d = (t - w).round();
    return d == 0 ? null : d;
  }

  Future<void> _continue(Locale l) async {
    final age = int.tryParse(_age.text.trim());
    if (age == null || age < 13 || age > 120) {
      _snack(l, ProfileSetupStrings.badAge(l));
      return;
    }
    final h = _parseDouble(_height.text);
    if (h == null || h < 100 || h > 250) {
      _snack(l, ProfileSetupStrings.badHeight(l));
      return;
    }
    final wt = _parseDouble(_weight.text);
    if (wt == null || wt < 30 || wt > 400) {
      _snack(l, ProfileSetupStrings.badWeight(l));
      return;
    }
    final tgt = _parseDouble(_target.text);
    if (tgt == null || tgt < 30 || tgt > 400) {
      _snack(l, ProfileSetupStrings.badWeight(l));
      return;
    }
    final genderStr = switch (_gender) {
      _Gender.male => 'Male',
      _Gender.female => 'Female',
      _Gender.other => 'Other',
    };
    final goalStr = switch (_goal) {
      _FitnessGoal.loseFat => 'Lose Fat',
      _FitnessGoal.buildMuscle => 'Build Muscle',
      _FitnessGoal.maintain => 'Balanced/Recovery',
    };
    UserService.instance.saveProfile(
      age: age.toDouble(),
      gender: genderStr,
      height: h,
      weight: wt,
      targetWeight: tgt,
      goal: goalStr,
    ).ignore();
    if (!mounted) return;
    context.push(AppRoutes.profileSetupStep2);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = scope.locale;
    final ext = context.smartFitExt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fieldBorder = isDark ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB);
    final numberFill = Colors.white;

    final delta = _parseDeltaBadge();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.landing);
                      }
                    },
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ProfileSetupStrings.title(l),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.teal,
                          ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ThemeOutlineOrb(
                        selected: !isDark,
                        onTap: () => scope.setThemeBrightness(Brightness.light),
                        icon: Icons.wb_sunny_rounded,
                      ),
                      const SizedBox(width: 8),
                      _ThemeOutlineOrb(
                        selected: isDark,
                        onTap: () => scope.setThemeBrightness(Brightness.dark),
                        icon: Icons.dark_mode_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: ColoredBox(color: AppColors.teal),
                      ),
                      Expanded(
                        flex: 1,
                        child: ColoredBox(color: ext.inactiveTint.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      ProfileSetupStrings.step1of2(l),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            letterSpacing: 0.45,
                            color: AppColors.teal,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ProfileSetupStrings.headline(l),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ProfileSetupStrings.subtitle(l),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ext.mutedText,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 24),
                    _NumericBlock(
                      label: ProfileSetupStrings.age(l),
                      controller: _age,
                      borderColor: fieldBorder,
                      fill: numberFill,
                      formatting: FilteringTextInputFormatter.digitsOnly,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      ProfileSetupStrings.gender(l),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final g in _Gender.values) ...[
                          if (g != _Gender.male) const SizedBox(width: 10),
                          Expanded(
                            child: _GenderChip(
                              label: switch (g) {
                                _Gender.male => ProfileSetupStrings.male(l),
                                _Gender.female => ProfileSetupStrings.female(l),
                                _Gender.other => ProfileSetupStrings.other(l),
                              },
                              selected: _gender == g,
                              onTap: () => setState(() => _gender = g),
                              isDark: isDark,
                              inactiveTint: ext.inactiveTint,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _NumericBlock(
                            label: ProfileSetupStrings.heightCm(l),
                            controller: _height,
                            borderColor: fieldBorder,
                            fill: numberFill,
                            formatting: FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NumericBlock(
                            label: ProfileSetupStrings.weightKg(l),
                            controller: _weight,
                            borderColor: fieldBorder,
                            fill: numberFill,
                            formatting: FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      ProfileSetupStrings.primaryGoal(l),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _GoalTile(
                      title: ProfileSetupStrings.goalLoseTitle(l),
                      subtitle: ProfileSetupStrings.goalLoseSubtitle(l),
                      selected: _goal == _FitnessGoal.loseFat,
                      isDark: isDark,
                      onTap: () => setState(() => _goal = _FitnessGoal.loseFat),
                    ),
                    const SizedBox(height: 10),
                    _GoalTile(
                      title: ProfileSetupStrings.goalMuscleTitle(l),
                      subtitle: ProfileSetupStrings.goalMuscleSubtitle(l),
                      selected: _goal == _FitnessGoal.buildMuscle,
                      isDark: isDark,
                      onTap: () => setState(() => _goal = _FitnessGoal.buildMuscle),
                    ),
                    const SizedBox(height: 10),
                    _GoalTile(
                      title: ProfileSetupStrings.goalMaintainTitle(l),
                      subtitle: ProfileSetupStrings.goalMaintainSubtitle(l),
                      selected: _goal == _FitnessGoal.maintain,
                      isDark: isDark,
                      onTap: () => setState(() => _goal = _FitnessGoal.maintain),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      ProfileSetupStrings.targetWeightKg(l),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _target,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.black87,
                          ),
                      decoration: InputDecoration(
                        suffixIcon: delta == null
                            ? null
                            : Padding(
                                padding: const EdgeInsetsDirectional.only(end: 8),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.teal.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      ProfileSetupStrings.badgeKgFromCurrent(l, delta),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.teal,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                        suffixIconConstraints: const BoxConstraints(
                          minHeight: 0,
                          minWidth: 0,
                        ),
                        filled: true,
                        fillColor: numberFill,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.teal, width: 1.5),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _continue(l),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ProfileSetupStrings.continue_(l),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
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

class _NumericBlock extends StatelessWidget {
  const _NumericBlock({
    required this.label,
    required this.controller,
    required this.borderColor,
    required this.fill,
    required this.formatting,
    this.keyboardType =
        const TextInputType.numberWithOptions(decimal: true),
  });

  final String label;
  final TextEditingController controller;
  final Color borderColor;
  final Color fill;
  final TextInputFormatter formatting;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: [formatting],
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.black87,
              ),
          decoration: InputDecoration(
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
    required this.inactiveTint,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final Color inactiveTint;

  @override
  Widget build(BuildContext context) {
    final idleText = isDark ? Colors.white70 : const Color(0xFF4B5563);

    return Material(
      color: selected
          ? AppColors.teal
          : (isDark ? inactiveTint.withValues(alpha: 0.95) : const Color(0xFFF0F0F0)),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : idleText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = context.smartFitExt;
    final baseFill = isDark ? ext.cardBackground : const Color(0xFFF3F4F6);
    final fill = selected
        ? AppColors.teal.withValues(alpha: isDark ? 0.22 : 0.12)
        : baseFill;
    final edge = selected
        ? AppColors.teal
        : (isDark ? const Color(0xFF3D454B) : const Color(0xFFE5E7EB));

    const radius = 14.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: edge, width: selected ? 2 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ext.mutedText,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? AppColors.teal : ext.mutedText,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeOutlineOrb extends StatelessWidget {
  const _ThemeOutlineOrb({
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ext = context.smartFitExt;
    final idleIcon = Theme.of(context).brightness == Brightness.dark
        ? Colors.white54
        : Colors.black54;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? AppColors.teal : Colors.transparent,
            ),
            color: selected ? Colors.transparent : ext.inactiveTint.withValues(alpha: 0.85),
          ),
          child: Icon(icon, size: 20, color: selected ? AppColors.teal : idleIcon),
        ),
      ),
    );
  }
}
