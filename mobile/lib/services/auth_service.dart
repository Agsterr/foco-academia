import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/config/app_version.dart';
import '../data/services/app_update_service.dart';

class SessionExpiredException implements Exception {
  SessionExpiredException([this.message = 'Sessão expirada. Faça login novamente.']);
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  static const apiBase = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://academia.focodev.com.br',
  );

  String? token;
  String? academySlug;
  String? deviceId;

  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    academySlug = prefs.getString('academy_slug');
    deviceId = prefs.getString('device_id') ?? const Uuid().v4();
    await prefs.setString('device_id', deviceId!);
    return token != null;
  }

  Future<void> login(String email, String password, String slug) async {
    final response = await http.post(
      Uri.parse('$apiBase/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'academySlug': slug,
        'deviceId': deviceId,
        'deviceLabel': 'Flutter Android',
        'appClient': 'MOBILE',
        'appVersion': AppUpdateService.loginAppVersion(),
      }),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Erro no login');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    token = data['token'] as String;
    academySlug = slug;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token!);
    await prefs.setString('academy_slug', slug);
  }

  Future<void> logout() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<void> heartbeat() async {
    if (token == null || deviceId == null) return;
    try {
      final response = await http.post(
        Uri.parse('$apiBase/api/auth/heartbeat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'deviceId': deviceId,
          'appVersion': AppVersion.value,
          'appClient': 'MOBILE',
        }),
      );
      if (response.statusCode == 401) {
        await logout();
        throw SessionExpiredException();
      }
    } catch (e) {
      if (e is SessionExpiredException) rethrow;
      // Heartbeat é best-effort.
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('$apiBase$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 401) {
      await logout();
      throw SessionExpiredException();
    }
    if (response.statusCode != 200) {
      String message = 'Erro ${response.statusCode}';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          message = body['message'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Retorna null em 404 (ex.: sem treino outdoor ativo).
  Future<Map<String, dynamic>?> getOptional(String path) async {
    final response = await http.get(
      Uri.parse('$apiBase$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 401) {
      await logout();
      throw SessionExpiredException();
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Erro ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$apiBase$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 401) {
      await logout();
      throw SessionExpiredException();
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      String message = 'Erro ${response.statusCode}';
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map && parsed['message'] != null) {
          message = parsed['message'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
