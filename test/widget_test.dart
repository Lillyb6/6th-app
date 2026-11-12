import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixthapp/main.dart';

import 'social_test_helpers.dart';

void main() {
  for (final size in [
    const Size(320, 480),
    const Size(640, 320),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('Cloud tabs remain usable at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: cloudTheme(),
          home: CloudClubHome(api: TestCloudApi(), name: 'Sky'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Look up, Sky.'), findsOneWidget);
      expect(find.text('Cloud Club'), findsOneWidget);
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.text('Best clouds'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Safe areas protect mobile navigation and the wordmark', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: cloudTheme(),
        home: CloudClubHome(api: TestCloudApi()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Cloud Club')).dy,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getBottomRight(find.text('Profile')).dy,
      lessThanOrEqualTo(844 - 34),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Feed failure offers a retry and leaves navigation usable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: cloudTheme(),
        home: CloudClubHome(api: failingApi()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The sky is offline.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(find.text('Find your cloud'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Large text can scroll through the posting form', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: cloudTheme(),
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.6),
          ),
          child: child!,
        ),
        home: CloudClubHome(api: TestCloudApi()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Post cloud'));
    expect(find.text('Post cloud').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
