import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sixthapp/auth_api.dart';

void main() {
  Map<String, Object> validSession() => {
    'token': 'session-token',
    'user': {'name': 'Sky'},
    'expires_at':
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000,
  };

  Future<LoginSession> login(AuthApi api) => api.authenticate(
    signup: false,
    email: 'sky@example.com',
    password: 'test-password-123',
    name: 'Sky',
  );

  AuthApi apiWith(http.Client client) {
    final api = AuthApi(client: client, baseUrl: 'https://api.example.com///');
    addTearDown(api.close);
    return api;
  }

  test(
    'Login uses the configured server and omits signup-only fields',
    () async {
      final api = apiWith(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.example.com/auth/login');
          expect(request.headers['Content-Type'], 'application/json');
          expect(jsonDecode(request.body), {
            'email': 'sky@example.com',
            'password': 'test-password-123',
          });
          return http.Response(jsonEncode(validSession()), 200);
        }),
      );

      final session = await login(api);
      expect(session.token, 'session-token');
      expect(session.name, 'Sky');
      expect(session.expiresAt.isAfter(DateTime.now()), isTrue);
    },
  );

  for (final invalid in ['missing user', 'empty token', 'expired token']) {
    test('Rejects a successful response with $invalid', () async {
      final payload = validSession();
      switch (invalid) {
        case 'missing user':
          payload.remove('user');
        case 'empty token':
          payload['token'] = '';
        case 'expired token':
          payload['expires_at'] = 1;
      }
      final api = apiWith(
        MockClient((_) async => http.Response(jsonEncode(payload), 200)),
      );

      await expectLater(
        login(api),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            'The server returned an invalid login response.',
          ),
        ),
      );
    });
  }

  test('Preserves an actionable server error', () async {
    final api = apiWith(
      MockClient(
        (_) async => http.Response(
          '{"error":"Too many attempts. Try again in a minute."}',
          429,
        ),
      ),
    );
    await expectLater(
      login(api),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Too many attempts. Try again in a minute.',
        ),
      ),
    );
  });

  test('Timeout reports a retryable error', () async {
    final api = apiWith(
      MockClient((_) async => throw TimeoutException('test')),
    );
    await expectLater(
      login(api),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'The server took too long. Please try again.',
        ),
      ),
    );
  });

  test('A failed connection can be retried successfully', () async {
    var calls = 0;
    final api = apiWith(
      MockClient((_) async {
        if (++calls == 1) throw http.ClientException('Offline');
        return http.Response(jsonEncode(validSession()), 200);
      }),
    );
    await expectLater(login(api), throwsA(isA<AuthException>()));
    expect((await login(api)).token, 'session-token');
    expect(calls, 2);
  });

  test(
    'Logout sends the token and accepts an already expired session',
    () async {
      final api = apiWith(
        MockClient((request) async {
          expect(request.url.path, '/auth/logout');
          expect(request.headers['Authorization'], 'Bearer expired-token');
          expect(jsonDecode(request.body), isEmpty);
          return http.Response('{"error":"Session expired."}', 401);
        }),
      );
      await expectLater(api.logout('expired-token'), completes);
    },
  );
}
