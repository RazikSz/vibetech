import 'package:flutter_test/flutter_test.dart';
import 'package:vibetech_xyz/main.dart';

void main() {
  testWidgets('VibeTechApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VibeTechApp());
    expect(find.byType(VibeTechApp), findsOneWidget);
  });
}
