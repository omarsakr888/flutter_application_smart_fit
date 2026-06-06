import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/backend_config.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _keyUserId = 'user_id';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';

  Future<String> get currentUserId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId) ?? 'local-user';
  }

  Future<String> get currentUserName async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName) ?? '';
  }

  Future<bool> get isLoggedIn async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyUserId) &&
        prefs.getString(_keyUserId) != 'local-user';
  }

  Future<Map<String, dynamic>> register(
      String email, String password, {String name = ''}) async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/auth/register');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password, 'name': name}),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(
          (body['message'] as String?) ?? 'Registration failed (${response.statusCode})');
    }
    await _persist(body);
    return body;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/auth/login');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(
          (body['message'] as String?) ?? 'Login failed (${response.statusCode})');
    }
    await _persist(body);
    return body;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
  }

  Future<void> _persist(Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = body['user_id'] as String?;
    final name = body['name'] as String?;
    final email = body['email'] as String?;
    if (userId != null) await prefs.setString(_keyUserId, userId);
    if (name != null) await prefs.setString(_keyUserName, name);
    if (email != null) await prefs.setString(_keyUserEmail, email);
  }
}
