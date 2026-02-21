
import 'package:flutter_test/flutter_test.dart';

import 'package:soilsafe/main.dart';

void main() {
  testWidgets('App launches and shows title', (WidgetTester tester) async {

    await tester.pumpWidget(const SoilSafeApp());

    expect(find.text('SoilSafe'), findsOneWidget);
  });
}
