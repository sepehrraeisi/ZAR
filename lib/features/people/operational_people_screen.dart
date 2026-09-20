import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_core.dart';
import '../../application/customer_operational_balance_projector.dart';
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

class _OperationalPeopleScreenState extends State<OperationalPeopleScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final filtered = widget.people
        .where(
          (person) =>
              query.isEmpty ||
              person.name.contains(query) ||
              (person.phone ?? '').contains(query),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('اشخاص'),
        actions: [
          TextButton.icon(
            onPressed: widget.onOpenArchive,
            icon: const Icon(CupertinoIcons.archivebox, size: 17),
            label: Text(
              widget.archivedCount == 0
                  ? 'بایگانی'
                  : 'بایگانی (${toPersianDigits(widget.archivedCount.toString())})',
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'نام یا شماره تماس',
                      prefixIcon: Icon(CupertinoIcons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: widget.onAddPerson,
                  icon: const Icon(CupertinoIcons.add, size: 16),
                  label: const Text('افزودن'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                  '${toPersianDigits(filtered.length.toString())} نفر',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const _PeopleEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final person = filtered[index];
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
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.11,
                      ),
                      child: Text(
                        initial,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
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
