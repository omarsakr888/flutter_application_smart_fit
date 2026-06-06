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
    final userId = await AuthService.instance.currentUserId;
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/profile');
    await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
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
    final userId = await AuthService.instance.currentUserId;
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/preferences');
    await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
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
    final userId = await AuthService.instance.currentUserId;
    final uri =
        Uri.parse('${BackendConfig.baseUrl}/users/dashboard?user_id=$userId');
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final dashboard = body['dashboard'] as Map<String, dynamic>?;
    if (dashboard == null) return null;
    return DashboardData.fromJson(dashboard);
  }

  // ── Plan ──────────────────────────────────────────────────────────────────

  Future<PlanResult?> getPlan() async {
    final userId = await AuthService.instance.currentUserId;
    final uri =
        Uri.parse('${BackendConfig.baseUrl}/users/plan?user_id=$userId');
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final planJson = body['plan'] as Map<String, dynamic>?;
    if (planJson == null) return null;
    return PlanResult.fromJson(planJson);
  }

  // ── Activity Logs ─────────────────────────────────────────────────────────

  Future<void> logWorkout({
    required int dayNumber,
    required int rpe,
    String? planId,
  }) async {
    final userId = await AuthService.instance.currentUserId;
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/plan/workout-log');
    await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'plan_id': planId,
            'day_number': dayNumber,
            'rpe': rpe,
          }),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<void> logMeal(String slotName, {String? planId}) async {
    final userId = await AuthService.instance.currentUserId;
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/plan/meal-log');
    await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'plan_id': planId,
            'slot_name': slotName,
          }),
        )
        .timeout(const Duration(seconds: 10));
  }

  // ── Progress ──────────────────────────────────────────────────────────────

  Future<ProgressData?> getProgress() async {
    final userId = await AuthService.instance.currentUserId;
    final uri =
        Uri.parse('${BackendConfig.baseUrl}/users/progress?user_id=$userId');
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final progressJson = body['progress'] as Map<String, dynamic>?;
    if (progressJson == null) return null;
    return ProgressData.fromJson(progressJson);
  }
}
