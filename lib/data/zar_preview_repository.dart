import 'package:shamsi_date/shamsi_date.dart';

import '../domain/zar_domain_models.dart';
import 'zar_domain_repository.dart';

/// Deterministic preview data is stored as production domain objects so the
/// default app exercises the same repository path that Firestore will use.
ZarDomainRepository buildPhaseA2PreviewRepository() {
  final now = DateTime.now();
  final today = Jalali.fromDateTime(now);
  DateTime at(Jalali date, int hour, [int minute = 0]) {
    final g = date.toGregorian();
    return DateTime(g.year, g.month, g.day, hour, minute).toUtc();
  }

  final created = now.subtract(const Duration(days: 90)).toUtc();
  final people = [
    ZarPerson(
      id: 'p1',
      displayName: 'علی رضایی',
      phone: '۰۹۱۲۱۲۳۴۵۶۷',
      note: 'مشتری ثابت',
      createdAt: created,
      updatedAt: created,
      createdBy: 'preview-user',
    ),
    ZarPerson(
      id: 'p2',
      displayName: 'رضا محمدی',
      phone: '۰۹۱۲۴۴۴۵۵۶۶',
      createdAt: created,
      updatedAt: created,
      createdBy: 'preview-user',
    ),
    ZarPerson(
      id: 'p3',
      displayName: 'حسن کریمی',
      phone: '۰۹۱۲۳۳۳۴۴۵۵',
      createdAt: created,
      updatedAt: created,
      createdBy: 'preview-user',
    ),
    ZarPerson(
      id: 'p4',
      displayName: 'مهدی احمدی',
      note: 'ترجیح تماس بعدازظهر',
      createdAt: created,
      updatedAt: created,
      createdBy: 'preview-user',
    ),
    ZarPerson(
      id: 'p5',
      displayName: 'کامران حسینی',
      phone: '۰۹۱۲۹۹۹۸۸۷۷',
      archived: true,
      createdAt: created,
      updatedAt: created,
      createdBy: 'preview-user',
    ),
  ];

  ZarCurrencyAssetAmount usd(String amount) => ZarCurrencyAssetAmount(
    ZarCurrencyAmount(code: 'USD', minorUnits: int.parse(amount) * 100),
  );

  final settlements = [
    ZarSettlement(
      id: 's1',
      businessId: 'preview-business',
      personId: 'p2',
      direction: ZarSettlementDirection.deliver,
      amount: usd('10000'),
      scheduledAt: at(today.addDays(-1), 11),
      hasTime: true,
      createdBy: 'preview-user',
      createdAt: created,
      updatedAt: created,
    ),
    ZarSettlement(
      id: 's2',
      businessId: 'preview-business',
      personId: 'p1',
      direction: ZarSettlementDirection.receive,
      amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '250')),
      scheduledAt: at(today, 10, 30),
      hasTime: true,
      createdBy: 'preview-user',
      createdAt: created,
      updatedAt: created,
    ),
    ZarSettlement(
      id: 's3',
      businessId: 'preview-business',
      personId: 'p3',
      direction: ZarSettlementDirection.deliver,
      amount: ZarCurrencyAssetAmount(
        ZarCurrencyAmount(code: 'EUR', minorUnits: 500000),
      ),
      scheduledAt: at(today, 14, 45),
      hasTime: true,
      createdBy: 'preview-user',
      createdAt: created,
      updatedAt: created,
    ),
    ZarSettlement(
      id: 's4',
      businessId: 'preview-business',
      personId: 'p4',
      direction: ZarSettlementDirection.receive,
      amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '400')),
      scheduledAt: at(today.addDays(1), 12),
      hasTime: false,
      createdBy: 'preview-user',
      createdAt: created,
      updatedAt: created,
    ),
    ZarSettlement(
      id: 's5',
      businessId: 'preview-business',
      personId: 'p2',
      direction: ZarSettlementDirection.deliver,
      amount: usd('8000'),
      scheduledAt: at(today.addDays(-2), 12, 20),
      hasTime: true,
      status: ZarSettlementStatus.completed,
      completedAt: at(today.addDays(-2), 12, 25),
      completedBy: 'preview-user',
      createdBy: 'preview-user',
      createdAt: created,
      updatedAt: created,
    ),
  ];
  return InMemoryZarDomainRepository(people: people, settlements: settlements);
}
