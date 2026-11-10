import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

/// Login lembrado no aparelho.
class SavedCredentials {
  const SavedCredentials({required this.email, required this.password, required this.slug});
  final String email;
  final String password;
  final String slug;
}

/// Onde a senha lembrada fica guardada (cofre do sistema; substituível nos testes).
abstract class CredentialStore {
  Future<String?> readPassword();
  Future<void> writePassword(String password);
  Future<void> deletePassword();
}

class SecureCredentialStore implements CredentialStore {
  static const _key = 'login_password';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> readPassword() => _storage.read(key: _key);

  @override
  Future<void> writePassword(String password) => _storage.write(key: _key, value: password);

  @override
  Future<void> deletePassword() => _storage.delete(key: _key);
}

/// Recurso do Foco Premium sem assinatura ativa (a API responde 402).
class PaymentRequiredException implements Exception {
  PaymentRequiredException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  static const _rememberKey = 'remember_login';
  static const _emailKey = 'login_email';

  CredentialStore credentialStore = SecureCredentialStore();

  static const apiBase = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://academia.focodev.com.br',
  );

  String? token;
  String? academySlug;
  String? deviceId;

  /// ALUNO, INSTRUTOR ou GESTOR (nulo em sessões antigas, até [ensureRole]).
  String? role;

  /// Instrutor ou gestor de academia: o app abre o painel da equipe.
  bool get isStaff => role == 'INSTRUTOR' || role == 'GESTOR';
  Future<bool>? _refreshInFlight;

  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    academySlug = prefs.getString('academy_slug');
    role = prefs.getString('user_role');
    deviceId = prefs.getString('device_id') ?? await _newDeviceId();
    await prefs.setString('device_id', deviceId!);
    return token != null;
  }

  static const _deviceChannel = MethodChannel('com.focodev.academia/device');

  /// Identificador do celular que sobrevive a desinstalar e instalar de novo: a conta
  /// presa a um aparelho continua entrando no mesmo celular depois de reinstalar.
  static Future<String> _newDeviceId() async {
    try {
      final id = await _deviceChannel.invokeMethod<String>('stableDeviceId');
      if (id != null && id.isNotEmpty) return 'android-$id';
    } catch (_) {}
    return const Uuid().v4();
  }

  /// O que a tela do convite mostra (público, sem login).
  Future<Map<String, dynamic>> previewInvite(String code) async {
    final response = await http.get(Uri.parse('$apiBase/api/auth/invites/${Uri.encodeComponent(code)}'));
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Convite não encontrado'));
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Aceita o convite: cria a conta (ou vincula a de aluno avulso) já ligada à academia e entra.
  Future<void> acceptInvite({
    required String code,
    String? name,
    required String email,
    required String password,
    bool remember = true,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBase/api/auth/invites/${Uri.encodeComponent(code)}/accept'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'email': email,
        'password': password,
        'deviceId': deviceId,
        'deviceLabel': 'Flutter Android',
        'appClient': 'MOBILE',
        'appVersion': AppUpdateService.loginAppVersion(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Não foi possível aceitar o convite'));
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    await _startSession(data, data['academySlug'] as String? ?? '', email, password, remember);
  }

  Future<void> _persistRole(Object? user) async {
    final value = user is Map ? user['role'] as String? : null;
    if (value == null || value.isEmpty) return;
    role = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', value);
  }

  /// Sessões abertas antes do perfil existir no app: descobre o papel pela API.
  Future<void> ensureRole() async {
    if (role != null || token == null) return;
    try {
      await _persistRole(await get('/api/auth/me'));
    } catch (_) {
      // Sem rede: continua como aluno até a próxima abertura.
    }
  }

  Future<void> _persistToken(String newToken) async {
    token = newToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', newToken);
  }

  /// Renova o JWT ao abrir o app (aceita token expirado dentro da janela da API).
  ///
  /// Chamadas simultâneas aguardam a mesma renovação: antes, quem chegava
  /// durante um refresh em andamento repetia a requisição com o token antigo
  /// e era deslogado.
  Future<bool> refreshSession() {
    if (token == null || token!.isEmpty) return Future.value(false);
    return _refreshInFlight ??=
        _refreshSessionNow().whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _refreshSessionNow() async {
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
        // Token venceu de vez: entra de novo sozinho com o login lembrado.
        if (await reloginWithSavedCredentials()) return true;
        await logout();
        return false;
      }
      // 403 academia bloqueada etc. — mantém token; usuário verá mensagem na próxima chamada.
      return response.statusCode == 200;
    } catch (_) {
      // Sem rede: mantém token local para tentar depois.
      return token != null;
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
        if (!await reloginWithSavedCredentials()) {
          await logout();
          return false;
        }
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
      // A API responde o heartbeat com 204 (sem corpo). Antes só 200 contava,
      // então a validação online nunca passava e a tela de reconexão travava.
      if (_isSuccess(hb.statusCode)) {
        await OnlineAuthGate.instance.markOnlineAuthSuccess();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Login lembrado (e-mail e código da academia + senha do cofre), se houver.
  Future<SavedCredentials?> savedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_rememberKey) ?? false)) return null;
    final email = prefs.getString(_emailKey) ?? '';
    final slug = prefs.getString('academy_slug') ?? '';
    String? password;
    try {
      password = await credentialStore.readPassword();
    } catch (_) {
      password = null;
    }
    if (email.isEmpty) return null;
    return SavedCredentials(email: email, password: password ?? '', slug: slug);
  }

  Future<void> _rememberCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, true);
    await prefs.setString(_emailKey, email);
    try {
      await credentialStore.writePassword(password);
    } catch (_) {
      // Sem cofre disponível: lembra só o e-mail.
    }
  }

  Future<void> forgetCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberKey);
    await prefs.remove(_emailKey);
    try {
      await credentialStore.deletePassword();
    } catch (_) {}
  }

  /// Entra de novo com o login lembrado, sem o aluno digitar nada.
  Future<bool> reloginWithSavedCredentials() async {
    final saved = await savedCredentials();
    // Código da academia vazio = aluno avulso (conta criada no app).
    if (saved == null || saved.password.isEmpty) return false;
    try {
      await login(saved.email, saved.password, saved.slug, remember: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cria conta de aluno avulso (sem academia) e já entra.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    bool remember = true,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBase/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': 'ALUNO',
        'deviceId': deviceId,
        'deviceLabel': 'Flutter Android',
        'appClient': 'MOBILE',
        'appVersion': AppUpdateService.loginAppVersion(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Não foi possível criar a conta'));
    }
    await _startSession(jsonDecode(response.body) as Map<String, dynamic>, '', email, password, remember);
  }

  /// Cria uma academia (o dono vira gestor) ou um instrutor autônomo, e já entra.
  /// O dono entra depois sem código da academia.
  Future<void> registerBusiness({
    required String type,
    String? academyName,
    required String name,
    required String email,
    required String password,
    bool remember = true,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBase/api/auth/register-business'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': type,
        if (academyName != null && academyName.trim().isNotEmpty) 'academyName': academyName.trim(),
        'name': name,
        'email': email,
        'password': password,
        'deviceId': deviceId,
        'deviceLabel': 'Flutter Android',
        'appClient': 'MOBILE',
        'appVersion': AppUpdateService.loginAppVersion(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Não foi possível criar a conta'));
    }
    await _startSession(jsonDecode(response.body) as Map<String, dynamic>, '', email, password, remember);
  }

  Future<void> _startSession(
    Map<String, dynamic> data,
    String slug,
    String email,
    String password,
    bool remember,
  ) async {
    await _persistToken(data['token'] as String);
    await _persistRole(data['user']);
    academySlug = slug;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('academy_slug', slug);
    await OnlineAuthGate.instance.markOnlineAuthSuccess();
    if (remember) {
      await _rememberCredentials(email, password);
    } else {
      await forgetCredentials();
    }
  }

  Future<void> login(String email, String password, String slug, {bool remember = true}) async {
    final response = await http.post(
      Uri.parse('$apiBase/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        // Aluno avulso entra sem código de academia.
        'academySlug': slug.trim().isEmpty ? null : slug.trim(),
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
    await _startSession(jsonDecode(response.body) as Map<String, dynamic>, slug, email, password, remember);
  }

  Future<void> logout() async {
    token = null;
    role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_role');
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
      if (_isSuccess(response.statusCode)) {
        await OnlineAuthGate.instance.markOnlineAuthSuccess();
      }
    } catch (e) {
      if (e is SessionExpiredException) rethrow;
      // Heartbeat é best-effort.
    }
  }

  static bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

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
    if (response.statusCode == 402) {
      throw PaymentRequiredException(_errorMessage(response, 'Recurso do Foco Premium.'));
    }
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
  Future<void> delete(String path) async {
    final response = await _send(
      () => http.delete(Uri.parse('$apiBase$path'), headers: _headers()),
    );
    if (!_isSuccess(response.statusCode)) {
      throw Exception(_errorMessage(response, 'Erro ${response.statusCode}'));
    }
  }

}
