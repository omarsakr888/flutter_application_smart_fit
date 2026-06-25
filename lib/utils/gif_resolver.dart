import 'package:flutter/material.dart';
import 'package:string_similarity/string_similarity.dart';

/// Full catalogue of all available GIF asset names (without extension).
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

/// Maps a muscle-group tag (e.g. bodyPart) to the subset of available GIF names.
const _gifsByMuscle = <String, List<String>>{
  'CHEST': ['Incline_Bench_Press', 'Smith_Machine_Incline_Press'],
  'BACK': ['Lat_Pulldown', 'Chest_Supported_Dumbbell_Curl'],
  'SHOULDERS': [
    'Incline_Dumbbell_Shoulder_Press',
    'Lateral_Raise',
    'Standing_Front_Raise',
  ],
  'BICEPS': [
    'Chest_Supported_Dumbbell_Curl',
    'Dumbbell_Preacher_Curl',
    'Standing_Barbell_Curl',
  ],
  'TRICEPS': [
    'Lying_Triceps_Extension',
    'Prone_Triceps_Extension',
    'Seated_Overhead_Triceps_Extension',
  ],
  'LEGS': ['Degree_Leg_Press', 'Lying_Leg_Press', 'Leg_Press_Calf_Raise'],
  'CALVES': ['Leg_Press_Calf_Raise'],
  'ABS': ['Hanging_Knee_Raise', 'Oblique_Knee_Raise'],
};

/// Finds the best-matching GIF for an exercise, prioritising GIFs that belong
/// to the correct muscle group. Never returns null; falls back to a global default.
String findGifPath(String exerciseName, {String muscleTag = ''}) {
  final name = exerciseName.toLowerCase();
  final tag = muscleTag.toUpperCase();

  // Resolve the muscle-group bucket.
  final bucket =
      _gifsByMuscle[tag] ??
      _gifsByMuscle.entries
          .where((e) => tag.contains(e.key) || e.key.contains(tag))
          .map((e) => e.value)
          .firstOrNull;

  String normalize(String s) => s.replaceAll('_', ' ').toLowerCase();

  // Helper: best match within a list of candidates.
  (String?, double) bestIn(List<String> candidates) {
    String? bestName;
    double bestRating = 0;
    for (final gif in candidates) {
      final rating = StringSimilarity.compareTwoStrings(name, normalize(gif));
      if (rating > bestRating) {
        bestRating = rating;
        bestName = gif;
      }
    }
    return (bestName, bestRating);
  }

  // 1. Try muscle-group bucket first.
  if (bucket != null) {
    final (gif, rating) = bestIn(bucket);
    if (gif != null && rating >= 0.35) {
      return 'assets/gifs/$gif.gif';
    }
  }

  // 2. Fall back to entire catalogue.
  final (gif, rating) = bestIn(_availableGifs);
  if (gif != null && rating >= 0.5) {
    return 'assets/gifs/$gif.gif';
  }

  // 3. Robust fallback: default exercise GIF (Lat Pulldown is chosen as standard).
  return 'assets/gifs/Lat_Pulldown.gif';
}

/// Shows a beautiful fullscreen interactive dialog displaying the exercise GIF.
void showExpandedGif(
  BuildContext context,
  String gifPath,
  String exerciseName,
) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        child: Stack(
          children: [
            // Tap background to dismiss
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    title: Text(
                      exerciseName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    centerTitle: true,
                  ),
                  Expanded(
                    child: Center(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Hero(
                          tag: 'expanded_gif_${exerciseName}',
                          child: Image.asset(
                            gifPath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.fitness_center_rounded,
                                  color: Colors.white70,
                                  size: 80,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text(
                      'Pinch to zoom • Tap background to close',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
