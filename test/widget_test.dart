import 'package:flutter_test/flutter_test.dart';
import 'package:softcore/main.dart';

void main() {
  testWidgets('Softcore smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SoftcoreApp());
    expect(find.text('softcore'), findsOneWidget);
    // Allow any initial background initialization tasks to settle
    await tester.pump(const Duration(seconds: 10));
  });
}
