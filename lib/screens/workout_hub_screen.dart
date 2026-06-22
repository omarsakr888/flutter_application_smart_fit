import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:string_similarity/string_similarity.dart';

import '../models/plan_result.dart';
import '../router/app_routes.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_utils.dart';
import '../widgets/ai_chat_fab.dart';
import '../widgets/smart_fit_app_bar.dart';
import '../widgets/smart_fit_drawer.dart';

class WorkoutHubScreen extends StatefulWidget {
  const WorkoutHubScreen({super.key});

  @override
  State<WorkoutHubScreen> createState() => _WorkoutHubScreenState();
}

class _WorkoutHubScreenState extends State<WorkoutHubScreen> {
  PlanResult? _plan;
  final _checkedExercises = <int>{};
  bool _completing = false;
  bool _loading = true;

  static const _fallbackDark = [
    _Exercise('Bench Press', '4 x 8–10 reps', 'CHEST', Icons.fitness_center_rounded, true),
    _Exercise('Incline Press', '3 x 10–12 reps', 'CHEST', Icons.downhill_skiing_rounded, true),
    _Exercise('Cable Fly', '3 x 12–15 reps', 'CHEST', Icons.flutter_dash_rounded, false),
    _Exercise('Shoulder Press', '3 x 8–10 reps', 'SHOULDERS', Icons.fitness_center_rounded, false),
    _Exercise('Lateral Raises', '4 x 12–15 reps', 'SHOULDERS', Icons.waving_hand_rounded, false),
    _Exercise('Tricep Extension', '3 x 10–12 reps', 'TRICEPS', Icons.bolt_rounded, false),
  ];

  static const _fallbackLight = [
    _Exercise('Bench Press', '3 sets - 10 reps', 'CHEST', Icons.fitness_center_rounded, true),
    _Exercise('Incline Press', '3 sets - 12 reps', 'CHEST', Icons.trending_up_rounded, true),
    _Exercise('Cable Fly', '3 sets - 15 reps', 'CHEST', Icons.flutter_dash_rounded, false),
    _Exercise('Overhead Press', '4 sets - 8 reps', 'SHOULDERS', Icons.upload_rounded, false),
    _Exercise('Lateral Raises', '3 sets - 20 reps', 'SHOULDERS', Icons.waving_hand_rounded, false),
    _Exercise('Tricep Pushdown', '3 sets - 12 reps', 'ARMS', Icons.fitness_center_rounded, false),
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final plan = await UserService.instance.getPlan();
      if (mounted) setState(() { _plan = plan; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load workout plan. Check your connection.')),
        );
      }
    }
  }

  Future<void> _completeWorkout(List<_Exercise> exercises) async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      final names = _checkedExercises.map((i) => exercises[i].title).toList();
      final dayNumber = _plan?.workoutSplit.firstOrNull?.dayNumber ?? 1;
      final newAchievements = await UserService.instance.logWorkout(
        dayNumber: dayNumber,
        exercisesCompleted: names,
        durationMinutes: names.length * 7,
        planId: _plan?.planId,
      );
      if (mounted) {
        if (newAchievements.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Achievement unlocked: ${newAchievements.join(', ')}!'),
              backgroundColor: AppColors.teal,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout logged!')),
          );
        }
        setState(() => _checkedExercises.clear());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log workout. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  List<_Exercise> _buildExercises() {
    final plan = _plan;
    if (plan == null || plan.workoutSplit.isEmpty) return [];
    final day = plan.workoutSplit.first;
    return day.exercises.map((e) {
      final subtitle = '${e.sets} × ${e.repsMin}–${e.repsMax} reps';
      return _Exercise(e.name, subtitle, e.bodyPart.toUpperCase(),
          Icons.fitness_center_rounded, false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final planExercises = _buildExercises();
    final exercises = planExercises.isNotEmpty
        ? planExercises
        : (isDark ? _fallbackDark : _fallbackLight);

    final dayLabel = _plan?.workoutSplit.firstOrNull?.dayLabel ?? 'Push Day';
    final intensity = _plan?.intensityMultiplier ?? 0.85;
    final completed = _checkedExercises.length;

    return Scaffold(
      appBar: const SmartFitAppBar(),
      drawer: const SmartFitDrawer(),
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF7FCF8),
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
              color: isDark ? const Color(0xFF292929) : Colors.transparent,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  context.widthPct(0.05),
                  isDark ? context.heightPct(0.03) : context.heightPct(0.05),
                  context.widthPct(0.05),
                  context.heightPct(0.04),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DateStrip(),
                    SizedBox(height: isDark ? context.heightPct(0.07) : context.heightPct(0.08)),
                    if (isDark)
                      _WorkoutSummaryCard(
                        dayLabel: dayLabel,
                        completed: completed,
                        total: exercises.length,
                        intensityMultiplier: intensity,
                      )
                    else
                      _LightTitleBlock(
                        dayLabel: dayLabel,
                        completed: completed,
                        total: exercises.length,
                        intensityMultiplier: intensity,
                      ),
                    SizedBox(height: isDark ? context.heightPct(0.04) : context.heightPct(0.035)),
                    for (var i = 0; i < exercises.length; i++) ...[
                      _ExerciseTile(
                        exercise: exercises[i],
                        focused: !_checkedExercises.contains(i) &&
                            _checkedExercises.length == i,
                        isChecked: _checkedExercises.contains(i),
                        onToggle: () => setState(() {
                          if (!_checkedExercises.remove(i)) {
                            _checkedExercises.add(i);
                          }
                        }),
                      ),
                      SizedBox(height: context.heightPct(0.02)),
                    ],
                    SizedBox(height: context.heightPct(0.025)),
                    _CompleteWorkoutButton(
                      completing: _completing,
                      checkedCount: _checkedExercises.length,
                      total: exercises.length,
                      onPressed: () => _completeWorkout(exercises),
                    ),
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

class _Exercise {
  const _Exercise(this.title, this.subtitle, this.tag, this.icon, this.done);

  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final bool done;
}

class _DateStrip extends StatelessWidget {
  const _DateStrip();

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static DateTime _monday(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final monday = _monday(today);
    final todayIndex = today.weekday - 1; // 0 = Mon

    if (isDark) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < 6; i++)
            _DarkDay(label: _dayLetters[i], selected: i == todayIndex),
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _LightDay(
              day: _dayNames[i],
              date: monday.add(Duration(days: i)).day.toString(),
              selected: i == todayIndex,
            ),
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
  const _LightTitleBlock({
    required this.dayLabel,
    required this.completed,
    required this.total,
    required this.intensityMultiplier,
  });

  final String dayLabel;
  final int completed;
  final int total;
  final double intensityMultiplier;

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
                dayLabel,
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
                    '$completed/$total completed',
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
        _IntensityPill(multiplier: intensityMultiplier),
      ],
    );
  }
}

class _WorkoutSummaryCard extends StatelessWidget {
  const _WorkoutSummaryCard({
    required this.dayLabel,
    required this.completed,
    required this.total,
    required this.intensityMultiplier,
  });

  final String dayLabel;
  final int completed;
  final int total;
  final double intensityMultiplier;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
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
                    dayLabel,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _IntensityPill(multiplier: intensityMultiplier),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF9CA3AF), size: 22),
                const SizedBox(width: 12),
                Text(
                  '$completed/$total completed',
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
                value: progress,
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
  const _IntensityPill({required this.multiplier});

  final double multiplier;

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
          '${multiplier.toStringAsFixed(2)}x Intensity',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isDark ? const Color(0xFF31D39E) : AppColors.teal,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

const _availableGifs = [
  'Chest_Supported_Dumbbell_Curl',
  'Degree_Leg_Press',
  'Dumbbell_Preacher_Curl',
  'Hanging_Knee_Raise',
  'Incline_Bench_Press',
  'Incline_Dumbbell_Shoulder_Press',
  'Lat_Pulldown',
  'Lateral_Raise',
  'Leg_Press_Calf_Raise',
  'Lying_Leg_Press',
  'Lying_Triceps_Extension',
  'Oblique_Knee_Raise',
  'Prone_Triceps_Extension',
  'Seated_Overhead_Triceps_Extension',
  'Smith_Machine_Incline_Press',
  'Standing_Barbell_Curl',
  'Standing_Front_Raise',
];

String? _findGifPath(String exerciseName) {
  final options = _availableGifs.map((e) => e.replaceAll('_', ' ').toLowerCase()).toList();
  final bestMatch = StringSimilarity.findBestMatch(exerciseName.toLowerCase(), options);
  if (bestMatch.bestMatch.rating! >= 0.5) {
    return 'assets/gifs/${_availableGifs[bestMatch.bestMatchIndex]}.gif';
  }
  return null;
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.focused,
    required this.isChecked,
    required this.onToggle,
  });

  final _Exercise exercise;
  final bool focused;
  final bool isChecked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onToggle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          borderRadius: BorderRadius.circular(isDark ? 14 : 16),
          border: Border.all(
            color: isChecked
                ? AppColors.teal.withValues(alpha: isDark ? 0.55 : 0.35)
                : focused
                    ? (isDark ? AppColors.teal.withValues(alpha: 0.35) : AppColors.teal.withValues(alpha: 0.2))
                    : (isDark ? const Color(0xFF2B2B2D) : const Color(0xFFE8ECEB)),
            width: isChecked || focused ? 1.4 : 1,
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
          padding: EdgeInsets.symmetric(
            horizontal: isDark ? 24 : 26,
            vertical: isDark ? 24 : 26,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              isDark
                  ? _DarkExerciseContent(exercise: exercise, focused: focused, isChecked: isChecked)
                  : _LightExerciseContent(exercise: exercise, isChecked: isChecked),
              const SizedBox(height: 18),
              Builder(
                builder: (context) {
                  final gifPath = _findGifPath(exercise.title);
                  if (gifPath != null) {
                    return Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF18181A) : const Color(0xFFF4F7F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE4E9E7),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(gifPath, fit: BoxFit.cover, width: double.infinity),
                    );
                  }
                  return Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18181A) : const Color(0xFFF4F7F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE4E9E7),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_outline_rounded,
                          color: isDark ? const Color(0xFF2DB994) : AppColors.teal,
                          size: 26,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Exercise Instruction Placeholder',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white54 : const Color(0xFF5A605E),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                        ),
                        Text(
                          'No GIF matched for "${exercise.title}"',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white30 : const Color(0xFF8A908E),
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkExerciseContent extends StatelessWidget {
  const _DarkExerciseContent({
    required this.exercise,
    required this.focused,
    required this.isChecked,
  });

  final _Exercise exercise;
  final bool focused;
  final bool isChecked;

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
              color: focused ? const Color(0xFFFF8C34) : (isChecked ? Colors.amber : Colors.white70),
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
                  color: isChecked ? muted : Colors.white,
                  fontWeight: FontWeight.w800,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
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
          isChecked ? Icons.check_circle_outline_rounded : Icons.circle_outlined,
          color: isChecked ? const Color(0xFF31D39E) : const Color(0xFF4A4B55),
          size: 34,
        ),
      ],
    );
  }
}

class _LightExerciseContent extends StatelessWidget {
  const _LightExerciseContent({required this.exercise, required this.isChecked});

  final _Exercise exercise;
  final bool isChecked;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: isChecked ? const Color(0xFF68B9A8) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isChecked ? null : Border.all(color: const Color(0xFFB6C3BE), width: 2.5),
          ),
          child: SizedBox(
            width: 40,
            height: 40,
            child: isChecked
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
                  color: isChecked ? const Color(0xFF7C8083) : Colors.black,
                  fontWeight: FontWeight.w700,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
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

class _CompleteWorkoutButton extends StatelessWidget {
  const _CompleteWorkoutButton({
    required this.completing,
    required this.checkedCount,
    required this.total,
    required this.onPressed,
  });

  final bool completing;
  final int checkedCount;
  final int total;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = checkedCount == 0
        ? 'Complete Workout'
        : 'Complete Workout ($checkedCount/$total)';

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
        onPressed: completing ? null : onPressed,
        child: completing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 28),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
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
      _NavSpec(Icons.smart_toy_outlined, 'Coach', false, () => context.push(AppRoutes.aiCoach)),
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
