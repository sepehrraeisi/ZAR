import 'package:flutter/material.dart';

import '../../app_core.dart';

class OperationalPendingScreen extends StatelessWidget {
  const OperationalPendingScreen({
    super.key,
    required this.title,
    required this.records,
    required this.personName,
    required this.onOpenRecord,
    this.overdueRecordIds = const <String>{},
  });

  final String title;
  final List<AppRecord> records;
  final String Function(String personId) personName;
  final ValueChanged<AppRecord> onOpenRecord;
  final Set<String> overdueRecordIds;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: records.isEmpty
            ? const _PendingEmptyState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final record = records[index];
                  return _PendingRecordCard(
                    record: record,
                    personName: personName(record.personId),
                    overdue: overdueRecordIds.contains(record.id),
                    onTap: () => onOpenRecord(record),
                  );
                },
              ),
      );
}

class _PendingRecordCard extends StatelessWidget {
  const _PendingRecordCard({
    required this.record,
    required this.personName,
    required this.overdue,
    required this.onTap,
  });

  final AppRecord record;
  final String personName;
  final bool overdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: overdue
              ? error.withValues(alpha: 0.42)
              : theme.dividerColor,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.operationLabel,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          personName,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        record.timeLabel(),
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _StatusPill(overdue: overdue),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _assetSummary(record),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_left, size: 18),
                ],
              ),
              if (record.coinLines.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final line in record.coinLines.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '${toPersianDigits(line.quantity.toString())} × ${line.name}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                if (record.coinLines.length > 2)
                  Text(
                    '+ ${toPersianDigits((record.coinLines.length - 2).toString())} مورد دیگر',
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.overdue});

  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = overdue
        ? theme.colorScheme.error
        : theme.textTheme.bodyMedium?.color;
    final background = overdue
        ? theme.colorScheme.error.withValues(alpha: 0.08)
        : theme.dividerColor.withValues(alpha: 0.4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            overdue ? Icons.schedule : Icons.hourglass_top_rounded,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 5),
          Text(
            overdue ? 'عقب‌افتاده' : 'در انتظار',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingEmptyState extends StatelessWidget {
  const _PendingEmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.task_alt_rounded, size: 34),
              const SizedBox(height: 10),
              Text(
                'تعهد بازی وجود ندارد.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'موارد جدیدی که نیاز به دریافت یا تحویل داشته باشند اینجا نمایش داده می‌شوند.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
}

String _assetSummary(AppRecord record) {
  if (record.coinLines.isNotEmpty) {
    if (record.coinLines.length == 1) {
      final line = record.coinLines.single;
      return '${toPersianDigits(line.quantity.toString())} عدد ${line.name}';
    }
    return '${toPersianDigits(record.coinLines.length.toString())} نوع سکه';
  }
  if (record.assetLabel == 'وجه نقد') {
    return record.amountDisplay.contains('تومان')
        ? record.amountDisplay
        : '${record.amountDisplay} تومان';
  }
  if (record.currencyCode != null) {
    return record.amountDisplay;
  }
  if (record.goldFineness != null) {
    return '${record.amountDisplay} گرم • عیار ${toPersianDigits(record.goldFineness!)}';
  }
  return '${record.amountDisplay} ${record.assetLabel}';
}
