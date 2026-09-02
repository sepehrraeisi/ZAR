import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_core.dart';

class RepositorySettlementActionSheet extends StatelessWidget {
  const RepositorySettlementActionSheet({
    super.key,
    required this.record,
    required this.personName,
    required this.reminderSummary,
    required this.onComplete,
    required this.onEdit,
    required this.onReschedule,
    required this.onEditReminders,
    required this.onSnooze,
    required this.onCancel,
  });

  final AppRecord record;
  final String personName;
  final String reminderSummary;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onReschedule;
  final VoidCallback onEditReminders;
  final VoidCallback onSnooze;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = record.status == SettlementStatus.open;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.operationLabel, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 3),
                      Text(personName, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                _StatusPill(record: record),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('دارایی', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  _assetLine(context),
                  if (record.coinLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...record.coinLines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${toPersianDigits(line.quantity.toString())} × ${line.name}${line.weightGrams == null ? '' : ' • ${toPersianDigits(line.weightGrams!)} گرم'}${line.fineness == null ? '' : ' • عیار ${toPersianDigits(line.fineness!)}'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                  const Divider(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _Meta(icon: CupertinoIcons.calendar, text: formatJalaliDate(record.date)),
                      _Meta(icon: CupertinoIcons.clock, text: record.timeLabel(), ltr: true),
                    ],
                  ),
                  if (isOpen) ...[
                    const SizedBox(height: 10),
                    _Meta(icon: CupertinoIcons.bell, text: reminderSummary),
                  ],
                ],
              ),
            ),
            if (isOpen) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onComplete,
                icon: const Icon(CupertinoIcons.check_mark_circled, size: 19),
                label: const Text('انجام شد'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (record.coinLines.isEmpty) ...[
                    Expanded(child: _secondary(context, 'ویرایش', CupertinoIcons.pencil, onEdit)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: _secondary(context, 'زمان‌بندی', CupertinoIcons.calendar, onReschedule)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _secondary(context, 'یادآوری‌ها', CupertinoIcons.bell, onEditReminders)),
                  const SizedBox(width: 8),
                  Expanded(child: _secondary(context, 'بعداً', CupertinoIcons.moon_zzz, onSnooze)),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onCancel,
                icon: Icon(CupertinoIcons.xmark_circle, size: 18, color: theme.colorScheme.error),
                label: Text('لغو این تعهد', style: TextStyle(color: theme.colorScheme.error)),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'این تسویه بسته شده و فقط برای مشاهده در سوابق نمایش داده می‌شود.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assetLine(BuildContext context) {
    final theme = Theme.of(context);
    if (record.coinLines.isNotEmpty) {
      final total = record.coinLines.fold<int>(0, (sum, line) => sum + line.quantity);
      return Text('${toPersianDigits(total.toString())} عدد سکه', style: theme.textTheme.titleMedium);
    }
    return Wrap(
      spacing: 7,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AmountText(record.amountDisplay),
        Text(record.assetLabel, style: theme.textTheme.bodyLarge),
        if (record.goldFineness != null)
          Text('عیار ${toPersianDigits(record.goldFineness!)}', style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _secondary(BuildContext context, String text, IconData icon, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(text, overflow: TextOverflow.ellipsis),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.record});
  final AppRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (record.status) {
      SettlementStatus.open => theme.colorScheme.primary,
      SettlementStatus.completed => const Color(0xFF2F7D4C),
      SettlementStatus.cancelled => theme.colorScheme.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        record.statusLabel(),
        style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.ltr = false});
  final IconData icon;
  final String text;
  final bool ltr;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).textTheme.bodyMedium?.color),
          const SizedBox(width: 5),
          Directionality(
            textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      );
}
