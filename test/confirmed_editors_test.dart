import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/features/editors/confirmed_editors.dart';

void main() {
  testWidgets('person editor stays open when persistence fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmedPersonEditorSheet(
            onSave: (_) async => throw Exception('offline'),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'علی رضایی');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(find.text('افزودن شخص'), findsOneWidget);
    expect(find.text('اطلاعات ثبت نشد. دوباره تلاش کنید.'), findsOneWidget);
    expect(find.text('ذخیره'), findsOneWidget);
  });

  testWidgets('person editor dismisses only after successful persistence', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showModalBottomSheet<AppPerson>(
                context: context,
                builder: (_) => ConfirmedPersonEditorSheet(
                  onSave: (_) async => saved = true,
                ),
              ),
              child: const Text('باز کردن'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'رضا محمدی');
    final saveButton = find.text('ذخیره');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(find.text('افزودن شخص'), findsNothing);
  });

  testWidgets('record editor keeps record sheet available after failed save', (
    tester,
  ) async {
    final record = AppRecord(
      id: 's1',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p1',
      amountDisplay: r'$10,000',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali(1405, 6, 5),
      time: const TimeOfDay(hour: 11, minute: 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmedRecordEditorSheet(
            record: record,
            personName: 'علی رضایی',
            onSave: (_) async => throw Exception('write failed'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(find.text('ویرایش تعهد'), findsOneWidget);
    expect(find.text('اطلاعات ثبت نشد. دوباره تلاش کنید.'), findsOneWidget);
  });
}
