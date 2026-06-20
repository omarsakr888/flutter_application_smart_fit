import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/admin_models.dart';

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  String? _adminKey;

  void setKey(String key) => _adminKey = key;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_adminKey != null) 'X-Admin-Key': _adminKey!,
      };

  Future<bool> verifyKey(String key) async {
    final uri = Uri.parse('${BackendConfig.baseUrl}/admin/stats');
    final res = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'X-Admin-Key': key,
    }).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      _adminKey = key;
      return true;
    }
    return false;
  }

  Future<AdminStats> getStats() async {
    final res = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/admin/stats'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    _checkStatus(res);
    return AdminStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<({int total, List<AdminUser> users})> getUsers({
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse(
      '${BackendConfig.baseUrl}/admin/users?limit=$limit&offset=$offset',
    );
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      total: (body['total'] as num? ?? 0).toInt(),
      users: (body['users'] as List<dynamic>? ?? [])
          .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<AdminMlAnalytics> getMlAnalytics() async {
    final res = await http
        .get(
          Uri.parse('${BackendConfig.baseUrl}/admin/ml-analytics'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(res);
    return AdminMlAnalytics.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<({int total, List<AdminScan> scans})> getScans({
    int limit = 40,
    int offset = 0,
  }) async {
    final uri = Uri.parse(
      '${BackendConfig.baseUrl}/admin/scans?limit=$limit&offset=$offset',
    );
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      total: (body['total'] as num? ?? 0).toInt(),
      scans: (body['scans'] as List<dynamic>? ?? [])
          .map((e) => AdminScan.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode == 403) throw Exception('Invalid admin key.');
    if (res.statusCode != 200) {
      throw Exception('Admin request failed (${res.statusCode})');
    }
  }
}
