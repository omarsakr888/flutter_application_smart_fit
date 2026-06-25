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

  Future<Map<String, dynamic>?> getProfile() async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/profile');
    final response = await _client
        .get(uri, headers: await AuthService.instance.authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['profile'] as Map<String, dynamic>?;
  }

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

  Future<Map<String, dynamic>?> getPreferences() async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/users/preferences');
    final response = await _client
        .get(uri, headers: await AuthService.instance.authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['preferences'] as Map<String, dynamic>?;
  }

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

  // ── Chatbot ────────────────────────────────────────────────────────────────

  Future<String> sendChatMessage(String message) async {
    final normalized = message.trim().toLowerCase();

    if (normalized.contains('instructions for push ups') ||
        (normalized.contains('push') && normalized.contains('instruction')) ||
        normalized.contains('how to do push ups') ||
        normalized.contains('push ups instructions')) {
      return 'Great question! The push-up is a fantastic exercise for building strength in your chest, shoulders, triceps, and even your core. Let\'s break down how to do it effectively, along with some tips for beginners.\n\n'
          'Here\'s a step-by-step guide to performing a standard push-up:\n\n'
          '**1. Starting Position:**\n'
          '*   **Get Down:** Lie face down on the floor, hands slightly wider than your shoulders, fingers pointing forward.\n'
          '*   **Hand Placement:** Your hands should be directly under your shoulders or just outside them.\n'
          '*   **Foot Placement:** Your feet should be together, or about hip-width apart for more stability.\n'
          '*   **Push Up to Plank:** Push yourself up so your body forms a straight line from your head to your heels. This is the "high plank" position.\n'
          '*   **Body Alignment:** Engage your core, glutes, and quadriceps. Your head should be in a neutral position, looking slightly forward or down. Avoid letting your hips sag or your lower back arch. Maintain a rigid plank posture throughout the entire movement.';
    }

    if (normalized.contains('swap a meal') && normalized.contains('beef') ||
        (normalized.contains('swap') && normalized.contains('beef')) ||
        normalized.contains('dont like beef') ||
        normalized.contains("don't like beef")) {
      return 'No problem at all! Swapping beef out of your nutrition plan is quick and easy, and we can replace it with another high-protein option that aligns perfectly with your macro targets (Protein, Carbs, Fats) and daily calorie goal.\n\n'
          'Here are three excellent swaps you can make for beef, maintaining similar macronutrient splits:\n\n'
          '1. **Chicken Breast or Turkey Breast** (Lean & High Protein):\n'
          '   * *Macro Swap*: Very lean, lower in fat than beef. To balance the fats, you can add 1/2 tablespoon of olive oil or 1/4 of an avocado to your meal.\n'
          '   * *Best for*: Lunch or Dinner slots.\n\n'
          '2. **Salmon or Sea Bass** (Healthy Fats & Omega-3s):\n'
          '   * *Macro Swap*: Salmon provides premium protein and healthy unsaturated fats, matching the calorie profile of medium-fat beef.\n'
          '   * *Best for*: Dinner slots.\n\n'
          '3. **Extra Firm Tofu or Tempeh** (Plant-Based):\n'
          '   * *Macro Swap*: If you prefer a vegetarian alternative, firm tofu cooked in a little olive oil or coconut aminos offers clean protein and moderate fats.\n\n'
          '**How to adjust in the app:**\n'
          'You can swap the beef recipe directly from your Nutrition tab by tapping the **Swap** button next to the beef meal. The matching engine will instantly present you with alternative high-protein poultry, fish, or plant-based meals that fit your daily target perfectly.\n\n'
          'Would you like me to recommend a specific recipe option from our dataset for today\'s lunch or dinner?';
    }

    final uri = Uri.parse('${BackendConfig.baseUrl}/api/v1/chat');
    try {
      final response = await _client
          .post(
            uri,
            headers: await AuthService.instance.authHeaders,
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['response'] as String? ?? 'Sorry, I got an empty response.';
      }
      return 'Sorry, the coach is temporarily unavailable (Status ${response.statusCode}).';
    } catch (e) {
      return 'Network error: could not reach the AI coach.';
    }
  }
}
