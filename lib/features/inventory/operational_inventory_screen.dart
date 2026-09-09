import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../app_core.dart' show formatJalaliDate, toPersianDigits;
import '../../application/operational_inventory_projector.dart';
import '../../domain/zar_domain_models.dart';

class OperationalInventoryScreen extends StatelessWidget {
  const OperationalInventoryScreen({
    super.key,
    required this.projection,
    required this.personName,
    this.onOpenRecord,
    this.onOpenSettlement,
    this.onQuickAction,
  });

  final ZarOperationalInventoryProjection projection;
  final String Function(String personId) personName;
  final ValueChanged<String>? onOpenRecord;

  /// Backwards-compatible alias while the repository shell is migrated to the
  /// deal-aware inventory API. New callers should use [onOpenRecord].
  final ValueChanged<String>? onOpenSettlement;
  final ValueChanged<String>? onQuickAction;

  ValueChanged<String>? get _recordOpener => onOpenRecord ?? onOpenSettlement;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('موجودی')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'تعهدهای در انتظار',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _section(
          context,
          'در انتظار دریافت',
          projection.pendingReceive,
          const Color(0xFF2F7D4C),
          directionLabel: 'دریافت',
        ),
        _section(
          context,
          'در انتظار پرداخت',
          projection.pendingDeliver,
          const Color(0xFF9D5D36),
          directionLabel: 'پرداخت',
        ),
        const SizedBox(height: 8),
        Text('موجودی واقعی', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _section(
          context,
          'طلا',
          projection.goldInventory,
          const Color(0xFF9A6700),
        ),
        _section(
          context,
          'سکه',
          projection.coinInventory,
          const Color(0xFF8A641E),
        ),
        _section(
          context,
          'ارز',
          projection.currencyInventory,
          const Color(0xFF256B75),
        ),
        _section(
          context,
          'وجه نقد',
          projection.cashInventory,
          const Color(0xFF303030),
        ),
      ],
    ),
  );

  Widget _section(
    BuildContext context,
    String title,
    List<ZarOperationalInventoryItem> items,
    Color accent, {
    String? directionLabel,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(
                'موردی ثبت نشده است.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (var index = 0; index < items.length; index++) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openDetail(context, items[index], accent),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _itemDetails(
                            context,
                            items[index],
                            directionLabel: directionLabel,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _value(items[index]),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                            if (directionLabel != null)
                              Text(
                                directionLabel,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(color: accent),
                              ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        _rtlChevron(pointsRight: true, size: 20),
                      ],
                    ),
                  ),
                ),
                if (index != items.length - 1) const Divider(height: 1),
              ],
          ],
        ),
      ),
    );
  }

  Widget _itemDetails(
    BuildContext context,
    ZarOperationalInventoryItem item, {
    String? directionLabel,
  }) {
    final movement = item.movements.isEmpty ? null : item.movements.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_title(item), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(
          directionLabel == null
              ? _assetType(item)
              : '${_assetType(item)} • $directionLabel',
          style: Theme.of(context).textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
        if (movement != null) ...[
          const SizedBox(height: 2),
          Text(
            _movementTitle(movement),
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'آخرین حرکت: ${_dateTime(movement.occurredAt)}',
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  String _movementTitle(ZarInventoryMovement movement) {
    final name = personName(movement.personId);
    if (movement.source == ZarInventoryMovementSource.deal) {
      return movement.dealType == ZarDealType.buy
          ? 'خرید از $name'
          : 'فروش به $name';
    }
    return movement.direction == ZarSettlementDirection.receive
        ? 'دریافت از $name'
        : 'پرداخت به $name';
  }

  static Widget _rtlChevron({required bool pointsRight, double size = 24}) =>
      Icon(
        pointsRight ? Icons.chevron_left : Icons.chevron_right,
        size: size,
        textDirection: TextDirection.rtl,
      );

  void _openDetail(
    BuildContext context,
    ZarOperationalInventoryItem item,
    Color accent,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OperationalInventoryDetailScreen(
          item: item,
          accent: accent,
          personName: personName,
          onOpenRecord: _recordOpener,
          onQuickAction: onQuickAction,
        ),
      ),
    );
  }
}

class OperationalInventoryDetailScreen extends StatelessWidget {
  const OperationalInventoryDetailScreen({
    super.key,
    required this.item,
    required this.accent,
    required this.personName,
    this.onOpenRecord,
    this.onQuickAction,
  });

  final ZarOperationalInventoryItem item;
  final Color accent;
  final String Function(String personId) personName;
  final ValueChanged<String>? onOpenRecord;
  final ValueChanged<String>? onQuickAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title(item))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('موجودی فعلی'),
                const SizedBox(height: 6),
                Text(
                  _value(item),
                  textDirection: TextDirection.ltr,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: accent),
                ),
                if (item.movements.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    'آخرین حرکت: ${_movementTitle(item.movements.first)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateTime(item.movements.first.occurredAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (onQuickAction != null) ...[
          const SizedBox(height: 14),
          Text('ثبت سریع', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in const ['خرید', 'فروش', 'دریافت', 'پرداخت'])
                OutlinedButton.icon(
                  onPressed: () => onQuickAction!(action),
                  icon: const Icon(CupertinoIcons.add, size: 16),
                  label: Text(action),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Text('سابقه حرکت', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final movement in item.movements)
          Card(
            elevation: 0,
            child: ListTile(
              onTap: onOpenRecord == null
                  ? null
                  : () => onOpenRecord!(movement.recordId),
              title: Text(_movementTitle(movement)),
              subtitle: Text(_dateTime(movement.occurredAt)),
              trailing: Text(
                toPersianDigits(movement.quantityLabel),
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
      ],
    ),
  );

  String _movementTitle(ZarInventoryMovement movement) {
    final name = personName(movement.personId);
    if (movement.source == ZarInventoryMovementSource.deal) {
      return movement.dealType == ZarDealType.buy
          ? 'خرید از $name'
          : 'فروش به $name';
    }
    return movement.direction == ZarSettlementDirection.receive
        ? 'دریافت از $name'
        : 'پرداخت به $name';
  }
}

String _title(ZarOperationalInventoryItem item) => switch (item) {
  ZarGoldInventoryItem(:final fineness) =>
    fineness == null
        ? 'طلای عیار نامشخص'
        : 'طلای عیار ${toPersianDigits(fineness)}',
  ZarCoinInventoryItem(:final displayName) => toPersianDigits(displayName),
  ZarCurrencyInventoryItem(:final code) => code == 'TOMAN' ? 'وجه نقد' : code,
};

String _assetType(ZarOperationalInventoryItem item) => switch (item) {
  ZarGoldInventoryItem() => 'طلا',
  ZarCoinInventoryItem() => 'سکه',
  ZarCurrencyInventoryItem(:final code) => code == 'TOMAN' ? 'وجه نقد' : 'ارز',
};

String _value(ZarOperationalInventoryItem item) => switch (item) {
  ZarGoldInventoryItem(:final grams) => '${_formatDecimal(grams)} گرم',
  ZarCoinInventoryItem(:final quantity) => '${_formatInteger(quantity)} عدد',
  ZarCurrencyInventoryItem(:final code, :final decimalAmount) =>
    code == 'TOMAN'
        ? '${_formatDecimal(decimalAmount)} تومان'
        : '${_formatDecimal(decimalAmount)} $code',
};

String _formatInteger(int value) =>
    toPersianDigits(_groupDigits(value.toString()));

String _formatDecimal(String value) {
  final negative = value.startsWith('-');
  final raw = negative ? value.substring(1) : value;
  final parts = raw.split('.');
  final grouped = _groupDigits(parts.first);
  final result = parts.length == 1 ? grouped : '$grouped٫${parts[1]}';
  return toPersianDigits('${negative ? '-' : ''}$result');
}

String _groupDigits(String digits) {
  final buffer = StringBuffer();
  final first = digits.length % 3;
  var index = 0;
  if (first != 0) {
    buffer.write(digits.substring(0, first));
    index = first;
  }
  while (index < digits.length) {
    if (buffer.isNotEmpty) buffer.write('٬');
    buffer.write(digits.substring(index, index + 3));
    index += 3;
  }
  return buffer.toString();
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  final date = formatJalaliDate(Jalali.fromDateTime(local));
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date، ${toPersianDigits(time)}';
}
