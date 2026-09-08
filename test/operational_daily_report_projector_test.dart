import 'package:flutter_app/application/operational_daily_report_projector.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projector = ZarOperationalDailyReportProjector();
  final selected = DateTime(2026, 9, 2, 12);

  test('separates daily deals and completed movements', () {
    final report = projector.project(
      selectedDay: selected,
      deals: [
        deal('buy', ZarDealType.buy, DateTime(2026, 9, 2, 9)),
        deal('sell', ZarDealType.sell, DateTime(2026, 9, 2, 11)),
      ],
      settlements: [
        settlement(
          'receive',
          ZarSettlementDirection.receive,
          scheduledAt: DateTime(2026, 9, 1, 10),
          status: ZarSettlementStatus.completed,
          completedAt: DateTime(2026, 9, 2, 13),
        ),
        settlement(
          'deliver',
          ZarSettlementDirection.deliver,
          scheduledAt: DateTime(2026, 9, 2, 10),
          status: ZarSettlementStatus.completed,
          completedAt: DateTime(2026, 9, 2, 14),
        ),
      ],
    );

    expect(report.buyDealIds, ['buy']);
    expect(report.sellDealIds, ['sell']);
    expect(report.completedReceiveIds, ['receive']);
    expect(report.completedDeliverIds, ['deliver']);
  });

  test('keeps due today and overdue open obligations separate', () {
    final report = projector.project(
      selectedDay: selected,
      deals: const [],
      settlements: [
        settlement(
          'today',
          ZarSettlementDirection.receive,
          scheduledAt: DateTime(2026, 9, 2, 15),
        ),
        settlement(
          'overdue',
          ZarSettlementDirection.deliver,
          scheduledAt: DateTime(2026, 9, 1, 15),
        ),
      ],
    );

    expect(report.openDueIds, ['today']);
    expect(report.overdueOpenIds, ['overdue']);
  });

  test('cancelled records are excluded', () {
    final report = projector.project(
      selectedDay: selected,
      deals: [
        deal(
          'cancelled-deal',
          ZarDealType.buy,
          DateTime(2026, 9, 2, 9),
          status: ZarDealStatus.cancelled,
        ),
      ],
      settlements: [
        settlement(
          'cancelled-settlement',
          ZarSettlementDirection.receive,
          scheduledAt: DateTime(2026, 9, 2, 10),
          status: ZarSettlementStatus.cancelled,
        ),
      ],
    );

    expect(report.dealCount, 0);
    expect(report.completedMovementCount, 0);
    expect(report.actionCount, 0);
  });
}

final _amount = ZarCurrencyAssetAmount(
  ZarCurrencyAmount(code: 'USD', minorUnits: 10000, minorUnitScale: 2),
);

ZarDeal deal(
  String id,
  ZarDealType type,
  DateTime at, {
  ZarDealStatus status = ZarDealStatus.active,
}) => ZarDeal(
  id: id,
  businessId: 'business',
  type: type,
  personId: 'person',
  amount: _amount,
  dealAt: at,
  status: status,
  createdBy: 'user',
  createdAt: at,
  updatedAt: at,
);

ZarSettlement settlement(
  String id,
  ZarSettlementDirection direction, {
  required DateTime scheduledAt,
  ZarSettlementStatus status = ZarSettlementStatus.open,
  DateTime? completedAt,
}) => ZarSettlement(
  id: id,
  businessId: 'business',
  personId: 'person',
  direction: direction,
  amount: _amount,
  scheduledAt: scheduledAt,
  hasTime: true,
  status: status,
  completedAt: completedAt,
  completedBy: status == ZarSettlementStatus.completed ? 'user' : null,
  createdBy: 'user',
  createdAt: scheduledAt,
  updatedAt: completedAt ?? scheduledAt,
);
