import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixthapp/main.dart';

import 'social_test_helpers.dart';

void main() {
  testWidgets('Upload completion after leaving home does not update disposed UI', (
    tester,
  ) async {
    final api = PendingUploadApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: cloudTheme(),
        home: CloudClubHome(api: api, photoPicker: () async => testPhoto),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find your cloud'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'A sleeping dragon');
    await tester.ensureVisible(find.text('Post cloud'));
    await tester.tap(find.text('Post cloud'));
    await tester.pump();
    expect(api.uploadStarted, isTrue);
    final callsBeforeLeaving = api.calls.length;

    // Removing home reproduces the auth gate disposing it on logout.
    await tester.pumpWidget(const MaterialApp(home: Text('Logged out')));
    api.upload.complete({'id': 1});
    await tester.pumpAndSettle();

    expect(find.text('Logged out'), findsOneWidget);
    expect(api.calls.length, callsBeforeLeaving);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Choose a photo, post it, like it and find it in best clouds', (
    tester,
  ) async {
    final api = TestCloudApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: cloudTheme(),
        home: CloudClubHome(
          api: api,
          name: 'Sky',
          photoPicker: () async => testPhoto,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find your cloud'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'A sleeping dragon');
    await tester.ensureVisible(find.text('Post cloud'));
    await tester.tap(find.text('Post cloud'));
    await tester.pumpAndSettle();
    expect(api.posts.single['caption'], 'A sleeping dragon');
    expect(find.text('A sleeping dragon'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Like cloud'));
    await tester.tap(find.byTooltip('Like cloud'));
    await tester.pumpAndSettle();
    expect(find.text('1 like'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Best clouds'), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Posting requires a photo and caption; cancelling picker keeps draft',
    (tester) async {
      final api = TestCloudApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: cloudTheme(),
          home: CloudClubHome(api: api, photoPicker: () async => null),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Post cloud'));
      await tester.tap(find.text('Post cloud'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a cloud photo first.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Keep this draft');
      await tester.ensureVisible(find.text('Find your cloud'));
      await tester.tap(find.text('Find your cloud'));
      await tester.pumpAndSettle();
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(api.posts, isEmpty);
    },
  );
  testWidgets('Profile name and bio save through the API', (tester) async {
    final api = TestCloudApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: cloudTheme(),
        home: CloudClubHome(api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Sky Blue');
    await tester.enterText(find.byType(TextField).last, 'Always looking up.');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(api.profile['bio'], 'Always looking up.');
    expect(find.text('Always looking up.'), findsOneWidget);
    expect(find.text('Sky Blue'), findsOneWidget);
  });
}

class PendingUploadApi extends TestCloudApi {
  final upload = Completer<Map<String, dynamic>>();
  bool uploadStarted = false;

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? data,
  }) {
    if (path == '/posts') {
      uploadStarted = true;
      return upload.future;
    }
    return super.request(path, data: data);
  }
}
