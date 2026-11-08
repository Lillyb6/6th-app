import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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

  LoginSession? get restoredSession => null;

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

/// Supabase Auth adapter used by the hosted app. The HTTP AuthApi remains
/// available for local development and widget tests.
class SupabaseAuthApi extends AuthApi {
  SupabaseAuthApi();

  sb.SupabaseClient get _supabase => sb.Supabase.instance.client;

  LoginSession? _fromSession(sb.Session? session) {
    if (session == null || session.expiresAt == null) return null;
    return LoginSession(
      session.accessToken,
      session.user.userMetadata?['name'] as String? ??
          session.user.email?.split('@').first ??
          'Cloud watcher',
      DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000),
    );
  }

  @override
  LoginSession? get restoredSession =>
      _fromSession(_supabase.auth.currentSession);

  @override
  Future<LoginSession> authenticate({
    required bool signup,
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = signup
          ? await _supabase.auth.signUp(
              email: email,
              password: password,
              data: {'name': name},
            )
          : await _supabase.auth.signInWithPassword(
              email: email,
              password: password,
            );
      final session = _fromSession(response.session);
      if (session == null) {
        throw const AuthException(
          'Check your email to confirm your account, then log in.',
        );
      }
      return session;
    } on AuthException {
      rethrow;
    } on sb.AuthException catch (error) {
      throw AuthException(error.message);
    } catch (_) {
      throw const AuthException(
        'Cannot reach Cloud Club. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> logout(String token) async {
    try {
      await _supabase.auth.signOut();
    } on sb.AuthException catch (error) {
      throw AuthException(error.message);
    } catch (_) {
      throw const AuthException('Could not log out. Please try again.');
    }
  }

  @override
  void close() {}
}
