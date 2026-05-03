import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/smart_fit_theme.dart';

enum _DietType { omnivore, vegetarian, vegan }

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  _DietType _diet = _DietType.omnivore;
  final Set<int> _workoutDays = {0, 2, 4};
  bool _hydration = true;
  bool _sleep = false;
  bool _recovery = false;

  void _toggleDay(int index) {
    setState(() {
      if (_workoutDays.contains(index)) {
        _workoutDays.remove(index);
      } else {
        _workoutDays.add(index);
      }
    });
  }

  void _finish() {
    context.push(AppRoutes.inBodyScan);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final ext = context.smartFitExt;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              isDark: isDark,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.profileSetup);
                }
              },
              onLight: () => scope.setThemeBrightness(Brightness.light),
              onDark: () => scope.setThemeBrightness(Brightness.dark),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF2C3335) : const Color(0xFFF0F2F1)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _ProgressPair(),
                    const SizedBox(height: 34),
                    Text(
                      'STEP 2 OF 2',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your preferences',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Customize your nutrition and schedule',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: ext.mutedText,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 44),
                    _SectionHeader(title: 'DIET TYPE', trailing: null),
                    const SizedBox(height: 18),
                    _DietTile(
                      title: 'Omnivore',
                      subtitle: isDark ? null : 'Balanced diet with all food groups',
                      icon: Icons.restaurant_rounded,
                      selected: _diet == _DietType.omnivore,
                      onTap: () => setState(() => _diet = _DietType.omnivore),
                    ),
                    const SizedBox(height: 20),
                    _DietTile(
                      title: 'Vegetarian',
                      subtitle: isDark ? null : 'Plant-based with dairy and eggs',
                      icon: Icons.eco_outlined,
                      selected: _diet == _DietType.vegetarian,
                      onTap: () => setState(() => _diet = _DietType.vegetarian),
                    ),
                    const SizedBox(height: 20),
                    _DietTile(
                      title: 'Vegan',
                      subtitle: isDark ? null : 'Strict plant-based nutrition',
                      icon: Icons.spa_outlined,
                      selected: _diet == _DietType.vegan,
                      onTap: () => setState(() => _diet = _DietType.vegan),
                    ),
                    const SizedBox(height: 48),
                    _SectionHeader(
                      title: 'WORKOUT DAYS',
                      trailing: '${_workoutDays.length} days selected',
                    ),
                    const SizedBox(height: 18),
                    _WorkoutDayRow(
                      selectedDays: _workoutDays,
                      onTap: _toggleDay,
                    ),
                    const SizedBox(height: 44),
                    _SectionHeader(title: 'PUSH NOTIFICATIONS', trailing: null),
                    const SizedBox(height: 20),
                    _NotificationPanel(
                      hydration: _hydration,
                      sleep: _sleep,
                      recovery: _recovery,
                      onHydration: (value) => setState(() => _hydration = value),
                      onSleep: (value) => setState(() => _sleep = value),
                      onRecovery: (value) => setState(() => _recovery = value),
                    ),
                    if (!isDark) ...[
                      const SizedBox(height: 44),
                      const _PerformanceBanner(),
                    ] else
                      const SizedBox(height: 88),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                14 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        elevation: isDark ? 0 : 12,
                        shadowColor: AppColors.teal.withValues(alpha: 0.24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isDark ? 8 : 7),
                        ),
                      ),
                      onPressed: _finish,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Finish Setup',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 20),
                          Icon(Icons.arrow_forward_rounded, size: 28),
                        ],
                      ),
                    ),
                  ),
                  if (!isDark) ...[
                    const SizedBox(height: 16),
                    Text(
                      'You can change these later in settings.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: ext.mutedText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
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
      height: 84,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 30),
            ),
            const Spacer(),
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
    final bg = isDark ? const Color(0xFF202927) : const Color(0xFFF0F5F0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF3B4642) : Colors.white,
          width: 1.4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeSegmentButton(
              selected: !isDark,
              icon: Icons.wb_sunny_outlined,
              onTap: onLight,
            ),
            const SizedBox(width: 4),
            _ThemeSegmentButton(
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

class _ThemeSegmentButton extends StatelessWidget {
  const _ThemeSegmentButton({
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
    final idle = isDark ? Colors.white54 : const Color(0xFF9AA19F);

    return Material(
      color: selected ? AppColors.teal : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color: selected ? Colors.white : idle,
            size: 25,
          ),
        ),
      ),
    );
  }
}

class _ProgressPair extends StatelessWidget {
  const _ProgressPair();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          const Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: SizedBox(height: 7),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.trailing,
  });

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.teal,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _DietTile extends StatelessWidget {
  const _DietTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ext = context.smartFitExt;
    final fill = selected
        ? AppColors.teal.withValues(alpha: isDark ? 0.12 : 0.06)
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final border = selected
        ? AppColors.teal
        : (isDark ? const Color(0xFF303636) : const Color(0xFFE1E1E1));
    final iconBg = selected
        ? AppColors.teal.withValues(alpha: isDark ? 1 : 0.11)
        : (isDark ? const Color(0xFF303736) : const Color(0xFFFAFAFA));
    final iconColor = selected
        ? (isDark ? Colors.white : AppColors.teal)
        : (isDark ? Colors.white70 : const Color(0xFF5E6466));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: isDark ? 138 : 104,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDark ? 34 : 22,
              vertical: 20,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(isDark ? 14 : 999),
                  ),
                  child: SizedBox(
                    width: isDark ? 66 : 60,
                    height: isDark ? 66 : 60,
                    child: Icon(icon, color: iconColor, size: isDark ? 30 : 28),
                  ),
                ),
                SizedBox(width: isDark ? 22 : 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ext.mutedText,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected ? Icons.check_circle_outline_rounded : Icons.circle_outlined,
                  color: selected ? AppColors.teal : ext.inactiveTint,
                  size: isDark ? 36 : 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkoutDayRow extends StatelessWidget {
  const _WorkoutDayRow({
    required this.selectedDays,
    required this.onTap,
  });

  final Set<int> selectedDays;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _DayButton(
              label: days[i],
              selected: selectedDays.contains(i),
              onTap: () => onTap(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected
        ? AppColors.teal
        : (isDark ? const Color(0xFF1F1F1F) : Colors.white);
    final border = isDark ? const Color(0xFF353A3A) : const Color(0xFFE0E0E0);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? AppColors.teal : border),
          ),
          child: Center(
            child: SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({
    required this.hydration,
    required this.sleep,
    required this.recovery,
    required this.onHydration,
    required this.onSleep,
    required this.onRecovery,
  });

  final bool hydration;
  final bool sleep;
  final bool recovery;
  final ValueChanged<bool> onHydration;
  final ValueChanged<bool> onSleep;
  final ValueChanged<bool> onRecovery;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return Column(
        children: [
          _NotificationTile(
            icon: Icons.water_drop_outlined,
            label: 'Hydration reminders',
            value: hydration,
            onChanged: onHydration,
          ),
          const SizedBox(height: 10),
          _NotificationTile(
            icon: Icons.dark_mode_outlined,
            label: 'Sleep analysis',
            value: sleep,
            onChanged: onSleep,
          ),
          const SizedBox(height: 10),
          _NotificationTile(
            icon: Icons.bolt_outlined,
            label: 'Recovery alerts',
            value: recovery,
            onChanged: onRecovery,
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _NotificationTile(
            icon: Icons.water_drop_outlined,
            label: 'Hydration',
            value: hydration,
            onChanged: onHydration,
          ),
          const Divider(height: 1, indent: 6, endIndent: 6),
          _NotificationTile(
            icon: Icons.dark_mode_outlined,
            label: 'Sleep',
            value: sleep,
            onChanged: onSleep,
          ),
          const Divider(height: 1, indent: 6, endIndent: 6),
          _NotificationTile(
            icon: Icons.self_improvement_rounded,
            label: 'Recovery',
            value: recovery,
            onChanged: onRecovery,
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ext = context.smartFitExt;
    final fill = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final border = isDark ? Colors.transparent : const Color(0xFFF0F0F0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(isDark ? 8 : 7),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        child: Row(
          children: [
            Icon(
              icon,
              color: value ? AppColors.teal : ext.mutedText,
              size: 28,
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.teal,
              inactiveThumbColor: isDark ? const Color(0xFFD8DEDD) : Colors.white,
              inactiveTrackColor: isDark ? const Color(0xFF26312F) : const Color(0xFFE2E3E6),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceBanner extends StatelessWidget {
  const _PerformanceBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 2.6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _PerformancePainter()),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.58),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Text(
                  'Your journey to peak performance starts\nnow.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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

class _PerformancePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFDDE4DE),
          Color(0xFFF1F4EF),
          Color(0xFFC8D1CA),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wall);

    final floor = Paint()..color = const Color(0xFF88948C);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.68, size.width, size.height * 0.32),
      floor,
    );

    final mat = Paint()..color = AppColors.teal.withValues(alpha: 0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.15, size.height * 0.78, size.width * 0.7, 8),
        const Radius.circular(99),
      ),
      mat,
    );

    final skin = Paint()..color = const Color(0xFFC58D72);
    final outfit = Paint()..color = const Color(0xFF0F766E);
    final hair = Paint()..color = const Color(0xFF25201D);

    final center = Offset(size.width * 0.52, size.height * 0.42);
    canvas.drawCircle(center.translate(0, -36), 16, skin);
    canvas.drawArc(
      Rect.fromCircle(center: center.translate(0, -39), radius: 18),
      3.18,
      3.1,
      false,
      hair..style = PaintingStyle.stroke..strokeWidth = 7,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, 0), width: 52, height: 58),
        const Radius.circular(18),
      ),
      outfit,
    );

    final limb = Paint()
      ..color = skin.color
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center.translate(-22, -18), center.translate(-54, -58), limb);
    canvas.drawLine(center.translate(22, -18), center.translate(54, -58), limb);
    canvas.drawLine(center.translate(-54, -58), center.translate(-14, -82), limb);
    canvas.drawLine(center.translate(54, -58), center.translate(14, -82), limb);

    final leg = Paint()
      ..color = const Color(0xFF0B5F59)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center.translate(-15, 30), center.translate(-84, 70), leg);
    canvas.drawLine(center.translate(15, 30), center.translate(90, 70), leg);
    canvas.drawLine(center.translate(-84, 70), center.translate(-135, 64), leg);
    canvas.drawLine(center.translate(90, 70), center.translate(140, 64), leg);

    final light = Paint()..color = Colors.white.withValues(alpha: 0.34);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.08, 0, 12, size.height), light);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.93, 0, 8, size.height), light);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
