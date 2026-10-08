import 'package:flutter_test/flutter_test.dart';
import 'package:urban_farming_ai/main.dart';

void main() {
  testWidgets('Urban Farming AI app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const UrbanFarmingAI());

    expect(find.text('Urban Farming AI'), findsOneWidget);
  });
}
