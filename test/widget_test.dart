import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixthapp/main.dart';

void main() {
  testWidgets('Cloud Club introduces the cloud spotting flow', (tester) async {
    await tester.pumpWidget(const CloudClubApp());
    expect(find.text('Cloud Club'), findsOneWidget);
    expect(find.text('What do you see?'), findsOneWidget);
    expect(find.text('1. Capture or upload a cloud'), findsOneWidget);
    expect(
      find.text('2. Guess its shape and reveal the AI suggestion'),
      findsOneWidget,
    );
    expect(find.text('3. Share and compare with friends'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Starting screen remains readable on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CloudClubApp());
    expect(tester.takeException(), isNull);

    final notice = find.text(
      'Photo capture and AI interpretations are coming next. This is the Cloud Club starting screen.',
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

    await tester.scrollUntilVisible(
      find.text('3. Share and compare with friends'),
      200,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('3. Share and compare with friends').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cloud Club content is reachable on a small phone screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CloudClubApp());

    final comingSoonMessage = find.text(
      'Photo capture and AI interpretations are coming next. This is the Cloud Club starting screen.',
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
