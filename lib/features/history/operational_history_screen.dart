import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_core.dart';

class OperationalHistoryScreen extends StatefulWidget {
  const OperationalHistoryScreen({
    super.key,
    required this.records,
    required this.personName,
    this.onTapRecord,
  });

  final List<AppRecord> records;
  final String Function(String personId) personName;
  final ValueChanged<AppRecord>? onTapRecord;

  @override
  State<OperationalHistoryScreen> createState() => _OperationalHistoryScreenState();
}

class _OperationalHistoryScreenState extends State<OperationalHistoryScreen> {
  String _query = '';
  HistoryFilter _filter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final items = widget.records
        .where(_matchesFilter)
        .where((record) {
          if (normalized.isEmpty) return true;
          final searchable = <String>[
            widget.personName(record.personId),
            record.operationLabel,
            record.assetLabel,
            record.amountDisplay,
            record.currencyCode ?? '',
            record.note ?? '',
            if (record.type == RecordType.settlement) record.statusLabel(),
          ].join(' ').toLowerCase();
          return searchable.contains(normalized);
        })
        .toList(growable: false)
      ..sort(_newestFirst);

    return Scaffold(
      appBar: AppBar(title: const Text('سوابق')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(CupertinoIcons.search),
                    hintText: 'جستجو در سوابق',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip('همه', HistoryFilter.all),
                      _chip('خرید', HistoryFilter.buy),
                      _chip('فروش', HistoryFilter.sell),
                      _chip('دریافت', HistoryFilter.receive),
                      _chip('تحویل', HistoryFilter.deliver),
                      _chip('انجام‌شده', HistoryFilter.completed),
                      _chip('لغوشده', HistoryFilter.cancelled),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'فعالیت‌ها',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${toPersianDigits(items.length.toString())} مورد',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const _HistoryEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final record = items[index];
                      return _HistoryCard(
                        record: record,
                        personName: widget.personName(record.personId),
                        onTap: widget.onTapRecord == null
                            ? null
                            : () => widget.onTapRecord!(record),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, HistoryFilter value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
              : Theme.of(context).dividerColor,
        ),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  bool _matchesFilter(AppRecord record) => switch (_filter) {
        HistoryFilter.all => true,
        HistoryFilter.buy => record.type == RecordType.deal && record.operationLabel == 'خرید',
        HistoryFilter.sell => record.type == RecordType.deal && record.operationLabel == 'فروش',
        HistoryFilter.receive => record.type == RecordType.settlement && record.operationLabel == 'دریافت',
        HistoryFilter.deliver => record.type == RecordType.settlement && record.operationLabel == 'تحویل',
        HistoryFilter.completed => record.type == RecordType.settlement && record.status == SettlementStatus.completed,
        HistoryFilter.cancelled => record.type == RecordType.settlement && record.status == SettlementStatus.cancelled,
      };

  int _newestFirst(AppRecord a, AppRecord b) {
    final date = b.date.compareTo(a.date);
    if (date != 0) return date;
    final aMinutes = (a.time?.hour ?? -1) * 60 + (a.time?.minute ?? 0);
    final bMinutes = (b.time?.hour ?? -1) * 60 + (b.time?.minute ?? 0);
    return bMinutes.compareTo(aMinutes);
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.record,
    required this.personName,
    required this.onTap,
  });

  final AppRecord record;
  final String personName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDeal = record.type == RecordType.deal;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _OperationPill(record: record),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            personName,
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _assetLine(record),
                      style: theme.textTheme.titleMedium,
                    ),
                    if ((record.note ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        record.note!,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(formatJalaliDate(record.date), style: theme.textTheme.bodyMedium),
                        Text(record.timeLabel(), style: theme.textTheme.bodyMedium),
                        if (!isDeal) _SettlementStatusLabel(record: record),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(CupertinoIcons.chevron_left, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationPill extends StatelessWidget {
  const _OperationPill({required this.record});
  final AppRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDeal = record.type == RecordType.deal;
    final color = isDeal
        ? theme.colorScheme.primary
        : record.operationLabel == 'دریافت'
            ? const Color(0xFF2F7D4C)
            : const Color(0xFF8C5A2B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        record.operationLabel,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettlementStatusLabel extends StatelessWidget {
  const _SettlementStatusLabel({required this.record});
  final AppRecord record;

  @override
  Widget build(BuildContext context) {
    final color = record.status == SettlementStatus.completed
        ? const Color(0xFF2F7D4C)
        : record.status == SettlementStatus.cancelled
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).textTheme.bodyMedium?.color;
    return Text(
      record.statusLabel(),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.clock, size: 34),
              const SizedBox(height: 10),
              Text('نتیجه‌ای پیدا نشد.', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'فیلتر یا عبارت جستجو را تغییر دهید.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
}

String _assetLine(AppRecord record) {
  if (record.coinLines.isNotEmpty) {
    if (record.coinLines.length == 1) {
      final line = record.coinLines.single;
      return '${toPersianDigits(line.quantity.toString())} عدد ${line.name}';
    }
    return '${toPersianDigits(record.coinLines.length.toString())} نوع سکه';
  }
  if (record.currencyCode != null || record.assetLabel == 'وجه نقد') {
    return record.amountDisplay;
  }
  if (record.goldFineness != null) {
    return '${record.amountDisplay} گرم • عیار ${toPersianDigits(record.goldFineness!)}';
  }
  return '${record.amountDisplay} ${record.assetLabel}';
}
