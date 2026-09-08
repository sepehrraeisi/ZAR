import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/repository_phase_a2_app.dart';

void main() {
  testWidgets('repository-backed ZAR+ renders operational shell', (WidgetTester tester) async {
    await tester.pumpWidget(const RepositoryZarPlusApp());
    await tester.pumpAndSettle();

    expect(find.text('ZAR+'), findsOneWidget);
    expect(find.text('خانه'), findsOneWidget);
    expect(find.text('تقویم'), findsOneWidget);
    expect(find.text('اشخاص'), findsOneWidget);
    expect(find.text('سوابق'), findsOneWidget);
    expect(find.text('عقب‌افتاده'), findsOneWidget);
    expect(find.text('رضا محمدی'), findsWidgets);
  });
}
