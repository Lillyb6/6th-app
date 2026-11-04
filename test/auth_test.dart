import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sixthapp/auth_api.dart';
import 'package:sixthapp/main.dart';

import 'social_test_helpers.dart';

void main() {
  Future<void> fillLogin(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'sky@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'rainbow-cloud-123',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
  }

  String sessionResponse() => jsonEncode({
    'token': 'server-issued-session',
    'user': {'id': 1, 'name': 'Sky', 'email': 'sky@example.com'},
    'expires_at':
        DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/
        1000,
  });

  testWidgets('Login gates the community and logout returns to login', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/auth/logout') {
          expect(
            request.headers['Authorization'],
            'Bearer server-issued-session',
          );
          return http.Response('{}', 200);
        }
        return http.Response(sessionResponse(), 200);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      CloudClubApp(authApi: api, cloudApiBuilder: (_) => TestCloudApi()),
    );
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Look up, Sky.'), findsNothing);
    await fillLogin(tester);
    expect(find.text('Look up, Sky.'), findsOneWidget);
    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Look up, Sky.'), findsNothing);
  });

  testWidgets('Invalid credentials cannot open the journal', (tester) async {
    final api = AuthApi(
      client: MockClient(
        (_) async =>
            http.Response('{"error":"Incorrect email or password."}', 401),
      ),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      CloudClubApp(authApi: api, cloudApiBuilder: (_) => TestCloudApi()),
    );
    await fillLogin(tester);
    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('Look up, Sky.'), findsNothing);
  });

  testWidgets('Signup checks confirmation and submits real account fields', (
    tester,
  ) async {
    var calls = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/auth/signup');
        expect(jsonDecode(request.body), {
          'name': 'Sky',
          'email': 'sky@example.com',
          'password': 'rainbow-cloud-123',
        });
        return http.Response(sessionResponse(), 201);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      CloudClubApp(authApi: api, cloudApiBuilder: (_) => TestCloudApi()),
    );
    await tester.ensureVisible(find.text('New here? Create an account'));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sky');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'sky@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'rainbow-cloud-123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'different',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Create account'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'rainbow-cloud-123',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Create account'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Look up, Sky.'), findsOneWidget);
  });

  testWidgets('Network errors leave login available for retry', (tester) async {
    final api = AuthApi(
      client: MockClient((_) async => throw http.ClientException('Offline')),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      CloudClubApp(authApi: api, cloudApiBuilder: (_) => TestCloudApi()),
    );
    await fillLogin(tester);
    expect(
      find.text(
        'Cannot reach Cloud Club. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(find.text('Look up, Sky.'), findsNothing);
  });
}
