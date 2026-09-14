import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

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
  Widget build(BuildContext context) {
    final overdueCount = records
        .where((record) => overdueRecordIds.contains(record.id))
        .length;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _PendingSummary(total: records.length, overdue: overdueCount),
          const SizedBox(height: 12),
          if (records.isEmpty)
            const _PendingEmptyState()
          else
            ...records.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PendingRecordCard(
                  record: record,
                  personName: personName(record.personId),
                  overdue: overdueRecordIds.contains(record.id),
                  onTap: () => onOpenRecord(record),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingSummary extends StatelessWidget {
  const _PendingSummary({required this.total, required this.overdue});

  final int total;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '${toPersianDigits(total.toString())} مورد · '
      '${toPersianDigits(overdue.toString())} عقب‌افتاده',
      key: const ValueKey('pending-summary'),
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.68),
        fontWeight: FontWeight.w600,
      ),
    );
  }
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
          color: overdue ? error.withValues(alpha: 0.22) : theme.dividerColor,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              child: Text(
                                record.operationDisplayLabel,
                                textAlign: TextAlign.right,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusPill(overdue: overdue),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          personName,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                textDirection: TextDirection.ltr,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    key: ValueKey('pending-chevron-target-${record.id}'),
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Directionality(
                        // This is a physical navigation affordance. Keep it
                        // isolated from the surrounding RTL tree so the
                        // glyph itself always points to the left edge.
                        textDirection: TextDirection.ltr,
                        child: Icon(
                          key: ValueKey('pending-chevron-${record.id}'),
                          Icons.chevron_left,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: _assetValue(context),
                        ),
                        if (record.coinLines.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          for (final line in record.coinLines.take(2))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '${toPersianDigits(line.quantity.toString())} × ${line.name}',
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          if (record.coinLines.length > 2)
                            Text(
                              '+ ${toPersianDigits((record.coinLines.length - 2).toString())} مورد دیگر',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodyMedium,
                            ),
                        ],
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _DueLabel(record: record),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _assetValue(BuildContext context) {
    final text = Text(
      _assetSummary(record),
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      textAlign: TextAlign.right,
    );
    if (record.currencyCode != null) {
      return Directionality(textDirection: TextDirection.ltr, child: text);
    }
    return text;
  }
}

class _DueLabel extends StatelessWidget {
  const _DueLabel({required this.record});

  final AppRecord record;

  @override
  Widget build(BuildContext context) {
    final today = Jalali.now();
    final dateLabel = isSameJalali(record.date, today)
        ? 'امروز'
        : formatJalaliDate(record.date);
    final dueText = record.time == null
        ? 'موعد: $dateLabel'
        : 'موعد: $dateLabel · ${record.timeLabel()}';
    return Text(
      dueText,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(
          context,
        ).textTheme.bodySmall?.color?.withValues(alpha: 0.72),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            'موارد جدیدی که نیاز به دریافت یا پرداخت داشته باشند اینجا نمایش داده می‌شوند.',
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
    return '${toPersianNumberText(_numericPart(record.amountDisplay))} تومان';
  }
  if (record.currencyCode != null) {
    return '${record.currencyCode} ${toPersianNumberText(_numericPart(record.amountDisplay))}';
  }
  if (record.goldFineness != null) {
    return '${toPersianNumberText(_numericPart(record.amountDisplay))} گرم طلا • عیار ${toPersianNumberText(record.goldFineness!)}';
  }
  return '${record.assetLabel} ${toPersianNumberText(_numericPart(record.amountDisplay))}';
}

String _numericPart(String value) =>
    RegExp(r'[-+]?[0-9۰-۹٬,٫.]+').firstMatch(value)?.group(0) ?? value;
