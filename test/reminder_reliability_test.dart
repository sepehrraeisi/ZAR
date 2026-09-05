import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/features/editors/confirmed_quick_add_sheet.dart';
import 'package:flutter_app/features/reminders/reminder_model.dart';
import 'package:flutter_app/main_phase_a2.dart';

void main() {
  test('snooze presets use the actual time and roll into the next day', () {
    final now = DateTime(2026, 8, 29, 23, 50);

    expect(snoozePresetDateTime('۱۵ دقیقه', now), DateTime(2026, 8, 30, 0, 5));
    expect(snoozePresetDateTime('۳۰ دقیقه', now), DateTime(2026, 8, 30, 0, 20));
    expect(snoozePresetDateTime('۱ ساعت', now), DateTime(2026, 8, 30, 0, 50));
    expect(snoozePresetDateTime('۳ ساعت', now), DateTime(2026, 8, 30, 2, 50));
    expect(snoozePresetDateTime('۱ روز', now), DateTime(2026, 8, 30, 23, 50));
    expect(snoozePresetDateTime('فردا', now), DateTime(2026, 8, 30, 9));
    expect(
      snoozePresetDateTime(
        'فردا',
        now,
        tomorrowTime: const TimeOfDay(hour: 14, minute: 20),
      ),
      DateTime(2026, 8, 30, 14, 20),
    );
    expect(snoozePresetDateTime('سفارشی', now), isNull);
  });

  testWidgets('Quick Add starts with the configured reminder preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmedQuickAddSheet(
            people: [AppPerson(id: 'p1', name: 'رضا')],
            initialReminder: reminderPresetLabel(180),
            onSave: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('دریافت'));
    await tester.pump();
    await tester.tap(find.text('طلا'));
    await tester.pump();

    expect(find.text('۳ ساعت'), findsOneWidget);
  });

  testWidgets('snooze picker marks the configured default selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await showReminderPickerBottomSheet(
                context,
                initialDate: Jalali(1405, 6, 7),
                initialTime: const TimeOfDay(hour: 9, minute: 0),
                initialSelection: reminderPresetLabel(180),
              );
            },
            child: const Text('اسنوز'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('اسنوز'));
    await tester.pumpAndSettle();

    final selectedTile = find.ancestor(
      of: find.text('۳ ساعت'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: selectedTile, matching: find.byType(Icon)),
      findsOneWidget,
    );
  });

  testWidgets('same-day settlement moves to overdue after its due time', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 29, 10, 1);
    final jalali = Jalali.fromDateTime(now);
    final record = AppRecord(
      id: 's1',
      type: RecordType.settlement,
      operationLabel: 'دریافت',
      personId: 'p1',
      amountDisplay: '100',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: jalali,
      time: const TimeOfDay(hour: 10, minute: 0),
    );

    expect(isRecordOverdueAt(record, now), isTrue);
    expect(isRecordOverdueAt(record, DateTime(2026, 8, 29, 10)), isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhaseA2HomeScreen(
            records: [record],
            personName: (_) => 'رضا',
            onTapRecord: (_) {},
            onOpenNotifications: () {},
            unreadCount: 1,
            now: now,
          ),
        ),
      ),
    );

    final rows = tester.widgetList<SettlementRow>(find.byType(SettlementRow));
    expect(rows, hasLength(1));
    expect(rows.single.showOverdueTone, isTrue);
  });
}
