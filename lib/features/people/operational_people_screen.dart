import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_core.dart';

class OperationalPeopleScreen extends StatefulWidget {
  const OperationalPeopleScreen({
    super.key,
    required this.people,
    required this.records,
    required this.archivedCount,
    required this.onAddPerson,
    required this.onOpenPerson,
    required this.onOpenArchive,
  });

  final List<AppPerson> people;
  final List<AppRecord> records;
  final int archivedCount;
  final VoidCallback onAddPerson;
  final ValueChanged<AppPerson> onOpenPerson;
  final VoidCallback onOpenArchive;

  @override
  State<OperationalPeopleScreen> createState() => _OperationalPeopleScreenState();
}

class _OperationalPeopleScreenState extends State<OperationalPeopleScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final filtered = widget.people
        .where((person) => query.isEmpty || person.name.contains(query) || (person.phone ?? '').contains(query))
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
                FilledButton.icon(
                  onPressed: widget.onAddPerson,
                  icon: const Icon(CupertinoIcons.add, size: 16),
                  label: const Text('افزودن'),
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
                  child: Text('مشتری‌ها و اشخاص', style: Theme.of(context).textTheme.titleMedium),
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
                          .where((record) => record.personId == person.id && record.isObligation && record.status == SettlementStatus.open)
                          .length;
                      final deals = widget.records
                          .where((record) => record.personId == person.id && record.type == RecordType.deal)
                          .length;
                      final last = _lastActivity(person.id);
                      return _PersonCard(
                        person: person,
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
    final items = widget.records.where((record) => record.personId == personId).toList(growable: false);
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
    required this.onTap,
  });

  final AppPerson person;
  final int openCount;
  final int dealCount;
  final AppRecord? lastActivity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = person.name.trim().isEmpty ? '-' : person.name.trim()[0];
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
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.11),
                child: Text(
                  initial,
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                    if ((person.phone ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(person.phone!, style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _CountPill(label: 'معامله', count: dealCount),
                        _CountPill(label: 'تعهد باز', count: openCount, emphasize: openCount > 0),
                      ],
                    ),
                    if (lastActivity != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'آخرین فعالیت: ${lastActivity!.operationLabel} • ${formatJalaliDate(lastActivity!.date)}',
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.chevron_left, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.count, this.emphasize = false});

  final String label;
  final int count;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasize ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: emphasize
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.dividerColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '${toPersianDigits(count.toString())} $label',
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
              Text('شخصی پیدا نشد.', style: Theme.of(context).textTheme.titleMedium),
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
