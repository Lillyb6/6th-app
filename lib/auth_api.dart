import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

class LoginSession {
  const LoginSession(this.token, this.name, this.expiresAt);
  final String token;
  final String name;
  final DateTime expiresAt;
}

class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://127.0.0.1:8000',
          );

  final http.Client _client;
  final String _baseUrl;

  Future<LoginSession> authenticate({
    required bool signup,
    required String email,
    required String password,
    required String name,
  }) async {
    final data = await _post(signup ? '/auth/signup' : '/auth/login', {
      'email': email,
      'password': password,
      if (signup) 'name': name,
    });
    try {
      final user = data['user'] as Map<String, dynamic>;
      final token = data['token'] as String;
      final expires = DateTime.fromMillisecondsSinceEpoch(
        (data['expires_at'] as int) * 1000,
      );
      if (token.isEmpty || !expires.isAfter(DateTime.now())) {
        throw const FormatException();
      }
      return LoginSession(token, user['name'] as String, expires);
    } catch (_) {
      throw const AuthException(
        'The server returned an invalid login response.',
      );
    }
  }

  Future<void> logout(String token) async {
    await _post('/auth/logout', {}, token: token, allowExpired: true);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
    bool allowExpired = false,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (allowExpired && response.statusCode == 401) return {};
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          data['error'] is String
              ? data['error'] as String
              : 'Unable to sign in. Please try again.',
        );
      }
      return data;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException('The server took too long. Please try again.');
    } catch (_) {
      throw const AuthException(
        'Cannot reach Cloud Club. Check your connection and try again.',
      );
    }
  }

  void close() => _client.close();
}
