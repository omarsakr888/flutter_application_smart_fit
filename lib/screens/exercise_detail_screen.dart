import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/exercise_view_data.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';
import '../utils/gif_resolver.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});

  final ExerciseViewData? exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Safety check for null
    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Exercise Details'.tr(context))),
        body: Center(
          child: Text('No details found for this exercise.'.tr(context)),
        ),
      );
    }

    final data = exercise!;
    final gif =
        data.gifPath ?? findGifPath(data.name, muscleTag: data.targetMuscle);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121213)
          : const Color(0xFFF7FCF8),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              key: const ValueKey('exercise_detail_header'),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: 28,
                      color: isDark ? Colors.white : const Color(0xFF1D2425),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Exercise Guide'.tr(context),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF5A5E66),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance back button space
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Large Exercise GIF Container (40% - 45% screen height)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Hero(
                        tag: 'exercise_gif_${data.name}',
                        child: Container(
                          height: MediaQuery.sizeOf(context).height * 0.4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E22)
                                : const Color(0xFFEFF3F2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2C2C32)
                                  : const Color(0xFFDEE5E3),
                              width: 1.5,
                            ),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: GestureDetector(
                            onTap: () =>
                                showExpandedGif(context, gif, data.name),
                            child: Image.asset(
                              gif,
                              fit: BoxFit
                                  .contain, // best visual result to ensure full animation fits
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.fitness_center_rounded,
                                    color: AppColors.teal,
                                    size: 50,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Exercise Metadata details
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data.name,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1D2425),
                                            height: 1.25,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      data.targetMuscle
                                          .tr(context)
                                          .toUpperCase(),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: AppColors.teal,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.6,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (data.dayLabel != null) ...[
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.teal.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.teal.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    data.dayLabel!.tr(context),
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: AppColors.teal,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Target Metadata Tiles Row
                          Row(
                            children: [
                              Expanded(
                                child: _MetaCard(
                                  label: 'Sets'.tr(context),
                                  value:
                                      '${data.setsRepsLabel.split('×').firstOrNull?.trim() ?? '3'}',
                                  icon: Icons.repeat_rounded,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _MetaCard(
                                  label: 'Reps'.tr(context),
                                  value:
                                      '${data.setsRepsLabel.split('×').lastOrNull?.trim() ?? '10-12'}',
                                  icon: Icons.fitness_center_rounded,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Instructions / Notes Section
                          Text(
                            'Instructions'.tr(context),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1D2425),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1D1D22)
                                  : const Color(0xFFF0F4F3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF28282E)
                                    : const Color(0xFFE4EAE8),
                              ),
                            ),
                            child: Text(
                              data.notes != null && data.notes!.isNotEmpty
                                  ? data.notes!.tr(context)
                                  : 'Perform the exercise with a slow tempo. Keep your core engaged and maintain stable breathing throughout the movement.'
                                        .tr(context),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF4A4E55),
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions (Close Button)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isDark ? 8 : 10),
                    ),
                  ),
                  onPressed: () => context.pop(),
                  child: Text(
                    'Close'.tr(context),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1D22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF28282E) : const Color(0xFFECEEEF),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.teal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark ? Colors.white54 : const Color(0xFF8A8D93),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1D2425),
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
