import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/plan_result.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  final _client = http.Client();

  // ── Profile ──────────────────────────────────────────────────────────────

  Future<void> saveProfile({
    required double? age,
    required String? gender,
    required double? height,
    required double? weight,
    required double? targetWeight,
    required String? goal,
  }) async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/profile');
    await _client
        .post(
          uri,
          headers: await AuthService.instance.authHeaders,
          body: jsonEncode({
            'age': age,
            'gender': gender,
            'height': height,
            'weight': weight,
            'target_weight': targetWeight,
            'goal': goal,
          }),
        )
        .timeout(const Duration(seconds: 10));
  }

  // ── Preferences ───────────────────────────────────────────────────────────

  Future<void> savePreferences({
    required String dietType,
    required int preferredDays,
    required bool hydration,
    required bool sleep,
    required bool recovery,
  }) async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/preferences');
    await _client
        .post(
          uri,
          headers: await AuthService.instance.authHeaders,
          body: jsonEncode({
            'diet_type': dietType,
            'preferred_days': preferredDays,
            'hydration_enabled': hydration,
            'sleep_enabled': sleep,
            'recovery_enabled': recovery,
          }),
        )
        .timeout(const Duration(seconds: 10));
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Future<DashboardData?> getDashboard() async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/dashboard');
    final response = await _client
        .get(uri, headers: await AuthService.instance.authHeaders)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final dashboard = body['dashboard'] as Map<String, dynamic>?;
    if (dashboard == null) return null;
    return DashboardData.fromJson(dashboard);
  }

  // ── Plan ──────────────────────────────────────────────────────────────────

  Future<PlanResult?> getPlan() async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/plan');
    final response = await _client
        .get(uri, headers: await AuthService.instance.authHeaders)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final planJson = body['plan'] as Map<String, dynamic>?;
    if (planJson == null) return null;
    return PlanResult.fromJson(planJson);
  }

  // ── Activity Logs ─────────────────────────────────────────────────────────

  Future<List<String>> logWorkout({
    required int dayNumber,
    int rpe = 5,
    String? planId,
    List<String> exercisesCompleted = const [],
    int durationMinutes = 0,
  }) async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/log-workout');
    final response = await _client
        .post(
          uri,
          headers: await AuthService.instance.authHeaders,
          body: jsonEncode({
            'plan_id': planId,
            'day_number': dayNumber,
            'rpe': rpe,
            'exercises_completed': exercisesCompleted,
            'duration_minutes': durationMinutes,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final newAchievements = body['new_achievements'] as List? ?? [];
    return newAchievements
        .map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  Future<void> logMeal(
    String slotName, {
    String? planId,
    double caloriesConsumed = 0,
  }) async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/log-meal');
    await _client
        .post(
          uri,
          headers: await AuthService.instance.authHeaders,
          body: jsonEncode({
            'plan_id': planId,
            'slot_name': slotName,
            'calories_consumed': caloriesConsumed,
          }),
        )
        .timeout(const Duration(seconds: 10));
  }

  // ── Progress ──────────────────────────────────────────────────────────────

  Future<ProgressData?> getProgress() async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/progress');
    final response = await _client
        .get(uri, headers: await AuthService.instance.authHeaders)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final progressJson = body['progress'] as Map<String, dynamic>?;
    if (progressJson == null) return null;
    return ProgressData.fromJson(progressJson);
  }

  // ── Daily Progress ────────────────────────────────────────────────────────

  Future<DailyProgress?> getDailyProgress(String date) async {
    final uri = Uri.parse(
      '${BackendConfig.baseUrl}/users/daily-progress?date=$date',
    );
    final response = await _client
        .get(uri, headers: await AuthService.instance.authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return DailyProgress.fromJson(body);
  }

  // ── Achievements ──────────────────────────────────────────────────────────

  Future<List<AchievementData>> getAchievements() async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/achievements');
    final response = await _client
        .get(uri, headers: await AuthService.instance.authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (body['achievements'] as List?) ?? [];
    return list
        .map((a) => AchievementData.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  // ── Hydration ──────────────────────────────────────────────────────────────

  Future<int> getTodayHydrationCups() async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/hydration');
    final response = await _client
        .get(uri, headers: await AuthService.instance.authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return 0;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['cups'] as int?) ?? 0;
  }

  Future<void> logHydration({int cups = 1}) async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/log-hydration');
    await _client
        .post(
          uri,
          headers: await AuthService.instance.authHeaders,
          body: jsonEncode({'cups': cups}),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<List<String>> checkAchievements() async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/achievements/check');
    final response = await _client
        .post(
          uri,
          headers: await AuthService.instance.authHeaders,
          body: jsonEncode({}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final newList = body['new_achievements'] as List? ?? [];
    return newList
        .map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }
}
