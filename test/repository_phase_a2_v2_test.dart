import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/repository_phase_a2_app_v2.dart';

void main() {
  testWidgets('settlement action exposes persistent reminder management',
      (tester) async {
    await tester.pumpWidget(const RepositoryZarPlusAppV2());
    await tester.pumpAndSettle();

    expect(find.text('خانه'), findsWidgets);

    // Preview data includes an open delivery for رضا محمدی.
    await tester.tap(find.text('رضا محمدی').first);
    await tester.pumpAndSettle();

    expect(find.text('مدیریت یادآوری‌ها'), findsOneWidget);
    await tester.tap(find.text('مدیریت یادآوری‌ها'));
    await tester.pumpAndSettle();

    expect(find.text('یادآوری‌های این تعهد'), findsOneWidget);
    expect(find.text('۱۵ دقیقه قبل'), findsOneWidget);
    expect(find.text('۱ ساعت قبل'), findsOneWidget);
  });

  testWidgets('people add flow uses confirmed persistence editor',
      (tester) async {
    await tester.pumpWidget(const RepositoryZarPlusAppV2());
    await tester.pumpAndSettle();

    await tester.tap(find.text('اشخاص').last);
    await tester.pumpAndSettle();

    final addPerson = find.text('افزودن شخص');
    expect(addPerson, findsWidgets);
  });
}
