import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

/// Manages authentication state using flutter_secure_storage.
///
/// Credentials (user_id, access_token) are stored in the OS keychain /
/// Android Keystore — never in SharedPreferences or plain files.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // Use BiometricStorage on Android for extra security (optional upgrade).
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    webOptions: WebOptions(dbName: 'smart_fit_auth', publicKey: 'smart_fit_key'),
  );

  static const _keyUserId = 'sf_user_id';
  static const _keyUserName = 'sf_user_name';
  static const _keyUserEmail = 'sf_user_email';
  static const _keyAccessToken = 'sf_access_token';

  // ── Getters ───────────────────────────────────────────────────────────────

  Future<String> get currentUserId async =>
      (await _storage.read(key: _keyUserId)) ?? 'local-user';

  Future<String> get currentUserName async =>
      (await _storage.read(key: _keyUserName)) ?? '';

  Future<String?> getAuthToken() => _storage.read(key: _keyAccessToken);

  Future<bool> get isLoggedIn async {
    final id = await _storage.read(key: _keyUserId);
    final token = await _storage.read(key: _keyAccessToken);
    return id != null && id != 'local-user' && token != null;
  }

  /// Returns headers with Content-Type and the Bearer token if available.
  Future<Map<String, String>> get authHeaders async {
    final token = await getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth API calls ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register(
    String email,
    String password, {
    String name = '',
  }) async {
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
        (body['message'] as String?) ??
            'Registration failed (${response.statusCode})',
      );
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
        (body['message'] as String?) ??
            'Login failed (${response.statusCode})',
      );
    }
    await _persist(body);
    return body;
  }

  Future<Map<String, dynamic>> socialLogin(
    String email,
    String name,
    String provider,
  ) async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/auth/social-login');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'name': name, 'provider': provider}),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(
        (body['message'] as String?) ?? 'Social login failed (${response.statusCode})',
      );
    }
    await _persist(body);
    return body;
  }

  Future<void> logout() async {
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserName);
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyAccessToken);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _persist(Map<String, dynamic> body) async {
    final userId = body['user_id'] as String?;
    final name = body['name'] as String?;
    final email = body['email'] as String?;
    final token = body['access_token'] as String?;
    if (userId != null) await _storage.write(key: _keyUserId, value: userId);
    if (name != null) await _storage.write(key: _keyUserName, value: name);
    if (email != null) await _storage.write(key: _keyUserEmail, value: email);
    if (token != null) await _storage.write(key: _keyAccessToken, value: token);
  }
}
