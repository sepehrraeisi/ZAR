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
    final isOpen = record.status == SettlementStatus.open;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${record.operationLabel} • $personName',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  record.assetLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                AmountText(record.amountDisplay),
                if (record.currencyCode != null) ...[
                  const SizedBox(width: 8),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      record.currencyCode!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(
                  formatJalaliDate(record.date),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  record.timeLabel(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  record.statusLabel(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isOpen
                        ? null
                        : record.status == SettlementStatus.completed
                        ? const Color(0xFF2F7D4C)
                        : const Color(0xFF9D3636),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (isOpen) ...[
              const SizedBox(height: 4),
              Text(
                reminderSummary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              _action(
                context,
                'انجام شد',
                CupertinoIcons.check_mark_circled,
                onComplete,
              ),
              _action(context, 'ویرایش', CupertinoIcons.pencil, onEdit),
              _action(
                context,
                'زمان‌بندی مجدد',
                CupertinoIcons.calendar,
                onReschedule,
              ),
              _action(
                context,
                'مدیریت یادآوری‌ها',
                CupertinoIcons.bell,
                onEditReminders,
              ),
              _action(
                context,
                'یادآوری بعداً',
                CupertinoIcons.moon_zzz,
                onSnooze,
              ),
              _action(
                context,
                'لغو',
                CupertinoIcons.xmark_circle,
                onCancel,
                destructive: true,
              ),
            ] else ...[
              const SizedBox(height: 14),
              Text(
                'این تسویه بسته شده و فقط برای مشاهده در سوابق نمایش داده می‌شود.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: destructive ? Colors.red : null),
      title: Text(
        text,
        style: TextStyle(color: destructive ? Colors.red : null),
      ),
      onTap: onTap,
    );
  }
}
