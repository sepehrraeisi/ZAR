import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/history/operational_history_screen.dart';
import 'package:flutter_app/features/people/operational_people_screen.dart';
import 'package:flutter_app/features/reports/operational_daily_report_screen.dart';
import 'package:flutter_app/repository_phase_a2_app_v2.dart';

void main() {
  testWidgets('settlement action exposes persistent reminder management', (
    tester,
  ) async {
    await tester.pumpWidget(const RepositoryZarPlusAppV2());
    await tester.pumpAndSettle();

    expect(find.text('خانه'), findsWidgets);

    // Preview data includes an open delivery for رضا محمدی.
    await tester.tap(find.text('رضا محمدی').first);
    await tester.pumpAndSettle();

    expect(find.text('یادآوری‌ها'), findsOneWidget);
    await tester.tap(find.text('یادآوری‌ها'));
    await tester.pumpAndSettle();

    expect(find.text('یادآوری‌های این تعهد'), findsOneWidget);
    expect(find.text('۱۵ دقیقه قبل'), findsOneWidget);
    expect(find.text('۱ ساعت قبل'), findsOneWidget);
  });

  testWidgets('people add flow uses confirmed persistence editor', (
    tester,
  ) async {
    await tester.pumpWidget(const RepositoryZarPlusAppV2());
    await tester.pumpAndSettle();

    await tester.tap(find.text('اشخاص').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('افزودن'));
    await tester.pumpAndSettle();

    final addPerson = find.text('افزودن شخص');
    expect(addPerson, findsOneWidget);
  });

  testWidgets('production shell wires modern report history and people screens', (tester) async {
    await tester.pumpWidget(const RepositoryZarPlusAppV2());
    await tester.pumpAndSettle();

    await tester.tap(find.text('گزارش روزانه'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationalDailyReportScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(OperationalDailyReportScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('اشخاص').last);
    await tester.pumpAndSettle();
    expect(find.byType(OperationalPeopleScreen), findsOneWidget);

    await tester.tap(find.text('سوابق').last);
    await tester.pumpAndSettle();
    expect(find.byType(OperationalHistoryScreen), findsOneWidget);
  });
}
