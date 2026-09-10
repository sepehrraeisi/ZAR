import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../app_core.dart' show formatJalaliDate, monthName, toPersianDigits;
import '../../application/operational_inventory_projector.dart';
import '../../domain/zar_domain_models.dart';
import '../../widgets/zar_amount_display.dart';

/// Operational inventory view. The projection is intentionally supplied by
/// the application layer; this screen never stores or mutates inventory.
class OperationalInventoryScreen extends StatefulWidget {
  const OperationalInventoryScreen({
    super.key,
    required this.projection,
    required this.personName,
    this.onOpenRecord,
    this.onOpenSettlement,
    this.onQuickAction,
    this.onQuickActionWithContext,
    this.stateListenable,
    this.projectionBuilder,
  });

  final ZarOperationalInventoryProjection projection;
  final String Function(String personId) personName;
  final ValueChanged<String>? onOpenRecord;

  /// Backwards-compatible alias for older callers/tests.
  final ValueChanged<String>? onOpenSettlement;
  final ValueChanged<String>? onQuickAction;
  final void Function(String operation, ZarOperationalInventoryItem item)?
  onQuickActionWithContext;

  /// When provided, the screen rebuilds from the current repository state
  /// instead of keeping the projection captured when the route was pushed.
  final Listenable? stateListenable;
  final ZarOperationalInventoryProjection Function()? projectionBuilder;

  @override
  State<OperationalInventoryScreen> createState() =>
      _OperationalInventoryScreenState();
}

class _OperationalInventoryScreenState
    extends State<OperationalInventoryScreen> {
  bool _pendingExpanded = false;

  ValueChanged<String>? get _recordOpener =>
      widget.onOpenRecord ?? widget.onOpenSettlement;

  ZarOperationalInventoryProjection get _projection =>
      widget.projectionBuilder?.call() ?? widget.projection;

  @override
  Widget build(BuildContext context) {
    final listenable = widget.stateListenable;
    if (listenable == null) return _buildScreen(context, _projection);
    return AnimatedBuilder(
      animation: listenable,
      builder: (_, __) => _buildScreen(context, _projection),
    );
  }

  Widget _buildScreen(
    BuildContext context,
    ZarOperationalInventoryProjection projection,
  ) {
    final pendingCount =
        projection.pendingReceive.length + projection.pendingDeliver.length;
    return Scaffold(
      appBar: AppBar(title: const Text('موجودی')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _sectionHeading(
            context,
            title: 'تعهدهای در انتظار',
            summary: pendingCount == 0
                ? 'تعهد بازی وجود ندارد'
                : '${_formatInteger(pendingCount)} مورد',
          ),
          if (pendingCount > 0) ...[
            _pendingCounts(context, projection),
            const SizedBox(height: 8),
          ],
          _section(
            context,
            'در انتظار دریافت',
            _visiblePending(projection.pendingReceive),
            const Color(0xFF2F7D4C),
            directionLabel: 'دریافت',
            isPending: true,
          ),
          _section(
            context,
            'در انتظار پرداخت',
            _visiblePending(projection.pendingDeliver),
            const Color(0xFF9D5D36),
            directionLabel: 'پرداخت',
            isPending: true,
          ),
          if (pendingCount > 2)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () =>
                    setState(() => _pendingExpanded = !_pendingExpanded),
                child: Text(_pendingExpanded ? 'نمایش کمتر' : 'مشاهده همه'),
              ),
            ),
          const SizedBox(height: 4),
          _sectionHeading(context, title: 'موجودی واقعی'),
          const SizedBox(height: 8),
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
            compactEmpty: true,
          ),
        ],
      ),
    );
  }

  List<ZarOperationalInventoryItem> _visiblePending(
    List<ZarOperationalInventoryItem> items,
  ) => _pendingExpanded ? items : items.take(2).toList(growable: false);

  Widget _pendingCounts(
    BuildContext context,
    ZarOperationalInventoryProjection projection,
  ) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        Expanded(
          child: Text(
            'دریافت ${_formatInteger(projection.pendingReceive.length)}',
            style: style?.copyWith(color: const Color(0xFF2F7D4C)),
          ),
        ),
        Text(
          'پرداخت ${_formatInteger(projection.pendingDeliver.length)}',
          style: style?.copyWith(color: const Color(0xFF9D5D36)),
        ),
      ],
    );
  }

  Widget _sectionHeading(
    BuildContext context, {
    required String title,
    String? summary,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
        if (summary != null) Text(summary, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<ZarOperationalInventoryItem> items,
    Color accent, {
    String? directionLabel,
    bool isPending = false,
    bool compactEmpty = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(compactEmpty && items.isEmpty ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: compactEmpty ? 4 : 8),
                child: Text(
                  'موردی ثبت نشده است.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else ...[
              const SizedBox(height: 8),
              for (var index = 0; index < items.length; index++) ...[
                _itemRow(
                  context,
                  items[index],
                  accent,
                  directionLabel: directionLabel,
                  isPending: isPending,
                ),
                if (index != items.length - 1) const Divider(height: 1),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemRow(
    BuildContext context,
    ZarOperationalInventoryItem item,
    Color accent, {
    String? directionLabel,
    required bool isPending,
  }) {
    final movement = item.movements.isEmpty ? null : item.movements.first;
    final openRecord = isPending && movement != null && _recordOpener != null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: openRecord
          ? () => _recordOpener!(movement.recordId)
          : () => _openDetail(context, item, accent),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _itemDetails(
                context,
                item,
                isPending: isPending,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 124, child: _amountForItem(context, item, accent)),
            const SizedBox(width: 4),
            const _InventoryDisclosureChevron(),
          ],
        ),
      ),
    );
  }

  Widget _itemDetails(
    BuildContext context,
    ZarOperationalInventoryItem item, {
    required bool isPending,
  }) {
    final theme = Theme.of(context);
    final movement = item.movements.isEmpty ? null : item.movements.first;
    final person = movement == null
        ? null
        : widget.personName(movement.personId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isPending && person != null ? person : _title(item),
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isPending) ...[
          const SizedBox(height: 2),
          Text(
            _title(item),
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          if (movement != null)
            Text(
              'آخرین فعالیت: ${_compactDateTime(movement.occurredAt)}',
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
        ] else if (movement != null) ...[
          const SizedBox(height: 2),
          Text(
            '${_movementTitle(movement)} · ${_compactDateTime(movement.occurredAt)}',
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  String _movementTitle(ZarInventoryMovement movement) {
    final name = widget.personName(movement.personId);
    if (movement.source == ZarInventoryMovementSource.deal) {
      return movement.dealType == ZarDealType.buy
          ? 'خرید از $name'
          : 'فروش به $name';
    }
    return movement.direction == ZarSettlementDirection.receive
        ? 'دریافت از $name'
        : 'پرداخت به $name';
  }

  Widget _amountForItem(
    BuildContext context,
    ZarOperationalInventoryItem item,
    Color accent,
  ) {
    final parts = _itemAmountParts(item);
    return ZarAmountDisplay(
      amount: parts.amount,
      unit: parts.unit,
      negative: parts.negative,
      amountStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: parts.negative ? const Color(0xFF9E4D4D) : accent,
      ),
      unitStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: parts.negative ? const Color(0xFF9E4D4D) : accent,
      ),
    );
  }

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
          personName: widget.personName,
          onOpenRecord: _recordOpener,
          onQuickAction: widget.onQuickAction,
          onQuickActionWithContext: widget.onQuickActionWithContext,
          stateListenable: widget.stateListenable,
          itemBuilder: widget.projectionBuilder == null
              ? null
              : () => _findCurrentItem(item.identity),
        ),
      ),
    );
  }

  ZarOperationalInventoryItem _findCurrentItem(String identity) {
    final projection = _projection;
    final all = <ZarOperationalInventoryItem>[
      ...projection.goldInventory,
      ...projection.coinInventory,
      ...projection.currencyInventory,
      ...projection.cashInventory,
    ];
    return all.firstWhere(
      (candidate) => candidate.identity == identity,
      orElse: () => _emptyItem(identity),
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
    this.onQuickActionWithContext,
    this.stateListenable,
    this.itemBuilder,
  });

  final ZarOperationalInventoryItem item;
  final Color accent;
  final String Function(String personId) personName;
  final ValueChanged<String>? onOpenRecord;
  final ValueChanged<String>? onQuickAction;
  final void Function(String operation, ZarOperationalInventoryItem item)?
  onQuickActionWithContext;
  final Listenable? stateListenable;
  final ZarOperationalInventoryItem Function()? itemBuilder;

  @override
  Widget build(BuildContext context) {
    final listenable = stateListenable;
    if (listenable == null) return _build(context, itemBuilder?.call() ?? item);
    return AnimatedBuilder(
      animation: listenable,
      builder: (_, __) => _build(context, itemBuilder?.call() ?? item),
    );
  }

  Widget _build(BuildContext context, ZarOperationalInventoryItem currentItem) {
    final movement = currentItem.movements.isEmpty
        ? null
        : currentItem.movements.first;
    return Scaffold(
      appBar: AppBar(title: Text(_title(currentItem))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('موجودی فعلی'),
                  const SizedBox(height: 6),
                  _amountForItem(context, currentItem),
                  if (movement != null) ...[
                    const Divider(height: 22),
                    Text(
                      'آخرین فعالیت',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _movementTitle(movement),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      _compactDateTime(movement.occurredAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onQuickAction != null || onQuickActionWithContext != null) ...[
            const SizedBox(height: 12),
            Text('ثبت سریع', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final actions = const ['خرید', 'فروش', 'دریافت', 'پرداخت'];
                if (constraints.maxWidth < 420) {
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisExtent: 44,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      for (final action in actions)
                        _quickButton(action, currentItem),
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var index = 0; index < actions.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _quickButton(actions[index], currentItem),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          Text('فعالیت اخیر', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          if (currentItem.movements.isEmpty)
            const Text('فعالیتی ثبت نشده است.')
          else
            for (final movement in currentItem.movements)
              _movementCard(context, movement),
        ],
      ),
    );
  }

  Widget _quickButton(String action, ZarOperationalInventoryItem currentItem) =>
      OutlinedButton.icon(
        onPressed: () {
          if (onQuickActionWithContext != null) {
            onQuickActionWithContext!(action, currentItem);
          } else {
            onQuickAction?.call(action);
          }
        },
        icon: const Icon(CupertinoIcons.add, size: 16),
        label: Text(action),
      );

  Widget _movementCard(BuildContext context, ZarInventoryMovement movement) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onOpenRecord == null
            ? null
            : () => onOpenRecord!(movement.recordId),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '${_movementTitle(movement)} · ${_compactDateTime(movement.occurredAt)}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 112, child: _movementAmount(context, movement)),
              const SizedBox(width: 2),
              const _InventoryDisclosureChevron(size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _movementAmount(BuildContext context, ZarInventoryMovement movement) {
    final parts = _quantityParts(movement.quantityLabel);
    return ZarAmountDisplay(
      amount: parts.amount,
      unit: parts.unit,
      negative: parts.negative,
      amountStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: parts.negative ? const Color(0xFF9E4D4D) : accent,
      ),
      unitStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: accent),
    );
  }

  Widget _amountForItem(
    BuildContext context,
    ZarOperationalInventoryItem item,
  ) {
    final parts = _itemAmountParts(item);
    return ZarAmountDisplay(
      amount: parts.amount,
      unit: parts.unit,
      negative: parts.negative,
      amountStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: parts.negative ? const Color(0xFF9E4D4D) : accent,
      ),
      unitStyle: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: accent),
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
}

class _InventoryDisclosureChevron extends StatelessWidget {
  const _InventoryDisclosureChevron({this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_left, textDirection: TextDirection.ltr, size: size);
}

({String amount, String unit, bool negative}) _itemAmountParts(
  ZarOperationalInventoryItem item,
) => switch (item) {
  ZarGoldInventoryItem(:final grams) => (
    amount: _formatGoldDecimal(grams),
    unit: 'گرم',
    negative: grams.startsWith('-'),
  ),
  ZarCoinInventoryItem(:final quantity) => (
    amount: _formatInteger(quantity.abs()),
    unit: 'عدد',
    negative: quantity < 0,
  ),
  ZarCurrencyInventoryItem(:final code, :final decimalAmount) => (
    amount: _formatDecimal(decimalAmount.replaceFirst('-', '')),
    unit: code == 'TOMAN' ? 'تومان' : code,
    negative: decimalAmount.startsWith('-'),
  ),
};

({String amount, String unit, bool negative}) _quantityParts(String value) {
  final normalized = value.trim();
  if (normalized.endsWith(' گرم')) {
    final raw = normalized.substring(0, normalized.length - 5).trim();
    return (
      amount: _formatGoldDecimal(raw.replaceFirst('-', '')),
      unit: 'گرم',
      negative: raw.startsWith('-'),
    );
  }
  if (normalized.endsWith(' عدد')) {
    final raw = normalized.substring(0, normalized.length - 5).trim();
    return (
      amount: _formatDecimal(raw.replaceFirst('-', '')),
      unit: 'عدد',
      negative: raw.startsWith('-'),
    );
  }
  final split = normalized.split(RegExp(r'\s+'));
  if (split.length >= 2) {
    final raw = split.sublist(1).join(' ');
    return (
      amount: _formatDecimal(raw.replaceFirst('-', '')),
      unit: split.first,
      negative: raw.startsWith('-'),
    );
  }
  return (
    amount: _formatDecimal(normalized.replaceFirst('-', '')),
    unit: '',
    negative: normalized.startsWith('-'),
  );
}

String _title(ZarOperationalInventoryItem item) => switch (item) {
  ZarGoldInventoryItem(:final fineness) =>
    fineness == null
        ? 'طلای عیار نامشخص'
        : 'طلای عیار ${toPersianDigits(fineness)}',
  ZarCoinInventoryItem(:final displayName) => toPersianDigits(displayName),
  ZarCurrencyInventoryItem(:final code) => code == 'TOMAN' ? 'وجه نقد' : code,
};

String _formatInteger(int value) =>
    toPersianDigits(_groupDigits(value.toString()));

String _formatGoldDecimal(String value) {
  try {
    final parsed = ZarExactDecimal.parse(value);
    // Presentation precision is intentionally bounded; persisted arithmetic
    // remains untouched and exact. Round half-up using integer arithmetic.
    final rounded = _roundDecimal(parsed, 4).toString();
    return _formatDecimal(rounded);
  } catch (_) {
    return _formatDecimal(value);
  }
}

ZarExactDecimal _roundDecimal(ZarExactDecimal value, int places) {
  if (value.scale <= places) return value;
  final divisor = BigInt.from(10).pow(value.scale - places);
  var quotient = value.unscaled ~/ divisor;
  final remainder = value.unscaled.remainder(divisor).abs();
  if (remainder * BigInt.two >= divisor) {
    quotient += value.unscaled.isNegative ? -BigInt.one : BigInt.one;
  }
  final text = quotient.toString();
  if (places == 0) return ZarExactDecimal.parse(text);
  final negative = text.startsWith('-');
  final raw = negative ? text.substring(1) : text;
  final padded = raw.padLeft(places + 1, '0');
  final split = padded.length - places;
  return ZarExactDecimal.parse(
    '${negative ? '-' : ''}${padded.substring(0, split)}.${padded.substring(split)}',
  );
}

String _formatDecimal(String value) {
  final negative = value.startsWith('-');
  final raw = negative ? value.substring(1) : value;
  final parts = raw.split('.');
  final fraction = parts.length == 1
      ? ''
      : parts[1].replaceFirst(RegExp(r'0+$'), '');
  final grouped = _groupDigits(parts.first);
  final result = fraction.isEmpty ? grouped : '$grouped٫$fraction';
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

String _compactDateTime(DateTime value) {
  final local = value.toLocal();
  final jalali = Jalali.fromDateTime(local);
  final currentYear = Jalali.now().year;
  final date = jalali.year == currentYear
      ? '${toPersianDigits(jalali.day.toString())} ${monthName(jalali.month)}'
      : formatJalaliDate(jalali);
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date · ${toPersianDigits(time)}';
}

ZarOperationalInventoryItem _emptyItem(String identity) {
  if (identity.startsWith('gold:')) {
    return ZarGoldInventoryItem(
      identity: identity,
      fineness: identity == 'gold:unknown' ? null : identity.substring(5),
      grams: '0',
      movements: const [],
    );
  }
  if (identity.startsWith('coin:')) {
    return ZarCoinInventoryItem(
      identity: identity,
      displayName: identity.substring(5),
      quantity: 0,
      movements: const [],
    );
  }
  final code = identity.substring('currency:'.length);
  return ZarCurrencyInventoryItem(
    identity: identity,
    code: code,
    decimalAmount: '0',
    movements: const [],
  );
}
