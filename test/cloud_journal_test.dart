import 'package:sixthapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Reject blank shapes and cancel without adding a spotting', (
    tester,
  ) async {
    await tester.pumpWidget(const CloudClubApp());
    await tester.tap(find.text('Record a cloud spotting'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.ensureVisible(find.text('Add to collection'));
    await tester.tap(find.text('Add to collection'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the shape you see.'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    expect(find.text('A sky full of possibilities'), findsOneWidget);
  });

  testWidgets('Save, browse, delete and restore an observation', (
    tester,
  ) async {
    await tester.pumpWidget(const CloudClubApp());
    await tester.tap(find.text('Record a cloud spotting'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      '  Sleeping dragon  ',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'Above the library',
    );
    await tester.ensureVisible(find.text('Add to collection'));
    await tester.tap(find.text('Add to collection'));
    await tester.pumpAndSettle();
    expect(find.text('Sleeping dragon'), findsOneWidget);
    expect(find.text('Above the library'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('1 cloud spotting recorded this session.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('1 cloud spotting recorded this session.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete spotting'));
    await tester.pumpAndSettle();
    expect(find.text('A sky full of possibilities'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Sleeping dragon'), findsOneWidget);
    expect(find.text('Above the library'), findsOneWidget);
  });
}
