/// Data models for the admin panel API responses.

class AdminStats {
  final int totalUsers;
  final int totalScans;
  final int totalPlans;
  final int newUsersToday;
  final int scansToday;
  final int plansToday;
  final int workoutLogsTotal;
  final int mealLogsTotal;
  final int hydrationLogsTotal;

  const AdminStats({
    required this.totalUsers,
    required this.totalScans,
    required this.totalPlans,
    required this.newUsersToday,
    required this.scansToday,
    required this.plansToday,
    required this.workoutLogsTotal,
    required this.mealLogsTotal,
    required this.hydrationLogsTotal,
  });

  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
        totalUsers: (j['total_users'] as num? ?? 0).toInt(),
        totalScans: (j['total_scans'] as num? ?? 0).toInt(),
        totalPlans: (j['total_plans'] as num? ?? 0).toInt(),
        newUsersToday: (j['new_users_today'] as num? ?? 0).toInt(),
        scansToday: (j['scans_today'] as num? ?? 0).toInt(),
        plansToday: (j['plans_today'] as num? ?? 0).toInt(),
        workoutLogsTotal: (j['workout_logs_total'] as num? ?? 0).toInt(),
        mealLogsTotal: (j['meal_logs_total'] as num? ?? 0).toInt(),
        hydrationLogsTotal: (j['hydration_logs_total'] as num? ?? 0).toInt(),
      );
}

class AdminUser {
  final String id;
  final String email;
  final String name;
  final String createdAt;
  final String? lastLoginDate;
  final int dailyStreak;
  final double? age;
  final String? gender;
  final double? weight;
  final String? goal;
  final int scanCount;
  final int planCount;
  final int workoutCount;
  final int mealCount;

  const AdminUser({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.lastLoginDate,
    required this.dailyStreak,
    this.age,
    this.gender,
    this.weight,
    this.goal,
    required this.scanCount,
    required this.planCount,
    required this.workoutCount,
    required this.mealCount,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: j['id'] as String? ?? '',
        email: j['email'] as String? ?? '',
        name: j['name'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
        lastLoginDate: j['last_login_date'] as String?,
        dailyStreak: (j['daily_streak'] as num? ?? 0).toInt(),
        age: (j['age'] as num?)?.toDouble(),
        gender: j['gender'] as String?,
        weight: (j['weight'] as num?)?.toDouble(),
        goal: j['goal'] as String?,
        scanCount: (j['scan_count'] as num? ?? 0).toInt(),
        planCount: (j['plan_count'] as num? ?? 0).toInt(),
        workoutCount: (j['workout_count'] as num? ?? 0).toInt(),
        mealCount: (j['meal_count'] as num? ?? 0).toInt(),
      );
}

class DistributionItem {
  final String label;
  final int count;
  final double pct;

  const DistributionItem({
    required this.label,
    required this.count,
    required this.pct,
  });

  factory DistributionItem.fromJson(Map<String, dynamic> j) => DistributionItem(
        label: j['label'] as String? ?? '',
        count: (j['count'] as num? ?? 0).toInt(),
        pct: (j['pct'] as num? ?? 0).toDouble(),
      );
}

class FeatureAverage {
  final String key;
  final String label;
  final String unit;
  final double? avg;
  final int n;

  const FeatureAverage({
    required this.key,
    required this.label,
    required this.unit,
    this.avg,
    required this.n,
  });

  factory FeatureAverage.fromJson(Map<String, dynamic> j) => FeatureAverage(
        key: j['key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        unit: j['unit'] as String? ?? '',
        avg: (j['avg'] as num?)?.toDouble(),
        n: (j['n'] as num? ?? 0).toInt(),
      );
}

class AdminMlAnalytics {
  final int totalAnalyzed;
  final double avgConfidencePct;
  final int intensityReducedCount;
  final List<DistributionItem> personaDistribution;
  final List<DistributionItem> focusZoneDistribution;
  final List<DistributionItem> goalDistribution;
  final List<FeatureAverage> featureAverages;

  const AdminMlAnalytics({
    required this.totalAnalyzed,
    required this.avgConfidencePct,
    required this.intensityReducedCount,
    required this.personaDistribution,
    required this.focusZoneDistribution,
    required this.goalDistribution,
    required this.featureAverages,
  });

  factory AdminMlAnalytics.fromJson(Map<String, dynamic> j) => AdminMlAnalytics(
        totalAnalyzed: (j['total_analyzed'] as num? ?? 0).toInt(),
        avgConfidencePct: (j['avg_confidence_pct'] as num? ?? 0).toDouble(),
        intensityReducedCount: (j['intensity_reduced_count'] as num? ?? 0).toInt(),
        personaDistribution: (j['persona_distribution'] as List<dynamic>? ?? [])
            .map((e) => DistributionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        focusZoneDistribution: (j['focus_zone_distribution'] as List<dynamic>? ?? [])
            .map((e) => DistributionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        goalDistribution: (j['goal_distribution'] as List<dynamic>? ?? [])
            .map((e) => DistributionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        featureAverages: (j['feature_averages'] as List<dynamic>? ?? [])
            .map((e) => FeatureAverage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AdminScan {
  final String id;
  final String userEmail;
  final String userName;
  final String status;
  final String createdAt;
  final String? filename;
  final String reportType;
  final double extractionConfidence;
  final String persona;
  final String focusZone;
  final double mlConfidence;
  final bool intensityReduced;
  final double? targetCalories;

  const AdminScan({
    required this.id,
    required this.userEmail,
    required this.userName,
    required this.status,
    required this.createdAt,
    this.filename,
    required this.reportType,
    required this.extractionConfidence,
    required this.persona,
    required this.focusZone,
    required this.mlConfidence,
    required this.intensityReduced,
    this.targetCalories,
  });

  factory AdminScan.fromJson(Map<String, dynamic> j) => AdminScan(
        id: j['id'] as String? ?? '',
        userEmail: j['user_email'] as String? ?? '',
        userName: j['user_name'] as String? ?? '',
        status: j['status'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
        filename: j['filename'] as String?,
        reportType: j['report_type'] as String? ?? '',
        extractionConfidence: (j['extraction_confidence'] as num? ?? 0).toDouble(),
        persona: j['persona'] as String? ?? '',
        focusZone: j['focus_zone'] as String? ?? '',
        mlConfidence: (j['ml_confidence'] as num? ?? 0).toDouble(),
        intensityReduced: j['intensity_reduced'] as bool? ?? false,
        targetCalories: (j['target_calories'] as num?)?.toDouble(),
      );
}
