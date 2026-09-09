import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
