import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/domain/zar_reminder_plan.dart';
import 'package:flutter_app/features/reminders/reminder_plan_editor.dart';

void main() {
  test('plan helpers avoid duplicate offsets and support custom reminders', () {
    var plan = const ZarReminderPlan();
    plan = plan.withOffset(30).withOffset(30).withOffset(60);

    expect(plan.rules.where((r) => r.minutesBefore == 30), hasLength(1));
    expect(plan.rules.where((r) => r.minutesBefore == 60), hasLength(1));

    final customAt = DateTime.utc(2026, 8, 28, 8, 45);
    plan = plan.withCustom(customAt, id: 'custom-a');
    expect(plan.rules.where((r) => r.id == 'custom-a'), hasLength(1));

    plan = plan.withoutOffset(30).withoutRule('custom-a');
    expect(plan.rules.where((r) => r.minutesBefore == 30), isEmpty);
    expect(plan.rules.where((r) => r.id == 'custom-a'), isEmpty);
  });

  testWidgets('editor can select multiple preset reminders and return plan',
      (tester) async {
    ZarReminderPlan? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa', 'IR'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showModalBottomSheet<ZarReminderPlan>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ReminderPlanEditorSheet(
                      initialPlan: const ZarReminderPlan(),
                      onPickCustomTime: () async => null,
                    ),
                  );
                },
                child: const Text('باز کردن'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();

    expect(find.text('یادآوری‌های این تعهد'), findsOneWidget);
    expect(find.text('۱۵ دقیقه قبل'), findsOneWidget);
    expect(find.text('۱ ساعت قبل'), findsOneWidget);

    final switches = find.byType(SwitchListTile);
    await tester.tap(switches.at(0));
    await tester.pump();
    await tester.tap(switches.at(2));
    await tester.pump();
    await tester.tap(find.text('ذخیره یادآوری‌ها'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(
      result!.rules.map((rule) => rule.minutesBefore).toSet(),
      containsAll(<int?>{15, 60}),
    );
  });

  testWidgets('editor can add and remove a custom reminder', (tester) async {
    final customAt = DateTime.utc(2026, 8, 29, 6, 30);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReminderPlanEditorSheet(
            initialPlan: const ZarReminderPlan(),
            onPickCustomTime: () async => customAt,
          ),
        ),
      ),
    );

    await tester.tap(find.text('افزودن یادآوری سفارشی'));
    await tester.pumpAndSettle();
    expect(find.text('یادآوری سفارشی'), findsOneWidget);

    await tester.tap(find.byTooltip('حذف'));
    await tester.pump();
    expect(find.text('یادآوری سفارشی'), findsNothing);
  });
}
