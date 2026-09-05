import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../domain/zar_reminder_plan.dart';

/// Persian-first editor for the persistent reminder intent attached to one
/// settlement. This widget edits business data only; native notification
/// scheduling must happen after the returned plan is successfully persisted.
class ReminderPlanEditorSheet extends StatefulWidget {
  const ReminderPlanEditorSheet({
    super.key,
    required this.initialPlan,
    required this.onPickCustomTime,
  });

  final ZarReminderPlan initialPlan;
  final Future<DateTime?> Function() onPickCustomTime;

  @override
  State<ReminderPlanEditorSheet> createState() =>
      _ReminderPlanEditorSheetState();
}

class _ReminderPlanEditorSheetState extends State<ReminderPlanEditorSheet> {
  static const _presets = <int, String>{
    15: '۱۵ دقیقه قبل',
    30: '۳۰ دقیقه قبل',
    60: '۱ ساعت قبل',
    180: '۳ ساعت قبل',
    1440: '۱ روز قبل',
  };

  late ZarReminderPlan _plan = widget.initialPlan;

  bool _hasOffset(int minutes) => _plan.rules.any(
        (rule) =>
            rule.type == ZarReminderRuleType.offset &&
            rule.minutesBefore == minutes &&
            rule.enabled,
      );

  void _toggleOffset(int minutes) {
    setState(() {
      _plan = _hasOffset(minutes)
          ? _plan.withoutOffset(minutes)
          : _plan.withOffset(minutes);
    });
  }

  Future<void> _addCustom() async {
    final picked = await widget.onPickCustomTime();
    if (!mounted || picked == null) return;
    setState(() => _plan = _plan.withCustom(picked.toUtc()));
  }

  @override
  Widget build(BuildContext context) {
    final customRules = _plan.rules
        .where((rule) => rule.type == ZarReminderRuleType.custom)
        .toList(growable: false);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 16),
              Text(
                'یادآوری‌های این تعهد',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'می‌توانید چند یادآوری را هم‌زمان فعال کنید.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              ..._presets.entries.map(
                (entry) => SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  value: _hasOffset(entry.key),
                  onChanged: (_) => _toggleOffset(entry.key),
                ),
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(CupertinoIcons.add_circled),
                title: const Text('افزودن یادآوری سفارشی'),
                subtitle: const Text('انتخاب تاریخ و ساعت دقیق'),
                onTap: _addCustom,
              ),
              if (customRules.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...customRules.map(
                  (rule) => _CustomReminderRow(
                    rule: rule,
                    onDelete: () => setState(
                      () => _plan = _plan.withoutRule(rule.id),
                    ),
                  ),
                ),
              ],
              if (_plan.snoozedUntil != null) ...[
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(CupertinoIcons.moon_zzz),
                  title: const Text('تعویق فعلی'),
                  subtitle: Text(_persianDateTime(_plan.snoozedUntil!)),
                  trailing: TextButton(
                    onPressed: () => setState(
                      () => _plan = _plan.copyWith(clearSnooze: true),
                    ),
                    child: const Text('حذف تعویق'),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _plan.isEmpty
                          ? null
                          : () => setState(
                                () => _plan = const ZarReminderPlan(),
                              ),
                      child: const Text('حذف همه'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_plan),
                      child: const Text('ذخیره یادآوری‌ها'),
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
}

class _CustomReminderRow extends StatelessWidget {
  const _CustomReminderRow({required this.rule, required this.onDelete});

  final ZarReminderRule rule;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(CupertinoIcons.clock),
      title: const Text('یادآوری سفارشی'),
      subtitle: Text(_persianDateTime(rule.customAt!)),
      trailing: IconButton(
        tooltip: 'حذف',
        onPressed: onDelete,
        icon: const Icon(CupertinoIcons.trash),
      ),
    );
  }
}

String _persianDateTime(DateTime value) {
  final local = value.toLocal();
  final jalali = Jalali.fromDateTime(local);
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_digits(jalali.year)}/${_digits(jalali.month)}/${_digits(jalali.day)} • ${_digits(hour)}:${_digits(minute)}';
}

String _digits(Object value) {
  const latin = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var result = value.toString();
  for (var i = 0; i < latin.length; i++) {
    result = result.replaceAll(latin[i], persian[i]);
  }
  return result;
}
