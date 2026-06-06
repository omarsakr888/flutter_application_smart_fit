class DashboardData {
  const DashboardData({
    required this.userName,
    required this.caloriesTarget,
    required this.caloriesConsumed,
    required this.hydrationCups,
    required this.hydrationTarget,
    required this.streak,
    required this.recoveryInsight,
    required this.todayWorkoutLabel,
    required this.nextMeal,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        userName: (json['user_name'] as String?) ?? 'there',
        caloriesTarget: (json['calories_target'] as num?)?.toDouble() ?? 2000,
        caloriesConsumed: (json['calories_consumed'] as num?)?.toDouble() ?? 0,
        hydrationCups: (json['hydration_cups'] as num?)?.toInt() ?? 5,
        hydrationTarget: (json['hydration_target'] as num?)?.toInt() ?? 8,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        recoveryInsight: (json['recovery_insight'] as String?) ?? '',
        todayWorkoutLabel: (json['today_workout_label'] as String?) ?? 'Rest Day',
        nextMeal: (json['next_meal'] as String?) ?? 'All meals logged',
      );

  final String userName;
  final double caloriesTarget;
  final double caloriesConsumed;
  final int hydrationCups;
  final int hydrationTarget;
  final int streak;
  final String recoveryInsight;
  final String todayWorkoutLabel;
  final String nextMeal;

  double get caloriesFraction =>
      caloriesTarget > 0 ? (caloriesConsumed / caloriesTarget).clamp(0.0, 1.0) : 0;

  int get caloriesConsumedInt => caloriesConsumed.round();
  int get caloriesTargetInt => caloriesTarget.round();
}


class ProgressData {
  const ProgressData({
    required this.totalScans,
    required this.fatLostKg,
    required this.muscleGainedKg,
    required this.weightHistory,
    required this.scanDates,
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) => ProgressData(
        totalScans: (json['total_scans'] as num?)?.toInt() ?? 0,
        fatLostKg: (json['fat_lost_kg'] as num?)?.toDouble() ?? 0,
        muscleGainedKg: (json['muscle_gained_kg'] as num?)?.toDouble() ?? 0,
        weightHistory: ((json['weight_history'] as List?) ?? [])
            .map((v) => (v as num).toDouble())
            .toList(),
        scanDates: List<String>.from((json['scan_dates'] as List?) ?? []),
      );

  final int totalScans;
  final double fatLostKg;
  final double muscleGainedKg;
  final List<double> weightHistory;
  final List<String> scanDates;
}
