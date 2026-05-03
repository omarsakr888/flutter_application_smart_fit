import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';

class WorkoutHubScreen extends StatelessWidget {
  const WorkoutHubScreen({super.key});

  static const _exercises = [
    _Exercise('Bench Press', '4 x 8 - 80kg', 'CHEST', Icons.fitness_center_rounded, true),
    _Exercise('Incline Press', '3 x 12 - 60kg', 'CHEST', Icons.downhill_skiing_rounded, true),
    _Exercise('Cable Fly', '3 x 15 - 15kg', 'CHEST', Icons.flutter_dash_rounded, false),
    _Exercise('Shoulder Press', '3 x 10 - 20kg', 'SHOULDERS', Icons.fitness_center_rounded, false),
    _Exercise('Lateral Raises', '4 x 15 - 8kg', 'SHOULDERS', Icons.waving_hand_rounded, false),
    _Exercise('Tricep Extension', '3 x 12 - 25kg', 'TRICEPS', Icons.bolt_rounded, false),
  ];

  static const _lightExercises = [
    _Exercise('Bench Press', '3 sets - 10 reps - 80kg', 'CHEST', Icons.fitness_center_rounded, true),
    _Exercise('Incline Press', '3 sets - 12 reps - 60kg', 'CHEST', Icons.trending_up_rounded, true),
    _Exercise('Cable Fly', '3 sets - 15 reps - 20kg', 'CHEST', Icons.flutter_dash_rounded, false),
    _Exercise('Overhead Press', '4 sets - 8 reps - 45kg', 'SHOULDERS', Icons.upload_rounded, false),
    _Exercise('Lateral Raises', '3 sets - 20 reps - 10kg', 'SHOULDERS', Icons.waving_hand_rounded, false),
    _Exercise('Tricep Pushdown', '3 sets - 12 reps - 30kg', 'ARMS', Icons.fitness_center_rounded, false),
  ];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final exercises = isDark ? _exercises : _lightExercises;

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF7FCF8),
      body: SafeArea(
        child: Column(
          children: [
            _WorkoutHeader(
              isDark: isDark,
              onLight: () => scope.setThemeBrightness(Brightness.light),
              onDark: () => scope.setThemeBrightness(Brightness.dark),
            ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF292929) : Colors.transparent,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, isDark ? 24 : 42, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DateStrip(),
                    SizedBox(height: isDark ? 60 : 72),
                    if (isDark) const _WorkoutSummaryCard() else const _LightTitleBlock(),
                    SizedBox(height: isDark ? 34 : 30),
                    for (var i = 0; i < exercises.length; i++) ...[
                      _ExerciseTile(exercise: exercises[i], focused: i == 2),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 20),
                    const _FeedbackButton(),
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

class _Exercise {
  const _Exercise(this.title, this.subtitle, this.tag, this.icon, this.done);

  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final bool done;
}

class _WorkoutHeader extends StatelessWidget {
  const _WorkoutHeader({
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
      height: isDark ? 88 : 102,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, isDark ? 14 : 20, 24, 14),
        child: Row(
          children: [
            const _ProfilePhoto(),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                'Workout Hub',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isDark ? const Color(0xFF31D39E) : AppColors.teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Download',
              onPressed: () {},
              icon: Icon(
                Icons.file_download_outlined,
                color: isDark ? Colors.white70 : const Color(0xFF6D7079),
                size: isDark ? 30 : 32,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: isDark ? 'Light theme' : 'Dark theme',
              onPressed: isDark ? onLight : onDark,
              icon: Icon(
                isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_rounded,
                color: isDark ? const Color(0xFF31D39E) : const Color(0xFF6D7079),
                size: isDark ? 34 : 36,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipOval(
      child: SizedBox(
        width: isDark ? 46 : 50,
        height: isDark ? 46 : 50,
        child: CustomPaint(painter: _ProfilePainter(isDark: isDark)),
      ),
    );
  }
}

class _ProfilePainter extends CustomPainter {
  const _ProfilePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF102421), const Color(0xFF050606)]
              : [const Color(0xFFE2F5F0), const Color(0xFF0B5F59)],
        ).createShader(Offset.zero & size),
    );
    final skin = Paint()..color = const Color(0xFFC58D72);
    final shirt = Paint()..color = AppColors.teal;
    final hair = Paint()..color = const Color(0xFF17110F);
    final center = Offset(size.width / 2, size.height * 0.45);
    canvas.drawCircle(center.translate(0, -8), size.width * 0.13, skin);
    canvas.drawArc(
      Rect.fromCircle(center: center.translate(0, -10), radius: size.width * 0.14),
      3.15,
      3.2,
      false,
      hair..style = PaintingStyle.stroke..strokeWidth = 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, 16), width: size.width * 0.36, height: size.height * 0.34),
        const Radius.circular(8),
      ),
      shirt,
    );
    final arm = Paint()
      ..color = skin.color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center.translate(-8, 12), center.translate(-18, 24), arm);
    canvas.drawLine(center.translate(8, 12), center.translate(18, 24), arm);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DateStrip extends StatelessWidget {
  const _DateStrip();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      const days = ['M', 'T', 'W', 'T', 'F', 'S'];
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < days.length; i++)
            _DarkDay(label: days[i], selected: i == 1),
        ],
      );
    }

    const days = [
      ('Mon', '12'),
      ('Tue', '13'),
      ('Wed', '14'),
      ('Thu', '15'),
      ('Fri', '16'),
      ('Sat', '17'),
      ('Sun', '18'),
    ];
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _LightDay(day: days[i].$1, date: days[i].$2, selected: i == 1),
          ),
        ],
      ],
    );
  }
}

class _DarkDay extends StatelessWidget {
  const _DarkDay({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            width: 56,
            height: 58,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : const Color(0xFF6F7078),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          selected ? 'TODAY' : '',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF31D39E),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LightDay extends StatelessWidget {
  const _LightDay({
    required this.day,
    required this.date,
    required this.selected,
  });

  final String day;
  final String date;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: selected ? null : Border.all(color: const Color(0xFFE4E7E7)),
            boxShadow: selected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: SizedBox(
            height: 88,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? Colors.white : const Color(0xFF1F2933),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selected ? Colors.white : const Color(0xFF1F2933),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          selected ? 'TODAY' : '',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.teal,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LightTitleBlock extends StatelessWidget {
  const _LightTitleBlock();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Push Day',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF676C72), size: 28),
                  const SizedBox(width: 10),
                  Text(
                    '2/6 completed - ~55 min',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF60656C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const _IntensityPill(),
      ],
    );
  }
}

class _WorkoutSummaryCard extends StatelessWidget {
  const _WorkoutSummaryCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF151517),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2C2C2F)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 34, 36, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Push Day',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const _IntensityPill(),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF9CA3AF), size: 22),
                const SizedBox(width: 12),
                Text(
                  '2/6 completed - ~55 min',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: 2 / 6,
                minHeight: 8,
                color: const Color(0xFF31D39E),
                backgroundColor: const Color(0xFF2A2A2D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntensityPill extends StatelessWidget {
  const _IntensityPill();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.teal.withValues(alpha: 0.14) : AppColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? AppColors.teal.withValues(alpha: 0.35) : AppColors.teal.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isDark ? 18 : 24, vertical: isDark ? 8 : 14),
        child: Text(
          '0.85x Intensity',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isDark ? const Color(0xFF31D39E) : AppColors.teal,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.focused,
  });

  final _Exercise exercise;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 14 : 16),
        border: Border.all(
          color: focused
              ? (isDark ? AppColors.teal.withValues(alpha: 0.55) : AppColors.teal.withValues(alpha: 0.35))
              : (isDark ? const Color(0xFF2B2B2D) : const Color(0xFFE8ECEB)),
          width: focused ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDark ? 24 : 26,
          vertical: isDark ? 24 : 26,
        ),
        child: isDark ? _DarkExerciseContent(exercise: exercise, focused: focused) : _LightExerciseContent(exercise: exercise),
      ),
    );
  }
}

class _DarkExerciseContent extends StatelessWidget {
  const _DarkExerciseContent({
    required this.exercise,
    required this.focused,
  });

  final _Exercise exercise;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final muted = const Color(0xFF80838D);

    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: focused ? AppColors.teal.withValues(alpha: 0.18) : const Color(0xFF242428),
            borderRadius: BorderRadius.circular(14),
          ),
          child: SizedBox(
            width: 68,
            height: 68,
            child: Icon(
              exercise.icon,
              color: focused ? const Color(0xFFFF8C34) : (exercise.done ? Colors.amber : Colors.white70),
              size: 34,
            ),
          ),
        ),
        const SizedBox(width: 26),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: exercise.done ? muted : Colors.white,
                  fontWeight: FontWeight.w800,
                  decoration: exercise.done ? TextDecoration.lineThrough : null,
                  decorationColor: muted,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    exercise.subtitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _Tag(label: exercise.tag),
                ],
              ),
            ],
          ),
        ),
        Icon(
          exercise.done ? Icons.check_circle_outline_rounded : Icons.circle_outlined,
          color: exercise.done ? const Color(0xFF31D39E) : const Color(0xFF4A4B55),
          size: 34,
        ),
      ],
    );
  }
}

class _LightExerciseContent extends StatelessWidget {
  const _LightExerciseContent({required this.exercise});

  final _Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: exercise.done ? const Color(0xFF68B9A8) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: exercise.done ? null : Border.all(color: const Color(0xFFB6C3BE), width: 2.5),
          ),
          child: SizedBox(
            width: 40,
            height: 40,
            child: exercise.done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 26),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: exercise.done ? const Color(0xFF7C8083) : Colors.black,
                  fontWeight: FontWeight.w700,
                  decoration: exercise.done ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                exercise.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF777B80),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _Tag(label: exercise.tag),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = label == 'CHEST';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A2F)
            : (active ? AppColors.teal.withValues(alpha: 0.11) : const Color(0xFFE4E5E7)),
        borderRadius: BorderRadius.circular(5),
        border: isDark || !active ? null : Border.all(color: AppColors.teal.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isDark ? const Color(0xFFB7B8BE) : (active ? AppColors.teal : const Color(0xFF62666C)),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: isDark ? 82 : 88,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: isDark ? 12 : 10,
          shadowColor: AppColors.teal.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {},
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isDark ? Icons.rate_review_outlined : Icons.send_rounded, size: 31),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                'Submit Workout Feedback (RPE)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
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
      _NavSpec(Icons.fitness_center_rounded, 'Workout', true, () {}),
      _NavSpec(Icons.restaurant_rounded, 'Nutrition', false, () => context.go(AppRoutes.nutrition)),
      _NavSpec(Icons.trending_up_rounded, 'Progress', false, () => context.go(AppRoutes.progress)),
      _NavSpec(Icons.smart_toy_outlined, 'Coach', false, () {}),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF242426) : const Color(0xFFEDEFF0))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: isDark ? 92 : 84,
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
    final idle = isDark ? const Color(0xFF5E6069) : const Color(0xFFA0A2AA);
    final color = item.selected ? active : idle;

    return Material(
      color: item.selected ? active.withValues(alpha: isDark ? 0.11 : 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 88,
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 28),
              const SizedBox(height: 5),
              Text(
                item.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
