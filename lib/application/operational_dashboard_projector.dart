import '../domain/zar_domain_models.dart';
import 'operational_inventory_projector.dart';

enum ZarDashboardActivityType { deal, settlement }

class ZarDashboardActivity {
  const ZarDashboardActivity({
    required this.id,
    required this.type,
    required this.occurredAt,
  });

  final String id;
  final ZarDashboardActivityType type;
  final DateTime occurredAt;
}

class ZarOperationalDashboardProjection {
  const ZarOperationalDashboardProjection({
    required this.todaySettlementIds,
    required this.overdueSettlementIds,
    required this.pendingReceiveCount,
    required this.pendingDeliverCount,
    required this.inventory,
    required this.recentActivities,
  });

  final List<String> todaySettlementIds;
  final List<String> overdueSettlementIds;
  final int pendingReceiveCount;
  final int pendingDeliverCount;
  final ZarOperationalInventoryProjection inventory;
  final List<ZarDashboardActivity> recentActivities;

  int get actionableCount =>
      todaySettlementIds.length + overdueSettlementIds.length;
}

/// A read-only operational summary from one already-loaded domain snapshot.
/// It stores nothing and delegates all asset aggregation to the inventory
/// projector so Home and Inventory cannot drift apart.
class ZarOperationalDashboardProjector {
  const ZarOperationalDashboardProjector({
    this.inventoryProjector = const ZarOperationalInventoryProjector(),
  });

  final ZarOperationalInventoryProjector inventoryProjector;

  ZarOperationalDashboardProjection project({
    required Iterable<ZarDeal> deals,
    required Iterable<ZarSettlement> settlements,
    required DateTime now,
    int recentLimit = 5,
  }) {
    final localNow = now.toLocal();
    final today = <ZarSettlement>[];
    final overdue = <ZarSettlement>[];
    var pendingReceive = 0;
    var pendingDeliver = 0;

    for (final settlement in settlements) {
      if (!settlement.isOpen) continue;
      if (settlement.direction == ZarSettlementDirection.receive) {
        pendingReceive++;
      } else {
        pendingDeliver++;
      }
      final due = settlement.scheduledAt.toLocal();
      if (due.isBefore(localNow)) {
        overdue.add(settlement);
      } else if (_sameLocalDate(due, localNow)) {
        today.add(settlement);
      }
    }
    today.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    overdue.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final activity = <ZarDashboardActivity>[
      ...deals.map(
        (item) => ZarDashboardActivity(
          id: item.id,
          type: ZarDashboardActivityType.deal,
          occurredAt: item.dealAt,
        ),
      ),
      ...settlements
          .where((item) => item.status != ZarSettlementStatus.open)
          .map(
            (item) => ZarDashboardActivity(
              id: item.id,
              type: ZarDashboardActivityType.settlement,
              occurredAt: item.completedAt ?? item.updatedAt,
            ),
          ),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return ZarOperationalDashboardProjection(
      todaySettlementIds: List.unmodifiable(today.map((item) => item.id)),
      overdueSettlementIds: List.unmodifiable(overdue.map((item) => item.id)),
      pendingReceiveCount: pendingReceive,
      pendingDeliverCount: pendingDeliver,
      inventory: inventoryProjector.project(settlements: settlements),
      recentActivities: List.unmodifiable(activity.take(recentLimit)),
    );
  }
}

bool _sameLocalDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
