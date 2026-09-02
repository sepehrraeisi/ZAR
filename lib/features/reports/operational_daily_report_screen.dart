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

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final jalali = Jalali.fromDateTime(report.day);
    return Scaffold(
      appBar: AppBar(title: const Text('گزارش روزانه')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                            const Text('روز انتخاب‌شده'),
                            const SizedBox(height: 4),
                            Text(
                              formatJalaliDate(jalali),
                              style: Theme.of(context).textTheme.titleMedium,
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
          ),
          const SizedBox(height: 12),
          _summary(report),
          const SizedBox(height: 16),
          _section('خریدها', report.buyDealIds, emptyText: 'خریدی ثبت نشده است.'),
          _section('فروش‌ها', report.sellDealIds, emptyText: 'فروشی ثبت نشده است.'),
          _section(
            'دریافت‌های انجام‌شده',
            report.completedReceiveIds,
            emptyText: 'دریافت انجام‌شده‌ای ثبت نشده است.',
          ),
          _section(
            'تحویل‌های انجام‌شده',
            report.completedDeliverIds,
            emptyText: 'تحویل انجام‌شده‌ای ثبت نشده است.',
          ),
          _section(
            'تعهدهای همان روز',
            report.openDueIds,
            emptyText: 'تعهد بازی برای این روز وجود ندارد.',
          ),
          if (report.overdueOpenIds.isNotEmpty)
            _section(
              'عقب‌افتاده‌ها',
              report.overdueOpenIds,
              emptyText: '',
              emphasize: true,
            ),
        ],
      ),
    );
  }

  Widget _summary(ZarDailyOperationalReport report) {
    return Row(
      children: [
        Expanded(child: _metric('خرید', report.buyDealIds.length)),
        const SizedBox(width: 8),
        Expanded(child: _metric('فروش', report.sellDealIds.length)),
        const SizedBox(width: 8),
        Expanded(
          child: _metric('دریافت/تحویل', report.completedMovementCount),
        ),
      ],
    );
  }

  Widget _metric(String label, int value) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            children: [
              Text(
                toPersianDigits(value.toString()),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9A6700),
                ),
              ),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _section(
    String title,
    List<String> ids, {
    required String emptyText,
    bool emphasize = false,
  }) {
    final records = ids.map((id) => _recordsById[id]).whereType<AppRecord>().toList();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: emphasize
              ? const Color(0xFFBF6A45)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (records.isEmpty)
              Text(emptyText)
            else
              for (var index = 0; index < records.length; index++) ...[
                _recordRow(records[index]),
                if (index != records.length - 1) const Divider(height: 1),
              ],
          ],
        ),
      ),
    );
  }

  Widget _recordRow(AppRecord record) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onOpenRecord(record),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.operationLabel} • ${widget.personName(record.personId)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${record.assetLabel} • ${toPersianDigits(record.amountDisplay)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(record.timeLabel()),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left, size: 18),
            ],
          ),
        ),
      );
}
