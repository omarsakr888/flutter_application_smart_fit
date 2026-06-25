import re

file_path = 'lib/screens/workout_hub_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
imports = """import '../widgets/ai_chat_fab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../localization/app_strings.dart';"""
content = content.replace("import '../widgets/ai_chat_fab.dart';", imports)

# 2. Translations
content = content.replace(
    "const SnackBar(content: Text('Could not load workout plan. Check your connection.'))",
    "SnackBar(content: Text('Could not load workout plan. Check your connection.'.tr(context)))"
)
content = content.replace(
    "content: Text('Achievement unlocked: ${newAchievements.join(', ')}!')",
    "content: Text('Achievement unlocked: ${newAchievements.join(\', \')}!'.tr(context))"
)
content = content.replace(
    "const SnackBar(content: Text('Workout logged!'))",
    "SnackBar(content: Text('Workout logged!'.tr(context)))"
)

# 3. Add workoutDay to cards in _WorkoutHubScreenState
content = content.replace(
    "_WorkoutSummaryCard(\n                        dayLabel: dayLabel,",
    "_WorkoutSummaryCard(\n                        workoutDay: _plan?.workoutSplit.firstOrNull,\n                        dayLabel: dayLabel,"
)
content = content.replace(
    "_LightTitleBlock(\n                        dayLabel: dayLabel,",
    "_LightTitleBlock(\n                        workoutDay: _plan?.workoutSplit.firstOrNull,\n                        dayLabel: dayLabel,"
)

# 4. _LightTitleBlock modifications
light_block_old = """class _LightTitleBlock extends StatelessWidget {
  const _LightTitleBlock({
    required this.dayLabel,
    required this.completed,
    required this.total,
    required this.intensityMultiplier,
  });

  final String dayLabel;"""
light_block_new = """class _LightTitleBlock extends StatelessWidget {
  const _LightTitleBlock({
    this.workoutDay,
    required this.dayLabel,
    required this.completed,
    required this.total,
    required this.intensityMultiplier,
  });

  final WorkoutDay? workoutDay;
  final String dayLabel;"""
content = content.replace(light_block_old, light_block_new)

light_ui_old = """              Text(
                dayLabel,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),"""
light_ui_new = """              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      dayLabel,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                  if (workoutDay != null)
                    Consumer(builder: (context, ref, _) {
                      final isFav = ref.watch(favoritesProvider).workouts.any(
                          (w) => w.dayLabel == workoutDay!.dayLabel && w.focusZone == workoutDay!.focusZone);
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? Colors.redAccent : Colors.grey,
                        ),
                        onPressed: () => ref.read(favoritesProvider.notifier).toggleWorkout(workoutDay!),
                      );
                    }),
                ],
              ),"""
content = content.replace(light_ui_old, light_ui_new)

# 5. _WorkoutSummaryCard modifications
dark_block_old = """class _WorkoutSummaryCard extends StatelessWidget {
  const _WorkoutSummaryCard({
    required this.dayLabel,
    required this.completed,
    required this.total,
    required this.intensityMultiplier,
  });

  final String dayLabel;"""
dark_block_new = """class _WorkoutSummaryCard extends StatelessWidget {
  const _WorkoutSummaryCard({
    this.workoutDay,
    required this.dayLabel,
    required this.completed,
    required this.total,
    required this.intensityMultiplier,
  });

  final WorkoutDay? workoutDay;
  final String dayLabel;"""
content = content.replace(dark_block_old, dark_block_new)

dark_ui_old = """              Text(
                dayLabel,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),"""
dark_ui_new = """              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      dayLabel,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (workoutDay != null)
                    Consumer(builder: (context, ref, _) {
                      final isFav = ref.watch(favoritesProvider).workouts.any(
                          (w) => w.dayLabel == workoutDay!.dayLabel && w.focusZone == workoutDay!.focusZone);
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? Colors.redAccent : Colors.white70,
                        ),
                        onPressed: () => ref.read(favoritesProvider.notifier).toggleWorkout(workoutDay!),
                      );
                    }),
                ],
              ),"""
content = content.replace(dark_ui_old, dark_ui_new)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied successfully.")
