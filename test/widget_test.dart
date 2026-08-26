import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('ZAR+ renders home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ZarPlusApp());

    expect(find.text('ZAR+'), findsOneWidget);
    expect(find.text('خانه'), findsOneWidget);
    expect(find.text('تقویم'), findsOneWidget);
    expect(find.text('اشخاص'), findsOneWidget);
  });
}
