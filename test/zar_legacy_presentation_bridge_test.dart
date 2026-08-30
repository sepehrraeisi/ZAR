import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/application/zar_legacy_presentation_bridge.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';

void main() {
  const bridge = ZarLegacyPresentationBridge(businessId: 'b1', userId: 'u1');
  final now = DateTime.utc(2026, 8, 27, 10);

  test('currency settlement round-trips without losing exact cents', () {
    final record = AppRecord(
      id: 's1',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p1',
      amountDisplay: r'$10,000.50',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali(1405, 6, 5),
      time: const TimeOfDay(hour: 11, minute: 30),
    );

    final domain = bridge.settlementFromUi(record, now: now);
    final amount = (domain.amount as ZarCurrencyAssetAmount).value;
    expect(amount.code, 'USD');
    expect(amount.minorUnits, 1000050);
    expect(amount.minorUnitScale, 2);

    final ui = bridge.settlementToUi(domain);
    expect(ui.currencyCode, 'USD');
    expect(ui.type, RecordType.settlement);
    expect(ui.operationLabel, 'تحویل');
  });

  test('gold quantity uses decimal-safe normalized representation', () {
    final record = AppRecord(
      id: 's2',
      type: RecordType.settlement,
      operationLabel: 'دریافت',
      personId: 'p1',
      amountDisplay: '۲۵۰٫۱۲۵',
      assetLabel: 'گرم طلا',
      date: Jalali(1405, 6, 5),
    );

    final domain = bridge.settlementFromUi(record, now: now);
    final amount = (domain.amount as ZarGoldAssetAmount).value;
    expect(amount.decimal, '250.125');
    expect(domain.hasTime, isFalse);
  });

  test('mithqal deal keeps canonical grams and market display values', () {
    final pricing = ZarGoldDealPricing.calculate(
      fineness: 750,
      inputWeight: '10',
      inputWeightUnit: ZarGoldUnit.mesghal,
      priceUnit: ZarGoldUnit.mesghal,
      pricePerUnitToman: ZarTomanAmount(35000000),
    );
    final deal = ZarDeal(
      id: 'd1',
      businessId: 'b1',
      type: ZarDealType.buy,
      personId: 'p1',
      amount: ZarGoldAssetAmount(
        ZarGoldQuantity(
          decimal: pricing.normalizedWeightGrams,
          unit: ZarGoldUnit.gram,
          purity: '750',
        ),
      ),
      pricing: pricing,
      dealAt: now,
      createdBy: 'u1',
      createdAt: now,
      updatedAt: now,
    );

    final record = bridge.dealToUi(deal);
    expect(record.amountDisplay, '۴۶.۰۸۳');
    expect(record.goldInputWeight, '10');
    expect(record.goldInputUnit, 'mesghal');
    expect(record.goldEquivalentWeight, '46.083');
    expect(record.goldPriceUnit, 'mesghal');
    expect(record.goldEquivalentPrice, '7594991.64550919');
  });

  test('completion transition sets completion metadata', () {
    final record = AppRecord(
      id: 's3',
      type: RecordType.settlement,
      operationLabel: 'دریافت',
      personId: 'p1',
      amountDisplay: '۱۰۰',
      assetLabel: 'گرم طلا',
      date: Jalali(1405, 6, 5),
      status: SettlementStatus.completed,
    );

    final domain = bridge.settlementFromUi(record, now: now);
    expect(domain.status, ZarSettlementStatus.completed);
    expect(domain.completedAt, now);
    expect(domain.completedBy, 'u1');
  });

  test('person archive state maps both directions', () {
    final ui = AppPerson(
      id: 'p1',
      name: 'علی رضایی',
      phone: '09121234567',
      archived: true,
    );
    final domain = bridge.personFromUi(ui, now: now);
    expect(domain.archived, isTrue);
    expect(domain.displayName, 'علی رضایی');

    final mapped = bridge.personToUi(domain);
    expect(mapped.archived, isTrue);
    expect(mapped.phone, '09121234567');
  });
}
