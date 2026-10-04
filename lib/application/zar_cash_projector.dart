import '../domain/zar_cash_entry.dart';
import '../domain/zar_domain_models.dart';
import '../domain/zar_payment_allocation.dart';

class ZarCashLine {
  const ZarCashLine({required this.id, required this.asset, required this.quantity,
    required this.direction, required this.at, required this.label, this.personId,
    this.entry, this.settlement, this.running = '0'});
  final String id;
  final ZarAssetAmount asset;
  final String quantity;
  final ZarSettlementDirection direction;
  final DateTime at;
  final String label;
  final String? personId;
  final ZarCashEntry? entry;
  final ZarSettlement? settlement;
  final String running;
  String get key => cashQuantities(asset).keys.single;
}

class ZarCashBalance {
  ZarCashBalance(this.asset);
  final ZarAssetAmount asset;
  String quantity = '0';
  final List<ZarCashLine> lines = [];
  String get key => cashQuantities(asset).keys.single;
}

class ZarCashProjection {
  const ZarCashProjection(this.balances, this.lines);
  final List<ZarCashBalance> balances;
  final List<ZarCashLine> lines;
}

String cashEntryLabel(ZarCashEntryKind kind) => switch (kind) {
  ZarCashEntryKind.opening => 'موجودی آغازین',
  ZarCashEntryKind.adjustment => 'تطبیق و اصلاح',
  ZarCashEntryKind.contribution => 'آورده به صندوق',
  ZarCashEntryKind.withdrawal => 'برداشت شخصی',
  ZarCashEntryKind.expense => 'هزینه',
  ZarCashEntryKind.delivery => 'تحویل بابت معامله',
  ZarCashEntryKind.reversal => 'برگشت سند',
};

String cashAssetLabel(ZarAssetAmount asset) => switch (asset) {
  ZarGoldAssetAmount(:final value) => 'طلا · عیار ${value.purity ?? 'نامشخص'} (گرم)',
  ZarCurrencyAssetAmount(:final value) => value.code == 'TOMAN' ? 'وجه نقد (تومان)' : '${value.code} (واحد)',
  ZarCoinBundleAmount(:final lines) => '${lines.single.coinTypeNameSnapshot}${lines.single.weightPerPieceGrams == null ? '' : ' · ${lines.single.weightPerPieceGrams} گرم'}${lines.single.fineness == null ? '' : ' · عیار ${lines.single.fineness}'} (عدد)',
};

class ZarCashProjector {
  const ZarCashProjector();

  ZarCashProjection project({required Iterable<ZarCashEntry> entries,
      required Iterable<ZarSettlement> settlements,
      Iterable<ZarPaymentAllocation> allocations = const [], DateTime? asOf}) {
    final rows = <ZarCashLine>[];
    final openings = <String, DateTime>{};
    final allSettlements = settlements.toList();
    for (final entry in entries) {
      if (asOf != null && entry.occurredAt.isAfter(asOf)) continue;
      for (final asset in cashSplitAssets(entry.amount)) {
        final q = cashQuantities(asset).entries.single;
        if (entry.kind == ZarCashEntryKind.opening) openings[q.key] = entry.occurredAt;
        rows.add(ZarCashLine(id: entry.id, asset: asset, quantity: q.value,
          direction: entry.direction, at: entry.occurredAt,
          label: '${cashEntryLabel(entry.kind)} · ${entry.note}', entry: entry));
      }
    }
    for (final settlement in allSettlements) {
      if (settlement.status != ZarSettlementStatus.completed) continue;
      final at = settlement.completedAt!;
      if (asOf != null && at.isAfter(asOf)) continue;
      final effective = zarEffectiveSettlementAmount(settlement, allSettlements, allocations);
      if (effective == null) continue;
      for (final asset in cashSplitAssets(effective)) {
        rows.add(ZarCashLine(id: settlement.id, asset: asset,
          quantity: cashQuantities(asset).values.single, direction: settlement.direction,
          at: at, label: settlement.direction == ZarSettlementDirection.receive ? 'دریافت' : 'پرداخت',
          personId: settlement.personId, settlement: settlement));
      }
    }
    rows.removeWhere((row) => openings[row.key] != null && row.at.isBefore(openings[row.key]!));
    rows.sort((a, b) {
      final time = a.at.compareTo(b.at);
      if (time != 0) return time;
      final ao = a.entry?.kind == ZarCashEntryKind.opening;
      final bo = b.entry?.kind == ZarCashEntryKind.opening;
      return ao != bo ? (ao ? -1 : 1) : a.id.compareTo(b.id);
    });
    final balances = <String, ZarCashBalance>{};
    final lines = <ZarCashLine>[];
    for (final row in rows) {
      final balance = balances.putIfAbsent(row.key, () => ZarCashBalance(row.asset));
      balance.quantity = cashAdd(balance.quantity, row.quantity,
        sign: row.direction == ZarSettlementDirection.receive ? 1 : -1);
      final line = ZarCashLine(id: row.id, asset: row.asset, quantity: row.quantity,
        direction: row.direction, at: row.at, label: row.label, personId: row.personId,
        entry: row.entry, settlement: row.settlement, running: balance.quantity);
      balance.lines.add(line);
      lines.add(line);
    }
    return ZarCashProjection(balances.values.toList()..sort((a, b) => a.key.compareTo(b.key)), lines.reversed.toList());
  }
}

void validateCashCount(ZarCashEntry entry, Iterable<ZarCashEntry> entries,
    Iterable<ZarSettlement> settlements, Iterable<ZarPaymentAllocation> allocations) {
  if (entry.expectedQuantity == null) return;
  final key = cashQuantities(entry.amount).keys.single;
  final p = const ZarCashProjector().project(entries: entries, settlements: settlements, allocations: allocations);
  final current = p.balances.where((b) => b.key == key).firstOrNull?.quantity ?? '0';
  if (cashCompare(current, entry.expectedQuantity!) != 0) {
    throw const FormatException('مانده صندوق تغییر کرده؛ شمارش را دوباره بررسی کنید.');
  }
}
