import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
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

  testWidgets('coin catalog surfaces stale conflict with reload action', (
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
    var reloads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: CoinCatalogScreen(
            types: [active],
            onSave: (_) async =>
                throw const ZarCloudWriteConflictException.staleRevision(
                  collection: 'zar_coin_types',
                  recordId: 'coin-active',
                  currentRevision: 2,
                ),
            onArchive: (_) async {},
            onRestore: (_) async {},
            onReload: () async {
              reloads += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('سکه فعال'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(find.textContaining('همین حساب'), findsOneWidget);
    expect(find.text('تازه‌سازی'), findsOneWidget);
    await tester.tap(find.text('تازه‌سازی'));
    await tester.pumpAndSettle();
    expect(reloads, 1);
    expect(find.textContaining('اطلاعات از سرور تازه شد'), findsOneWidget);
  });
}
