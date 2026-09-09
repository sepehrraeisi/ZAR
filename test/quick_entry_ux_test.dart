import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/features/editors/confirmed_quick_add_sheet.dart';
import 'package:flutter_app/features/editors/quick_entry_preferences.dart';

void main() {
  AppPerson person() => AppPerson(id: 'p1', name: 'مهیار');

  Widget host({
    List<ZarCoinType> coinTypes = const [],
    QuickEntryPreferenceStore? preferences,
  }) => MaterialApp(
    home: Scaffold(
      body: ConfirmedQuickAddSheet(
        people: [person()],
        coinTypes: coinTypes,
        preferenceStore: preferences ?? InMemoryQuickEntryPreferenceStore(),
        onSave: (_) async {},
      ),
    ),
  );

  Widget modalHost({
    required Future<void> Function(QuickAddDraft draft) onSave,
    String initialReminder = 'بدون یادآوری',
  }) => MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => ConfirmedQuickAddSheet(
              people: [person()],
              initialReminder: initialReminder,
              preferenceStore: InMemoryQuickEntryPreferenceStore(),
              onSave: onSave,
            ),
          ),
          child: const Text('باز کردن'),
        ),
      ),
    ),
  );

  String metadataSummary(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .firstWhere((value) => value.contains('امروز ·'));

  testWidgets(
    'new Quick Entry has an automatic transaction timestamp independent of reminder',
    (tester) async {
      QuickAddDraft? saved;
      await tester.pumpWidget(
        modalHost(onSave: (draft) async => saved = draft),
      );
      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('خرید'));
      await tester.pump();
      await tester.tap(find.text('طلا'));
      await tester.pump();

      final summary = metadataSummary(tester);
      expect(summary, contains('بدون یادآوری'));
      expect(summary, isNot(contains('بدون ساعت')));
      expect(summary, matches(RegExp(r'امروز · [۰-۹]{2}:[۰-۹]{2} ·')));

      await tester.tap(find.text('انتخاب طرف حساب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مهیار'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '۱');
      await tester.enterText(find.byType(TextField).at(1), '۱۰۰۰');
      await tester.pump();
      await tester.tap(find.text('ثبت خرید طلا').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأیید و ثبت'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.time, isNotNull);
      final today = Jalali.fromDateTime(DateTime.now());
      expect(saved!.date.year, today.year);
      expect(saved!.date.month, today.month);
      expect(saved!.date.day, today.day);
      expect(saved!.reminder, isEmpty);
    },
  );

  testWidgets('selecting a reminder does not change transaction time', (
    tester,
  ) async {
    await tester.pumpWidget(modalHost(onSave: (_) async {}));
    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دریافت'));
    await tester.pump();
    await tester.tap(find.text('ارز'));
    await tester.pump();
    await tester.tap(find.text('ویرایش'));
    await tester.pump();

    final timeTile = find.ancestor(
      of: find.text('ساعت ثبت'),
      matching: find.byType(ListTile),
    );
    final timeBefore = tester
        .widgetList<Text>(
          find.descendant(of: timeTile, matching: find.byType(Text)),
        )
        .map((widget) => widget.data ?? '')
        .last;
    final reminderTile = find.ancestor(
      of: find.text('بدون یادآوری'),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(reminderTile);
    await tester.pumpAndSettle();
    await tester.tap(reminderTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('۳۰ دقیقه'));
    await tester.pumpAndSettle();

    final timeAfter = tester
        .widgetList<Text>(
          find.descendant(of: timeTile, matching: find.byType(Text)),
        )
        .map((widget) => widget.data ?? '')
        .last;
    expect(timeAfter, timeBefore);
  });

  testWidgets(
    'changing selection preserves the selected context and common fields',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('خرید'));
      await tester.pump();
      await tester.tap(find.text('طلا'));
      await tester.pump();
      await tester.tap(find.text('تغییر'));
      await tester.pump();
      await tester.tap(find.text('طلا'));
      await tester.pump();
      expect(find.text('خرید · طلا'), findsOneWidget);
    },
  );

  testWidgets(
    'selection collapses into a compact context and CTA remains visible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host());
      await tester.tap(find.text('خرید'));
      await tester.pump();
      await tester.tap(find.text('طلا'));
      await tester.pump();

      expect(find.text('خرید · طلا'), findsOneWidget);
      expect(find.text('تغییر'), findsOneWidget);
      expect(find.text('ثبت خرید طلا'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gold total updates from exact input without a manual total field',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('خرید'));
      await tester.pump();
      await tester.tap(find.text('طلا'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '۲۵۰');
      await tester.enterText(find.byType(TextField).at(1), '۵۰۰۰۰۰۰۰');
      await tester.pump();

      expect(find.textContaining('مبلغ کل:'), findsOneWidget);
      expect(find.text('مبلغ کل (تومان)'), findsNothing);
    },
  );

  testWidgets('currency settlement hides valuation until explicitly enabled', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('دریافت'));
    await tester.pump();
    await tester.tap(find.text('ارز'));
    await tester.pump();

    expect(find.text('محاسبه ارزش مالی'), findsOneWidget);
    expect(find.text('نرخ هر واحد ارز (تومان)'), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(find.text('نرخ هر واحد ارز (تومان)'), findsOneWidget);
  });

  testWidgets('coin rows use Persian coin labels and live total', (
    tester,
  ) async {
    final now = DateTime.utc(2026);
    final coin = ZarCoinType(
      id: 'emami',
      name: 'سکه امامی',
      category: ZarCoinCategory.official,
      defaultPricingMethod: ZarCoinPricingMethod.perPiece,
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(host(coinTypes: [coin]));
    await tester.tap(find.text('خرید'));
    await tester.pump();
    await tester.tap(find.text('سکه'));
    await tester.pump();
    expect(find.text('سکه ۱'), findsOneWidget);
    expect(find.text('هر قطعه'), findsNothing);
    await tester.tap(find.text('افزودن سکه دیگر'));
    await tester.pump();
    expect(find.text('سکه ۲'), findsOneWidget);
  });

  test(
    'remembered Quick Entry choices never include sensitive transaction values',
    () async {
      final store = InMemoryQuickEntryPreferenceStore();
      await store.save(
        const QuickEntryPreferences(currencyCode: 'EUR', goldPurity: '999.9'),
      );
      final value = await store.load();
      expect(value.currencyCode, 'EUR');
      expect(value.goldPurity, '999.9');
    },
  );
}
