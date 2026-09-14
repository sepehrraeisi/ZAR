import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../app_core.dart';
import '../reminders/reminder_model.dart' show dueDateTimeFromJalali;

enum HistoryStatusFilter {
  all,
  recorded,
  pending,
  completed,
  overdue,
  cancelled,
}

enum HistoryAssetFilter { all, gold, coin, currency, cash }

class HistoryAdvancedFilters {
  const HistoryAdvancedFilters({
    this.status = HistoryStatusFilter.all,
    this.asset = HistoryAssetFilter.all,
    this.personId,
    this.from,
    this.to,
  });

  final HistoryStatusFilter status;
  final HistoryAssetFilter asset;
  final String? personId;
  final Jalali? from;
  final Jalali? to;

  int get activeCount => [
    status != HistoryStatusFilter.all,
    asset != HistoryAssetFilter.all,
    personId != null,
    from != null,
    to != null,
  ].where((active) => active).length;

  HistoryAdvancedFilters copyWith({
    HistoryStatusFilter? status,
    HistoryAssetFilter? asset,
    Object? personId = _unset,
    Object? from = _unset,
    Object? to = _unset,
  }) {
    return HistoryAdvancedFilters(
      status: status ?? this.status,
      asset: asset ?? this.asset,
      personId: identical(personId, _unset)
          ? this.personId
          : personId as String?,
      from: identical(from, _unset) ? this.from : from as Jalali?,
      to: identical(to, _unset) ? this.to : to as Jalali?,
    );
  }
}

const _unset = Object();

class OperationalHistoryScreen extends StatefulWidget {
  const OperationalHistoryScreen({
    super.key,
    required this.records,
    required this.personName,
    this.people = const [],
    this.onTapRecord,
  });

  final List<AppRecord> records;
  final String Function(String personId) personName;
  final List<AppPerson> people;
  final ValueChanged<AppRecord>? onTapRecord;

  @override
  State<OperationalHistoryScreen> createState() =>
      _OperationalHistoryScreenState();
}

class _OperationalHistoryScreenState extends State<OperationalHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  HistoryFilter _operation = HistoryFilter.all;
  HistoryAdvancedFilters _advanced = const HistoryAdvancedFilters();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredRecords();
    final theme = Theme.of(context);
    final hasFilters =
        _operation != HistoryFilter.all || _advanced.activeCount > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('سوابق')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: TextField(
                key: const ValueKey('history-search'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                  hintText: 'جستجو در سوابق',
                  suffixIcon: _query.trim().isEmpty
                      ? null
                      : IconButton(
                          key: const ValueKey('history-search-clear'),
                          tooltip: 'پاک کردن جستجو',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 18,
                          ),
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              key: const ValueKey('history-operation-filters'),
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    _operationChip(context, 'همه', HistoryFilter.all),
                    const SizedBox(width: 6),
                    _operationChip(context, 'خرید', HistoryFilter.buy),
                    const SizedBox(width: 6),
                    _operationChip(context, 'فروش', HistoryFilter.sell),
                    const SizedBox(width: 6),
                    _operationChip(context, 'دریافت', HistoryFilter.receive),
                    const SizedBox(width: 6),
                    _operationChip(context, 'پرداخت', HistoryFilter.deliver),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('history-advanced-filter'),
                  onPressed: _openAdvancedFilters,
                  icon: const Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 17,
                  ),
                  label: Text(
                    _advanced.activeCount == 0
                        ? 'فیلترها'
                        : 'فیلترها (${toPersianDigits(_advanced.activeCount.toString())})',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                if (hasFilters)
                  TextButton(
                    key: const ValueKey('history-clear-filters'),
                    onPressed: _clearFilters,
                    child: const Text('پاک کردن فیلترها'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  'فعالیت‌ها',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${toPersianDigits(items.length.toString())} مورد',
                  key: const ValueKey('history-result-count'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? _HistoryEmptyState(
                      hasQuery: _query.trim().isNotEmpty,
                      hasFilters: hasFilters,
                      onClear: hasFilters || _query.trim().isNotEmpty
                          ? _clearAll
                          : null,
                    )
                  : ListView.separated(
                      key: const ValueKey('history-list'),
                      padding: const EdgeInsets.only(bottom: 28),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final record = items[index];
                        return _HistoryCard(
                          key: ValueKey('history-record-${record.id}'),
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
      ),
    );
  }

  Widget _operationChip(
    BuildContext context,
    String label,
    HistoryFilter value,
  ) {
    final selected = _operation == value;
    final theme = Theme.of(context);
    return ChoiceChip(
      key: ValueKey('history-operation-${value.name}'),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.35)
            : theme.dividerColor,
      ),
      onSelected: (_) => setState(() => _operation = value),
    );
  }

  List<AppRecord> _filteredRecords() {
    return filterOperationalHistoryRecords(
      records: widget.records,
      personName: widget.personName,
      people: widget.people,
      query: _query,
      operation: _operation,
      advanced: _advanced,
      now: DateTime.now(),
    );
  }

  Future<void> _openAdvancedFilters() async {
    final result = await showModalBottomSheet<HistoryAdvancedFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HistoryAdvancedFilterSheet(
        initial: _advanced,
        people: widget.people,
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _advanced = result);
  }

  void _clearFilters() => setState(() {
    _operation = HistoryFilter.all;
    _advanced = const HistoryAdvancedFilters();
  });

  void _clearAll() {
    _searchController.clear();
    setState(() {
      _query = '';
      _operation = HistoryFilter.all;
      _advanced = const HistoryAdvancedFilters();
    });
  }
}

/// Pure, deterministic projection used by the History screen and tests.
///
/// It filters the already-loaded operational records; it never queries or
/// mutates persistence and keeps Deal/Settlement semantics separate.
List<AppRecord> filterOperationalHistoryRecords({
  required Iterable<AppRecord> records,
  required String Function(String personId) personName,
  List<AppPerson> people = const [],
  String query = '',
  HistoryFilter operation = HistoryFilter.all,
  HistoryAdvancedFilters advanced = const HistoryAdvancedFilters(),
  DateTime? now,
}) {
  final normalized = _normalizeHistoryQuery(query);
  final current = now ?? DateTime.now();
  final items = records
      .where((record) {
        if (!_historyMatchesOperation(record, operation) ||
            !_historyMatchesAdvanced(record, advanced, current)) {
          return false;
        }
        if (normalized.isEmpty) return true;
        final person = people
            .where((item) => item.id == record.personId)
            .firstOrNull;
        final searchable = <String>[
          personName(record.personId),
          person?.phone ?? '',
          record.operationDisplayLabel,
          record.operationLabel,
          record.assetLabel,
          recordAssetSummary(record),
          record.amountDisplay,
          record.currencyCode ?? '',
          record.goldFineness ?? '',
          record.note ?? '',
          ...record.coinLines.map((line) => line.name),
          if (record.type == RecordType.settlement) record.statusLabel(),
        ].map(_normalizeHistoryQuery).join(' ');
        return searchable.contains(normalized);
      })
      .toList(growable: false);
  return items..sort(_compareHistoryNewestFirst);
}

bool _historyMatchesOperation(
  AppRecord record,
  HistoryFilter operation,
) => switch (operation) {
  HistoryFilter.all => true,
  HistoryFilter.buy =>
    record.type == RecordType.deal && record.operationLabel == 'خرید',
  HistoryFilter.sell =>
    record.type == RecordType.deal && record.operationLabel == 'فروش',
  HistoryFilter.receive =>
    record.type == RecordType.settlement && record.operationLabel == 'دریافت',
  HistoryFilter.deliver =>
    record.type == RecordType.settlement && record.operationLabel == 'تحویل',
  HistoryFilter.completed || HistoryFilter.cancelled => true,
};

bool _historyMatchesAdvanced(
  AppRecord record,
  HistoryAdvancedFilters advanced,
  DateTime now,
) {
  if (advanced.personId != null && record.personId != advanced.personId) {
    return false;
  }
  if (!_historyMatchesAsset(record, advanced.asset)) return false;
  switch (advanced.status) {
    case HistoryStatusFilter.all:
      break;
    case HistoryStatusFilter.recorded:
      if (record.type != RecordType.deal) return false;
      break;
    case HistoryStatusFilter.pending:
      if (record.type != RecordType.settlement ||
          record.status != SettlementStatus.open ||
          _historyIsOverdue(record, now)) {
        return false;
      }
      break;
    case HistoryStatusFilter.completed:
      if (record.type != RecordType.settlement ||
          record.status != SettlementStatus.completed) {
        return false;
      }
      break;
    case HistoryStatusFilter.overdue:
      if (record.type != RecordType.settlement ||
          record.status != SettlementStatus.open ||
          !_historyIsOverdue(record, now)) {
        return false;
      }
      break;
    case HistoryStatusFilter.cancelled:
      if (record.type != RecordType.settlement ||
          record.status != SettlementStatus.cancelled) {
        return false;
      }
      break;
  }
  if (advanced.from != null && record.date.compareTo(advanced.from!) < 0) {
    return false;
  }
  if (advanced.to != null && record.date.compareTo(advanced.to!) > 0) {
    return false;
  }
  return true;
}

bool _historyMatchesAsset(AppRecord record, HistoryAssetFilter filter) =>
    switch (filter) {
      HistoryAssetFilter.all => true,
      HistoryAssetFilter.gold =>
        record.coinLines.isEmpty &&
            (record.goldFineness != null || record.assetLabel.contains('طلا')),
      HistoryAssetFilter.coin =>
        record.coinLines.isNotEmpty || record.assetLabel == 'سکه',
      HistoryAssetFilter.currency =>
        record.currencyCode != null && record.currencyCode != 'TOMAN',
      HistoryAssetFilter.cash =>
        record.assetLabel == 'وجه نقد' || record.currencyCode == 'TOMAN',
    };

bool _historyIsOverdue(AppRecord record, DateTime now) =>
    dueDateTimeFromJalali(record.date, record.time).isBefore(now);

int _compareHistoryNewestFirst(AppRecord a, AppRecord b) {
  final result = _historyTimestamp(b).compareTo(_historyTimestamp(a));
  if (result != 0) return result;
  return b.id.compareTo(a.id);
}

DateTime _historyTimestamp(AppRecord record) {
  if (record.calendarAt != null) return record.calendarAt!.toLocal();
  final gregorian = record.date.toGregorian();
  return DateTime(
    gregorian.year,
    gregorian.month,
    gregorian.day,
    record.time?.hour ?? 0,
    record.time?.minute ?? 0,
  );
}

String _normalizeHistoryQuery(String value) =>
    value.trim().toLowerCase().replaceAll('ي', 'ی').replaceAll('ك', 'ک');

class _HistoryAdvancedFilterSheet extends StatefulWidget {
  const _HistoryAdvancedFilterSheet({
    required this.initial,
    required this.people,
  });

  final HistoryAdvancedFilters initial;
  final List<AppPerson> people;

  @override
  State<_HistoryAdvancedFilterSheet> createState() =>
      _HistoryAdvancedFilterSheetState();
}

class _HistoryAdvancedFilterSheetState
    extends State<_HistoryAdvancedFilterSheet> {
  late HistoryAdvancedFilters _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('فیلترهای پیشرفته', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            DropdownButtonFormField<HistoryStatusFilter>(
              key: const ValueKey('history-status-filter'),
              initialValue: _draft.status,
              decoration: const InputDecoration(labelText: 'وضعیت'),
              items: const [
                DropdownMenuItem(
                  value: HistoryStatusFilter.all,
                  child: Text('همه وضعیت‌ها'),
                ),
                DropdownMenuItem(
                  value: HistoryStatusFilter.recorded,
                  child: Text('ثبت شده'),
                ),
                DropdownMenuItem(
                  value: HistoryStatusFilter.pending,
                  child: Text('در انتظار'),
                ),
                DropdownMenuItem(
                  value: HistoryStatusFilter.completed,
                  child: Text('انجام شد'),
                ),
                DropdownMenuItem(
                  value: HistoryStatusFilter.overdue,
                  child: Text('عقب‌افتاده'),
                ),
                DropdownMenuItem(
                  value: HistoryStatusFilter.cancelled,
                  child: Text('لغو شده'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _draft = _draft.copyWith(status: value));
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<HistoryAssetFilter>(
              key: const ValueKey('history-asset-filter'),
              initialValue: _draft.asset,
              decoration: const InputDecoration(labelText: 'نوع دارایی'),
              items: const [
                DropdownMenuItem(
                  value: HistoryAssetFilter.all,
                  child: Text('همه دارایی‌ها'),
                ),
                DropdownMenuItem(
                  value: HistoryAssetFilter.gold,
                  child: Text('طلا'),
                ),
                DropdownMenuItem(
                  value: HistoryAssetFilter.coin,
                  child: Text('سکه'),
                ),
                DropdownMenuItem(
                  value: HistoryAssetFilter.currency,
                  child: Text('ارز'),
                ),
                DropdownMenuItem(
                  value: HistoryAssetFilter.cash,
                  child: Text('وجه نقد'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _draft = _draft.copyWith(asset: value));
                }
              },
            ),
            if (widget.people.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: const ValueKey('history-person-filter'),
                initialValue: _draft.personId,
                decoration: const InputDecoration(labelText: 'شخص'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('همه اشخاص'),
                  ),
                  ...widget.people.map(
                    (person) => DropdownMenuItem<String?>(
                      value: person.id,
                      child: Text(person.name),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _draft = _draft.copyWith(personId: value)),
              ),
            ],
            const SizedBox(height: 14),
            _dateButton(
              context,
              key: const ValueKey('history-from-date'),
              label: 'از تاریخ',
              value: _draft.from,
              onClear: _draft.from == null
                  ? null
                  : () => setState(() => _draft = _draft.copyWith(from: null)),
              onPick: () async {
                final value = await pickJalaliDate(
                  context,
                  _draft.from ?? Jalali.now(),
                );
                if (value != null) {
                  setState(() => _draft = _draft.copyWith(from: value));
                }
              },
            ),
            const SizedBox(height: 8),
            _dateButton(
              context,
              key: const ValueKey('history-to-date'),
              label: 'تا تاریخ',
              value: _draft.to,
              onClear: _draft.to == null
                  ? null
                  : () => setState(() => _draft = _draft.copyWith(to: null)),
              onPick: () async {
                final value = await pickJalaliDate(
                  context,
                  _draft.to ?? Jalali.now(),
                );
                if (value != null) {
                  setState(() => _draft = _draft.copyWith(to: value));
                }
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _draft = const HistoryAdvancedFilters()),
                    child: const Text('پاک کردن'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('history-apply-filters'),
                    onPressed: () {
                      if (_draft.from != null &&
                          _draft.to != null &&
                          _draft.from!.compareTo(_draft.to!) > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('بازه تاریخ معتبر نیست.'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context, _draft);
                    },
                    child: const Text('اعمال فیلتر'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateButton(
    BuildContext context, {
    required Key key,
    required String label,
    required Jalali? value,
    required VoidCallback? onClear,
    required VoidCallback onPick,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: onPick,
      style: OutlinedButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null ? label : '$label: ${formatJalaliDate(value)}',
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(CupertinoIcons.xmark_circle, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            ),
          const Icon(CupertinoIcons.calendar, size: 18),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    super.key,
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
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                key: ValueKey('history-chevron-${record.id}'),
                width: 36,
                height: 72,
                child: const Center(
                  child: Icon(CupertinoIcons.chevron_left, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                key: ValueKey('history-main-${record.id}'),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: Text(
                              personName,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _OperationPill(record: record),
                        ],
                      ),
                      const SizedBox(height: 5),
                      _assetSummary(context),
                      if ((record.note ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          record.note!.trim(),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 5),
                      Wrap(
                        textDirection: TextDirection.rtl,
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatJalaliDate(record.date),
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            record.timeLabel(),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (record.type == RecordType.settlement)
                            _SettlementStatusLabel(record: record),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _assetSummary(BuildContext context) {
    final theme = Theme.of(context);
    final summary = recordAssetSummary(record);
    final foreignCurrency =
        record.currencyCode != null && record.currencyCode != 'TOMAN';
    return Align(
      alignment: Alignment.centerRight,
      child: Directionality(
        textDirection: foreignCurrency ? TextDirection.ltr : TextDirection.rtl,
        child: Text(
          summary,
          textAlign: foreignCurrency ? TextAlign.left : TextAlign.right,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        record.operationDisplayLabel,
        style: theme.textTheme.bodySmall?.copyWith(
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
    final color = switch (record.status) {
      SettlementStatus.completed => const Color(0xFF2F7D4C),
      SettlementStatus.cancelled => Theme.of(context).colorScheme.error,
      SettlementStatus.open => Theme.of(context).textTheme.bodyMedium?.color,
    };
    return Text(
      record.statusLabel(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({
    required this.hasQuery,
    required this.hasFilters,
    this.onClear,
  });

  final bool hasQuery;
  final bool hasFilters;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final title = hasQuery
        ? 'موردی پیدا نشد'
        : hasFilters
        ? 'موردی با این فیلترها پیدا نشد'
        : 'هنوز سابقه‌ای ثبت نشده';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.clock, size: 32),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (onClear != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onClear,
                child: const Text('پاک کردن فیلترها'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
