import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/config/app_version.dart';
import '../data/services/app_update_service.dart';
import 'online_auth_gate.dart';

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
  bool _refreshing = false;

  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    academySlug = prefs.getString('academy_slug');
    deviceId = prefs.getString('device_id') ?? const Uuid().v4();
    await prefs.setString('device_id', deviceId!);
    return token != null;
  }

  Future<void> _persistToken(String newToken) async {
    token = newToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', newToken);
  }

  /// Renova o JWT ao abrir o app (aceita token expirado dentro da janela da API).
  Future<bool> refreshSession() async {
    if (token == null || token!.isEmpty) return false;
    if (_refreshing) return token != null;
    _refreshing = true;
    try {
      final response = await http.post(
        Uri.parse('$apiBase/api/auth/refresh'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newToken = data['token'] as String?;
        if (newToken != null && newToken.isNotEmpty) {
          await _persistToken(newToken);
          await OnlineAuthGate.instance.markOnlineAuthSuccess();
          return true;
        }
      }
      if (response.statusCode == 401) {
        await logout();
        return false;
      }
      // 403 academia bloqueada etc. — mantém token; usuário verá mensagem na próxima chamada.
      return response.statusCode == 200;
    } catch (_) {
      // Sem rede: mantém token local para tentar depois.
      return token != null;
    } finally {
      _refreshing = false;
    }
  }

  /// Renova token + heartbeat (ao abrir ou voltar ao app).
  Future<void> ensureSession() async {
    await refreshSession();
    await heartbeat();
  }

  /// Exige rede: refresh + heartbeat e marca validação online (janela de 48h).
  Future<bool> ensureOnlineSession() async {
    if (token == null || token!.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('$apiBase/api/auth/refresh'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newToken = data['token'] as String?;
        if (newToken != null && newToken.isNotEmpty) {
          await _persistToken(newToken);
        }
      } else if (response.statusCode == 401) {
        await logout();
        return false;
      } else if (response.statusCode != 200) {
        return false;
      }

      final hb = await http.post(
        Uri.parse('$apiBase/api/auth/heartbeat'),
        headers: _headers(),
        body: jsonEncode({
          'deviceId': deviceId,
          'appVersion': AppVersion.value,
          'appClient': 'MOBILE',
        }),
      );
      if (_isLikelyAuthFailure(hb)) {
        await logout();
        return false;
      }
      if (hb.statusCode == 200) {
        await OnlineAuthGate.instance.markOnlineAuthSuccess();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
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
    await _persistToken(data['token'] as String);
    academySlug = slug;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('academy_slug', slug);
    await OnlineAuthGate.instance.markOnlineAuthSuccess();
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
        headers: _headers(),
        body: jsonEncode({
          'deviceId': deviceId,
          'appVersion': AppVersion.value,
          'appClient': 'MOBILE',
        }),
      );
      await _handleAuthResponse(response);
      if (response.statusCode == 200) {
        await OnlineAuthGate.instance.markOnlineAuthSuccess();
      }
    } catch (e) {
      if (e is SessionExpiredException) rethrow;
      // Heartbeat é best-effort.
    }
  }

  Map<String, String> _headers() => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  bool _isLikelyAuthFailure(http.Response response) {
    if (response.statusCode == 401) return true;
    if (response.statusCode != 403) return false;
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        final msg = (body['message'] as String?) ?? '';
        if (msg.contains('Academia') ||
            msg.contains('bloqueado') ||
            msg.contains('desativada')) {
          return false;
        }
      }
    } catch (_) {}
    return true;
  }

  Future<void> _handleAuthResponse(http.Response response) async {
    if (_isLikelyAuthFailure(response)) {
      await logout();
      throw SessionExpiredException();
    }
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        return body['message'] as String;
      }
    } catch (_) {}
    return fallback;
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    bool retryOnAuth = true,
  }) async {
    var response = await request();
    if (retryOnAuth && _isLikelyAuthFailure(response)) {
      final renewed = await refreshSession();
      if (renewed) {
        response = await request();
      }
    }
    await _handleAuthResponse(response);
    return response;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _send(
      () => http.get(Uri.parse('$apiBase$path'), headers: _headers()),
    );
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Erro ${response.statusCode}'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await _send(
      () => http.get(Uri.parse('$apiBase$path'), headers: _headers()),
    );
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Erro ${response.statusCode}'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded;
    throw Exception('Resposta inválida');
  }

  /// Retorna null em 404 (ex.: sem treino outdoor ativo).
  Future<Map<String, dynamic>?> getOptional(String path) async {
    final response = await _send(
      () => http.get(Uri.parse('$apiBase$path'), headers: _headers()),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Erro ${response.statusCode}'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await _send(
      () => http.post(
        Uri.parse('$apiBase$path'),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_errorMessage(response, 'Erro ${response.statusCode}'));
    }
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final response = await _send(
      () => http.put(
        Uri.parse('$apiBase$path'),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_errorMessage(response, 'Erro ${response.statusCode}'));
    }
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
