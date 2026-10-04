import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_core.dart';
import '../../application/customer_operational_balance_projector.dart';
import '../theme/zar_theme.dart';
import 'customer_balance_card.dart';

class OperationalPeopleScreen extends StatefulWidget {
  const OperationalPeopleScreen({
    super.key,
    required this.people,
    required this.records,
    required this.archivedCount,
    required this.onAddPerson,
    required this.onOpenPerson,
    required this.onOpenArchive,
    this.balanceFor,
  });

  final List<AppPerson> people;
  final List<AppRecord> records;
  final int archivedCount;
  final VoidCallback onAddPerson;
  final ValueChanged<AppPerson> onOpenPerson;
  final VoidCallback onOpenArchive;
  final ZarCustomerOperationalBalance Function(String)? balanceFor;

  @override
  State<OperationalPeopleScreen> createState() =>
      _OperationalPeopleScreenState();
}

enum _PeopleSort { lastActivity, name, receivable, payable }

extension _PeopleSortLabel on _PeopleSort {
  String get label => switch (this) {
    _PeopleSort.lastActivity => 'آخرین فعالیت',
    _PeopleSort.name => 'نام (الفبا)',
    _PeopleSort.receivable => 'بیشترین طلب',
    _PeopleSort.payable => 'بیشترین بدهی',
  };
}

class _OperationalPeopleScreenState extends State<OperationalPeopleScreen> {
  String _query = '';
  String _filter = 'all';
  _PeopleSort _sort = _PeopleSort.lastActivity;

  static const _avatarPalette = [
    (Color(0xFFF7E4C6), Color(0xFF7F5600)),
    (Color(0xFFDDF2E6), Color(0xFF1F7A50)),
    (Color(0xFFFBE3E0), Color(0xFFB3261E)),
    (Color(0xFFE5E1F5), Color(0xFF4A4380)),
    (Color(0xFFDCEAF7), Color(0xFF2E5C8A)),
  ];

  ZarCustomerOperationalBalance? _balanceOf(AppPerson person) =>
      widget.balanceFor?.call(person.id);

  String? _netStatusLabel(AppPerson person) {
    final b = _balanceOf(person);
    if (b == null) return null;
    final net = b.receivableToman - b.payableToman;
    final hasAssetBuckets =
        b.receivableAssetBuckets.isNotEmpty || b.payableAssetBuckets.isNotEmpty;
    if (net == BigInt.zero && !hasAssetBuckets) return 'تسویه';
    if (net > BigInt.zero) return 'طلبکار';
    if (net < BigInt.zero) return 'بدهکار';
    return hasAssetBuckets ? 'مانده ارزی/طلایی' : 'تسویه';
  }

  bool _matchesFilter(AppPerson person) {
    switch (_filter) {
      case 'receivable':
        return _netStatusLabel(person) == 'طلبکار' ||
            _netStatusLabel(person) == 'مانده ارزی/طلایی' &&
                (_balanceOf(person)?.receivableAssetBuckets.isNotEmpty ?? false);
      case 'payable':
        return _netStatusLabel(person) == 'بدهکار';
      case 'settled':
        return _netStatusLabel(person) == 'تسویه';
      default:
        return true;
    }
  }

  int _countFilter(String filter) {
    final previous = _filter;
    _filter = filter;
    try {
      return widget.people.where(_matchesFilter).length;
    } finally {
      _filter = previous;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final filtered = widget.people
        .where(
          (person) =>
              (query.isEmpty ||
                  person.name.contains(query) ||
                  (person.phone ?? '').contains(query)) &&
              _matchesFilter(person),
        )
        .toList(growable: false);

    final sorted = filtered.toList(growable: false)..sort(_comparePeople);
    final sortLabel = _sort.label;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اشخاص'),
        actions: [
          IconButton(
            key: const ValueKey('people-sort-button'),
            tooltip: 'مرتب‌سازی',
            icon: const Icon(CupertinoIcons.sort_down),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (sheetContext) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final sort in _PeopleSort.values)
                      ListTile(
                        leading: const Icon(CupertinoIcons.sort_down),
                        title: Text(sort.label),
                        trailing: sort == _sort
                            ? const Icon(CupertinoIcons.check_mark)
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          setState(() => _sort = sort);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            key: const ValueKey('people-more-button'),
            tooltip: 'گزینه‌های بیشتر',
            onSelected: (value) {
              if (value == 'archive') widget.onOpenArchive();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'archive',
                child: Text('بایگانی'),
              ),
              const PopupMenuItem(
                value: 'import',
                enabled: false,
                child: Text('ورود از مخاطبین'),
              ),
              const PopupMenuItem(
                value: 'export',
                enabled: false,
                child: Text('خروجی فهرست اشخاص'),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('people-add-fab'),
        heroTag: 'people-add-person',
        onPressed: widget.onAddPerson,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(CupertinoIcons.person_add),
        label: const Text('شخص جدید'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'جستجوی نام یا شماره…',
                prefixIcon: const Icon(CupertinoIcons.search),
                suffixIcon: IconButton(
                  tooltip: 'اسکن QR',
                  icon: const Icon(CupertinoIcons.qrcode_viewfinder),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('اسکن QR در نسخه بعدی فعال می‌شود.')),
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final (label, value) in const [
                  ('همه', 'all'),
                  ('طلبکاران', 'receivable'),
                  ('بدهکاران', 'payable'),
                  ('تسویه‌شده', 'settled'),
                ] ) ...[
                  FilterChip(
                    label: Text('$label ${toPersianDigits(_countFilter(value).toString())}'),
                    selected: _filter == value,
                    showCheckmark: false,
                    onSelected: (v) => setState(() => _filter = v ? value : 'all'),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'مشتری‌ها و اشخاص',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${toPersianDigits(filtered.length.toString())} نفر · $sortLabel',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: sorted.isEmpty
                ? const _PeopleEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final person = sorted[index];
                      final open = widget.records
                          .where(
                            (record) =>
                                record.personId == person.id &&
                                record.isObligation &&
                                record.status == SettlementStatus.open,
                          )
                          .length;
                      final deals = widget.records
                          .where(
                            (record) =>
                                record.personId == person.id &&
                                record.type == RecordType.deal,
                          )
                          .length;
                      final last = _lastActivity(person.id);
                      return _PersonCard(
                        person: person,
                        balance: widget.balanceFor?.call(person.id),
                        openCount: open,
                        dealCount: deals,
                        lastActivity: last,
                        onTap: () => widget.onOpenPerson(person),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  AppRecord? _lastActivity(String personId) {
    final items = widget.records
        .where((record) => record.personId == personId)
        .toList(growable: false);
    if (items.isEmpty) return null;
    items.sort((a, b) {
      final date = b.date.compareTo(a.date);
      if (date != 0) return date;
      final aMinutes = (a.time?.hour ?? -1) * 60 + (a.time?.minute ?? 0);
      final bMinutes = (b.time?.hour ?? -1) * 60 + (b.time?.minute ?? 0);
      return bMinutes.compareTo(aMinutes);
    });
    return items.first;
  }

  int _comparePeople(AppPerson a, AppPerson b) {
    switch (_sort) {
      case _PeopleSort.name:
        return a.name.compareTo(b.name);
      case _PeopleSort.lastActivity:
        final aLast = _lastActivity(a.id);
        final bLast = _lastActivity(b.id);
        if (aLast == null && bLast == null) return 0;
        if (aLast == null) return 1;
        if (bLast == null) return -1;
        final date = bLast.date.compareTo(aLast.date);
        if (date != 0) return date;
        final aMinutes = (aLast.time?.hour ?? -1) * 60 + (aLast.time?.minute ?? 0);
        final bMinutes = (bLast.time?.hour ?? -1) * 60 + (bLast.time?.minute ?? 0);
        return bMinutes.compareTo(aMinutes);
      case _PeopleSort.receivable:
      case _PeopleSort.payable:
        int netOf(AppPerson person) {
          final balance = widget.balanceFor?.call(person.id);
          if (balance == null) return 0;
          final net = balance.receivableToman - balance.payableToman;
          return _sort == _PeopleSort.receivable
              ? net > BigInt.zero ? net.toInt() : -1
              : net < BigInt.zero ? -net.toInt() : -1;
        }
        return netOf(b).compareTo(netOf(a));
    }
  }
}

(Color, Color) _avatarColors(String name) {
  var hash = 0;
  for (final code in name.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return _OperationalPeopleScreenState._avatarPalette[
      hash % _OperationalPeopleScreenState._avatarPalette.length];
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.openCount,
    required this.dealCount,
    required this.lastActivity,
    this.balance,
    required this.onTap,
  });

  final AppPerson person;
  final int openCount;
  final int dealCount;
  final AppRecord? lastActivity;
  final ZarCustomerOperationalBalance? balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = person.name.trim().isEmpty ? '-' : person.name.trim()[0];
    final hasBalance =
        balance != null &&
        (balance!.receivableAssetBuckets.isNotEmpty ||
            balance!.payableAssetBuckets.isNotEmpty ||
            balance!.receivableToman != BigInt.zero ||
            balance!.payableToman != BigInt.zero);
    final netLabel = hasBalance && balance != null
        ? _netLabelOf(balance!)
        : null;
    final semantic = context.zarSemantic;
    final netColor = switch (netLabel) {
      'طلبکار' => semantic.positive,
      'بدهکار' => semantic.negative,
      _ => theme.textTheme.bodySmall?.color,
    };
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
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: identity on the right and disclosure on the far
                // left. Counts stay with identity so they scan as one unit.
                Row(
                  textDirection: TextDirection.rtl,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _avatarColors(person.name).$1,
                      child: Text(
                        initial,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _avatarColors(person.name).$2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((person.phone ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                person.phone!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${toPersianDigits(dealCount.toString())} معامله',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              _CountPill(
                                label: 'تعهد باز',
                                count: openCount,
                                emphasize: openCount > 0,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (netLabel != null) ...[
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            netLabel,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: netColor,
                            ),
                          ),
                          Text(
                            'مانده خالص',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(CupertinoIcons.chevron_left, size: 18),
                    ),
                  ],
                ),
                if (hasBalance) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: theme.dividerColor),
                  const SizedBox(height: 9),
                  // Financial Summary is part of the person card itself;
                  // compact mode deliberately does not add another Card.
                  CustomerBalanceCard(balance: balance!, compact: true),
                ],
                if (lastActivity != null) ...[
                  const SizedBox(height: 9),
                  Divider(height: 1, color: theme.dividerColor),
                  const SizedBox(height: 8),
                  Text(
                    _compactActivityLabel(lastActivity!),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _netLabelOf(ZarCustomerOperationalBalance b) {
    final net = b.receivableToman - b.payableToman;
    final hasAssetBuckets =
        b.receivableAssetBuckets.isNotEmpty || b.payableAssetBuckets.isNotEmpty;
    if (net == BigInt.zero && !hasAssetBuckets) return 'تسویه';
    if (net > BigInt.zero) return 'طلبکار';
    if (net < BigInt.zero) return 'بدهکار';
    return 'مانده ارزی/طلایی';
  }

  String _compactActivityLabel(AppRecord record) {
    final date =
        '${toPersianDigits(record.date.day.toString())} ${monthName(record.date.month)}';
    final time = record.time == null ? '' : '، ${record.timeLabel()}';
    return '${record.operationDisplayLabel} • $date$time';
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.count,
    this.emphasize = false,
  });

  final String label;
  final int count;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelText = '${toPersianDigits(count.toString())} $label';
    if (!emphasize) {
      return Text(
        labelText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.textTheme.bodySmall?.color,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    final color = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: emphasize
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.dividerColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        labelText,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PeopleEmptyState extends StatelessWidget {
  const _PeopleEmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.person_2, size: 34),
          const SizedBox(height: 10),
          Text(
            'شخصی پیدا نشد.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'عبارت جستجو را تغییر دهید یا شخص جدید اضافه کنید.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
