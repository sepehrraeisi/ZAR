import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/features/coins/coin_catalog_screen.dart';
import 'package:flutter_app/features/currencies/currency_catalog_screen.dart';

void main() {
  final now = DateTime.utc(2026);

  testWidgets('coin catalog shows active count and isolates archived types', (
    tester,
  ) async {
    final active = ZarCoinType(
      id: 'coin-active',
      name: 'سکه فعال',
      category: ZarCoinCategory.official,
      defaultPricingMethod: ZarCoinPricingMethod.perPiece,
      createdAt: now,
      updatedAt: now,
    );
    final archived = active.copyWith(
      name: 'سکه بایگانی',
      archived: true,
      updatedAt: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: CoinCatalogScreen(
            types: [active, archived],
            onSave: (_) async {},
            onArchive: (_) async {},
            onRestore: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('۱ نوع فعال'), findsOneWidget);
    expect(find.text('سکه فعال'), findsOneWidget);
    expect(find.text('سکه بایگانی'), findsNothing);
    expect(find.text('بایگانی‌شده‌ها (۱)'), findsOneWidget);
  });

  testWidgets('currency catalog keeps codes LTR and exposes add action', (
    tester,
  ) async {
    final usd = ZarCurrencyType(
      id: 'currency-usd',
      name: 'دلار آمریکا',
      code: 'usd',
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: CurrencyCatalogScreen(
            types: [usd],
            onSave: (_) async {},
            onArchive: (_) async {},
            onRestore: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('۱ ارز فعال'), findsOneWidget);
    expect(find.text('دلار آمریکا'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('افزودن ارز'), findsOneWidget);
  });
}
