import '../domain/zar_domain_models.dart';

class ZarDailyOperationalReport {
  const ZarDailyOperationalReport({
    required this.day,
    required this.buyDealIds,
    required this.sellDealIds,
    required this.completedReceiveIds,
    required this.completedDeliverIds,
    required this.openDueIds,
    required this.overdueOpenIds,
  });

  final DateTime day;
  final List<String> buyDealIds;
  final List<String> sellDealIds;
  final List<String> completedReceiveIds;
  final List<String> completedDeliverIds;
  final List<String> openDueIds;
  final List<String> overdueOpenIds;

  int get dealCount => buyDealIds.length + sellDealIds.length;
  int get completedMovementCount =>
      completedReceiveIds.length + completedDeliverIds.length;
  int get actionCount => openDueIds.length + overdueOpenIds.length;
}

/// Read-only daily operational report. It intentionally does not calculate
/// profit/loss, net worth, or cross-asset monetary totals.
class ZarOperationalDailyReportProjector {
  const ZarOperationalDailyReportProjector();

  ZarDailyOperationalReport project({
    required Iterable<ZarDeal> deals,
    required Iterable<ZarSettlement> settlements,
    required DateTime selectedDay,
  }) {
    final day = DateTime(
      selectedDay.toLocal().year,
      selectedDay.toLocal().month,
      selectedDay.toLocal().day,
    );
    final nextDay = day.add(const Duration(days: 1));

    final buys = <ZarDeal>[];
    final sells = <ZarDeal>[];
    final receives = <ZarSettlement>[];
    final delivers = <ZarSettlement>[];
    final openDue = <ZarSettlement>[];
    final overdueOpen = <ZarSettlement>[];

    for (final deal in deals) {
      if (deal.status == ZarDealStatus.cancelled) continue;
      final occurred = deal.dealAt.toLocal();
      if (!_withinDay(occurred, day, nextDay)) continue;
      (deal.type == ZarDealType.buy ? buys : sells).add(deal);
    }

    for (final settlement in settlements) {
      if (settlement.status == ZarSettlementStatus.completed) {
        final completedAt = settlement.completedAt?.toLocal();
        if (completedAt != null && _withinDay(completedAt, day, nextDay)) {
          (settlement.direction == ZarSettlementDirection.receive
                  ? receives
                  : delivers)
              .add(settlement);
        }
        continue;
      }
      if (settlement.status != ZarSettlementStatus.open) continue;

      final due = settlement.scheduledAt.toLocal();
      if (_withinDay(due, day, nextDay)) {
        openDue.add(settlement);
      } else if (due.isBefore(day)) {
        overdueOpen.add(settlement);
      }
    }

    buys.sort((a, b) => a.dealAt.compareTo(b.dealAt));
    sells.sort((a, b) => a.dealAt.compareTo(b.dealAt));
    receives.sort(_completedSettlementCompare);
    delivers.sort(_completedSettlementCompare);
    openDue.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    overdueOpen.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return ZarDailyOperationalReport(
      day: day,
      buyDealIds: List.unmodifiable(buys.map((item) => item.id)),
      sellDealIds: List.unmodifiable(sells.map((item) => item.id)),
      completedReceiveIds: List.unmodifiable(receives.map((item) => item.id)),
      completedDeliverIds: List.unmodifiable(delivers.map((item) => item.id)),
      openDueIds: List.unmodifiable(openDue.map((item) => item.id)),
      overdueOpenIds: List.unmodifiable(overdueOpen.map((item) => item.id)),
    );
  }
}

bool _withinDay(DateTime value, DateTime day, DateTime nextDay) =>
    !value.isBefore(day) && value.isBefore(nextDay);

int _completedSettlementCompare(ZarSettlement a, ZarSettlement b) =>
    (a.completedAt ?? a.updatedAt).compareTo(b.completedAt ?? b.updatedAt);
