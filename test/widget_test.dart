import 'package:flutter_test/flutter_test.dart';
import 'package:sixthapp/main.dart';

void main() {
  testWidgets('Cloud Club introduces the cloud spotting flow', (tester) async {
    await tester.pumpWidget(const CloudClubApp());
    expect(find.text('Cloud Club'), findsOneWidget);
    expect(find.text('What do you see?'), findsOneWidget);
    expect(find.text('1. Capture or upload a cloud'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
