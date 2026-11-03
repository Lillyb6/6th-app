import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixthapp/main.dart';

void main() {
  testWidgets('Content stays reachable after rotating to landscape', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CloudClubHome()));

    tester.view.physicalSize = const Size(640, 320);
    await tester.pumpAndSettle();
    expect(find.text('Cloud Club').hitTestable(), findsOneWidget);
    final finalStep = find.text('Your discoveries');
    await tester.scrollUntilVisible(finalStep, 150);
    await tester.pumpAndSettle();
    expect(finalStep.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Content avoids device cutouts and the bottom system area', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 700);
    tester.view.padding = FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(const MaterialApp(home: CloudClubHome()));

    expect(
      tester.getTopLeft(find.text('Cloud Club')).dy,
      greaterThanOrEqualTo(44),
    );
    final notice = find.text(
      'Entries last for this session and disappear when the app restarts. Photos and AI guesses are coming later.',
    );
    await tester.scrollUntilVisible(notice, 150);
    await tester.pumpAndSettle();
    expect(notice.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(notice).dy, lessThanOrEqualTo(700 - 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cloud Club introduces the cloud spotting flow', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CloudClubHome()));
    expect(find.text('Cloud Club'), findsOneWidget);
    expect(find.text('What do you see?'), findsOneWidget);
    expect(find.text('Record a cloud spotting'), findsOneWidget);
    expect(find.text('A little inspiration'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Your discoveries'), 150);
    expect(find.text('Your discoveries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Starting screen remains readable on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CloudClubHome()));
    expect(tester.takeException(), isNull);

    final notice = find.text(
      'Entries last for this session and disappear when the app restarts. Photos and AI guesses are coming later.',
    );
    await tester.scrollUntilVisible(notice, 150);
    await tester.pumpAndSettle();
    expect(notice.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Starting screen supports enlarged text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CloudClubHome(),
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Your discoveries'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Your discoveries').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cloud Club content is reachable on a small phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CloudClubHome()));

    final comingSoonMessage = find.text(
      'Entries last for this session and disappear when the app restarts. Photos and AI guesses are coming later.',
    );
    await tester.scrollUntilVisible(
      comingSoonMessage,
      150,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(comingSoonMessage.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
