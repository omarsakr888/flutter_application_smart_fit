class WorkoutExercise {
  const WorkoutExercise({
    required this.name,
    required this.bodyPart,
    required this.targetMuscle,
    required this.equipment,
    required this.focusZone,
    required this.movementPattern,
    required this.sets,
    required this.repsMin,
    required this.repsMax,
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) => WorkoutExercise(
        name: (json['name'] as String?) ?? '',
        bodyPart: (json['body_part'] as String?) ?? '',
        targetMuscle: (json['target_muscle'] as String?) ?? '',
        equipment: (json['equipment'] as String?) ?? '',
        focusZone: (json['focus_zone'] as String?) ?? '',
        movementPattern: (json['movement_pattern'] as String?) ?? '',
        sets: (json['sets'] as num?)?.toInt() ?? 3,
        repsMin: (json['reps_min'] as num?)?.toInt() ?? 8,
        repsMax: (json['reps_max'] as num?)?.toInt() ?? 12,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'body_part': bodyPart,
        'target_muscle': targetMuscle,
        'equipment': equipment,
        'focus_zone': focusZone,
        'movement_pattern': movementPattern,
        'sets': sets,
        'reps_min': repsMin,
        'reps_max': repsMax,
      };

  final String name;
  final String bodyPart;
  final String targetMuscle;
  final String equipment;
  final String focusZone;
  final String movementPattern;
  final int sets;
  final int repsMin;
  final int repsMax;

  String get repsLabel => repsMin == repsMax ? '$repsMin' : '$repsMin–$repsMax';
  String get setsRepsLabel => '$sets × $repsLabel';
}


class WorkoutDay {
  const WorkoutDay({
    required this.dayNumber,
    required this.dayLabel,
    required this.focusZone,
    required this.exercises,
    required this.note,
  });

  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
        dayNumber: (json['day_number'] as num?)?.toInt() ?? 1,
        dayLabel: (json['day_label'] as String?) ?? 'Day 1',
        focusZone: (json['focus_zone'] as String?) ?? '',
        note: (json['note'] as String?) ?? '',
        exercises: ((json['exercises'] as List?) ?? [])
            .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'day_number': dayNumber,
        'day_label': dayLabel,
        'focus_zone': focusZone,
        'note': note,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  final int dayNumber;
  final String dayLabel;
  final String focusZone;
  final List<WorkoutExercise> exercises;
  final String note;
}


class MealSlot {
  const MealSlot({
    required this.slotName,
    required this.targetCalories,
    required this.recipeName,
    required this.caloriesPerServing,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.dietType,
    required this.healthScore,
    required this.rating,
    required this.mealTimeCategory,
    required this.ingredients,
    required this.instructions,
    this.imageUrl,
  });

  factory MealSlot.fromJson(Map<String, dynamic> json) => MealSlot(
        slotName: (json['slot_name'] as String?) ?? '',
        targetCalories: (json['target_calories'] as num?)?.toDouble() ?? 0,
        recipeName: (json['recipe_name'] as String?) ?? '',
        caloriesPerServing: (json['calories_per_serving'] as num?)?.toDouble() ?? 0,
        proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
        carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
        fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
        dietType: (json['diet_type'] as String?) ?? '',
        healthScore: (json['health_score'] as num?)?.toDouble() ?? 0,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        mealTimeCategory: (json['meal_time_category'] as String?) ?? '',
        ingredients: (json['ingredients'] as String?) ?? '',
        instructions: (json['instructions'] as String?) ?? '',
        imageUrl: json['image_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'slot_name': slotName,
        'target_calories': targetCalories,
        'recipe_name': recipeName,
        'calories_per_serving': caloriesPerServing,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'diet_type': dietType,
        'health_score': healthScore,
        'rating': rating,
        'meal_time_category': mealTimeCategory,
        'ingredients': ingredients,
        'instructions': instructions,
        'image_url': imageUrl,
      };

  final String slotName;
  final double targetCalories;
  final String recipeName;
  final double caloriesPerServing;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String dietType;
  final double healthScore;
  final double rating;
  final String mealTimeCategory;
  final String ingredients;
  final String instructions;
  final String? imageUrl;

  String get displayName => slotName.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
}


class NutritionMacros {
  const NutritionMacros({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
  });

  factory NutritionMacros.fromJson(Map<String, dynamic> json) => NutritionMacros(
        proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
        carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
        fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
        proteinPct: (json['protein_pct'] as num?)?.toDouble() ?? 30,
        carbsPct: (json['carbs_pct'] as num?)?.toDouble() ?? 40,
        fatPct: (json['fat_pct'] as num?)?.toDouble() ?? 30,
      );

  final double proteinG;
  final double carbsG;
  final double fatG;
  final double proteinPct;
  final double carbsPct;
  final double fatPct;
}


class PlanResult {
  const PlanResult({
    required this.focusZone,
    required this.mlConfidencePct,
    required this.intensityMultiplier,
    required this.intensityReason,
    required this.targetCaloriesKcal,
    required this.macros,
    required this.dailyMeals,
    required this.preferredDays,
    required this.workoutSplit,
    required this.warnings,
    this.planId,
    this.generatedAt,
  });

  factory PlanResult.fromJson(Map<String, dynamic> json) {
    final nutrition = (json['nutrition'] as Map<String, dynamic>?) ?? {};
    final training = (json['training'] as Map<String, dynamic>?) ?? {};
    return PlanResult(
      focusZone: (json['focus_zone'] as String?) ?? '',
      mlConfidencePct: (json['ml_confidence_pct'] as num?)?.toDouble() ?? 0,
      intensityMultiplier: (json['intensity_multiplier'] as num?)?.toDouble() ?? 1.0,
      intensityReason: (json['intensity_reason'] as String?) ?? '',
      targetCaloriesKcal:
          (nutrition['target_calories_kcal'] as num?)?.toDouble() ?? 2000,
      macros: NutritionMacros.fromJson(
          (nutrition['macros'] as Map<String, dynamic>?) ?? {}),
      dailyMeals: ((nutrition['daily_meals'] as List?) ?? [])
          .map((m) => MealSlot.fromJson(m as Map<String, dynamic>))
          .toList(),
      preferredDays: (training['preferred_days'] as num?)?.toInt() ?? 4,
      workoutSplit: ((training['workout_split'] as List?) ?? [])
          .map((d) => WorkoutDay.fromJson(d as Map<String, dynamic>))
          .toList(),
      warnings:
          List<String>.from((json['warnings'] as List?) ?? []),
      planId: json['plan_id'] as String?,
      generatedAt: json['generated_at'] as String?,
    );
  }

  final String focusZone;
  final double mlConfidencePct;
  final double intensityMultiplier;
  final String intensityReason;
  final double targetCaloriesKcal;
  final NutritionMacros macros;
  final List<MealSlot> dailyMeals;
  final int preferredDays;
  final List<WorkoutDay> workoutSplit;
  final List<String> warnings;
  final String? planId;
  final String? generatedAt;
}
