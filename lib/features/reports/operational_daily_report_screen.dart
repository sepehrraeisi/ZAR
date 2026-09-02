import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../app_core.dart';
import '../../application/operational_daily_report_projector.dart';
import '../../domain/zar_domain_models.dart';

class OperationalDailyReportScreen extends StatefulWidget {
  const OperationalDailyReportScreen({
    super.key,
    required this.deals,
    required this.settlements,
    required this.records,
    required this.personName,
    required this.onOpenRecord,
    this.initialDay,
  });

  final List<ZarDeal> deals;
  final List<ZarSettlement> settlements;
  final List<AppRecord> records;
  final String Function(String personId) personName;
  final ValueChanged<AppRecord> onOpenRecord;
  final DateTime? initialDay;

  @override
  State<OperationalDailyReportScreen> createState() =>
      _OperationalDailyReportScreenState();
}

class _OperationalDailyReportScreenState
    extends State<OperationalDailyReportScreen> {
  static const _projector = ZarOperationalDailyReportProjector();
  late DateTime _selectedDay = widget.initialDay ?? DateTime.now();

  Map<String, AppRecord> get _recordsById => {
        for (final record in widget.records) record.id: record,
      };

  ZarDailyOperationalReport get _report => _projector.project(
        deals: widget.deals,
        settlements: widget.settlements,
        selectedDay: _selectedDay,
      );

  Future<void> _pickDay() async {
    final picked = await pickJalaliDate(
      context,
      Jalali.fromDateTime(_selectedDay),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedDay = picked.toDateTime());
  }

  void _moveDay(int days) {
    setState(() => _selectedDay = _selectedDay.add(Duration(days: days)));
  }

  void _goToday() => setState(() => _selectedDay = DateTime.now());

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final jalali = Jalali.fromDateTime(report.day);
    return Scaffold(
      appBar: AppBar(title: const Text('گزارش روزانه')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _dayHeader(jalali),
          const SizedBox(height: 12),
          _summary(report),
          const SizedBox(height: 22),
          _sectionHeader('نیازمند اقدام', report.actionCount),
          const SizedBox(height: 8),
          if (report.overdueOpenIds.isEmpty && report.openDueIds.isEmpty)
            const _DailyEmptyState(
              icon: Icons.check_circle_outline,
              text: 'برای این روز تعهد بازی ثبت نشده است.',
            )
          else ...[
            if (report.overdueOpenIds.isNotEmpty)
              _section(
                'عقب‌افتاده',
                report.overdueOpenIds,
                emptyText: '',
                emphasize: true,
              ),
            if (report.openDueIds.isNotEmpty)
              _section(
                'موعد این روز',
                report.openDueIds,
                emptyText: '',
              ),
          ],
          const SizedBox(height: 22),
          _sectionHeader('خرید و فروش', report.dealCount),
          const SizedBox(height: 8),
          if (report.buyDealIds.isEmpty && report.sellDealIds.isEmpty)
            const _DailyEmptyState(
              icon: Icons.swap_horiz,
              text: 'خرید یا فروشی در این روز ثبت نشده است.',
            )
          else ...[
            if (report.buyDealIds.isNotEmpty)
              _section('خرید', report.buyDealIds, emptyText: ''),
            if (report.sellDealIds.isNotEmpty)
              _section('فروش', report.sellDealIds, emptyText: ''),
          ],
          const SizedBox(height: 22),
          _sectionHeader(
            'دریافت و تحویل انجام‌شده',
            report.completedMovementCount,
          ),
          const SizedBox(height: 8),
          if (report.completedReceiveIds.isEmpty &&
              report.completedDeliverIds.isEmpty)
            const _DailyEmptyState(
              icon: Icons.inventory_2_outlined,
              text: 'حرکت تکمیل‌شده‌ای در این روز ثبت نشده است.',
            )
          else ...[
            if (report.completedReceiveIds.isNotEmpty)
              _section(
                'دریافت',
                report.completedReceiveIds,
                emptyText: '',
              ),
            if (report.completedDeliverIds.isNotEmpty)
              _section(
                'تحویل',
                report.completedDeliverIds,
                emptyText: '',
              ),
          ],
        ],
      ),
    );
  }

  Widget _dayHeader(Jalali jalali) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'روز قبل',
                onPressed: () => _moveDay(-1),
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickDay,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          formatJalaliDate(jalali),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        TextButton(
                          onPressed: _goToday,
                          child: const Text('امروز'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'روز بعد',
                onPressed: () => _moveDay(1),
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
      );

  Widget _summary(ZarDailyOperationalReport report) => Row(
        children: [
          Expanded(child: _metric('اقدام', report.actionCount)),
          const SizedBox(width: 8),
          Expanded(child: _metric('معامله', report.dealCount)),
          const SizedBox(width: 8),
          Expanded(
            child: _metric('انجام‌شده', report.completedMovementCount),
          ),
        ],
      );

  Widget _metric(String label, int value) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            children: [
              Text(
                toPersianDigits(value.toString()),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );

  Widget _sectionHeader(String title, int count) => Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(
            toPersianDigits(count.toString()),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );

  Widget _section(
    String title,
    List<String> ids, {
    required String emptyText,
    bool emphasize = false,
  }) {
    final records = ids
        .map((id) => _recordsById[id])
        .whereType<AppRecord>()
        .toList(growable: false);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: emphasize
              ? Theme.of(context).colorScheme.error.withOpacity(0.45)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (emphasize) ...[
                  Icon(
                    Icons.schedule,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  toPersianDigits(records.length.toString()),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (records.isEmpty)
              Text(emptyText)
            else
              for (var index = 0; index < records.length; index++) ...[
                _recordRow(records[index], overdue: emphasize),
                if (index != records.length - 1) const Divider(height: 1),
              ],
          ],
        ),
      ),
    );
  }

  Widget _recordRow(AppRecord record, {bool overdue = false}) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onOpenRecord(record),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.operationLabel} • ${widget.personName(record.personId)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.assetLabel} • ${toPersianDigits(record.amountDisplay)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    record.timeLabel(),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (overdue) ...[
                    const SizedBox(height: 4),
                    Text(
                      'عقب‌افتاده',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_left, size: 18),
            ],
          ),
        ),
      );
}

class _DailyEmptyState extends StatelessWidget {
  const _DailyEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
}
