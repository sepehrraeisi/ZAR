import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../app_core.dart';
import '../../application/operational_daily_report_projector.dart';
import '../../domain/zar_domain_models.dart';
import '../../widgets/zar_amount_display.dart';

/// Read-only operational report for one Jalali day.
///
/// Domain state is still owned by the repository-backed store. The optional
/// builders/listenable let this screen refresh in place after a mutation from
/// a detail sheet without introducing another mutable presentation state.
class OperationalDailyReportScreen extends StatefulWidget {
  const OperationalDailyReportScreen({
    super.key,
    required this.deals,
    required this.settlements,
    required this.records,
    required this.personName,
    required this.onOpenRecord,
    this.initialDay,
    this.stateListenable,
    this.dealsBuilder,
    this.settlementsBuilder,
    this.recordsBuilder,
    this.clock,
  });

  final List<ZarDeal> deals;
  final List<ZarSettlement> settlements;
  final List<AppRecord> records;
  final String Function(String personId) personName;
  final ValueChanged<AppRecord> onOpenRecord;
  final DateTime? initialDay;

  /// When supplied, the report derives its inputs on every store notification.
  final Listenable? stateListenable;
  final List<ZarDeal> Function()? dealsBuilder;
  final List<ZarSettlement> Function()? settlementsBuilder;
  final List<AppRecord> Function()? recordsBuilder;
  final DateTime Function()? clock;

  @override
  State<OperationalDailyReportScreen> createState() =>
      _OperationalDailyReportScreenState();
}

class _OperationalDailyReportScreenState
    extends State<OperationalDailyReportScreen> {
  static const _projector = ZarOperationalDailyReportProjector();
  late DateTime _selectedDay = (widget.initialDay ?? _now()).toLocal();
  final _scrollController = ScrollController();
  final _actionKey = GlobalKey();
  final _dealsKey = GlobalKey();
  final _completedKey = GlobalKey();
  bool _showAllOverdue = false;

  DateTime _now() => (widget.clock?.call() ?? DateTime.now()).toLocal();

  List<ZarDeal> get _deals => widget.dealsBuilder?.call() ?? widget.deals;

  List<ZarSettlement> get _settlements =>
      widget.settlementsBuilder?.call() ?? widget.settlements;

  List<AppRecord> get _records =>
      widget.recordsBuilder?.call() ?? widget.records;

  Map<String, AppRecord> get _recordsById => {
    for (final record in _records) record.id: record,
  };

  ZarDailyOperationalReport _report(DateTime now) => _projector.project(
    deals: _deals,
    settlements: _settlements,
    selectedDay: _selectedDay,
    now: now,
  );

  Future<void> _pickDay() async {
    final picked = await pickJalaliDate(
      context,
      Jalali.fromDateTime(_selectedDay),
    );
    if (!mounted || picked == null) return;
    final candidate = picked.toDateTime();
    if (_dateOnly(candidate).isAfter(_dateOnly(_now()))) return;
    setState(() {
      _selectedDay = candidate;
      _showAllOverdue = false;
    });
  }

  void _moveDay(int days) {
    final candidate = _selectedDay.add(Duration(days: days));
    if (_dateOnly(candidate).isAfter(_dateOnly(_now()))) return;
    setState(() {
      _selectedDay = candidate;
      _showAllOverdue = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listenable = widget.stateListenable;
    if (listenable == null) return _buildReport(context);
    return AnimatedBuilder(
      animation: listenable,
      builder: (_, __) => _buildReport(context),
    );
  }

  Widget _buildReport(BuildContext context) {
    final now = _now();
    final report = _report(now);
    final jalali = Jalali.fromDateTime(report.day);
    final isToday = _isSameDay(report.day, now);
    return Scaffold(
      appBar: AppBar(title: const Text('گزارش روزانه')),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _dayHeader(jalali, isToday: isToday),
          const SizedBox(height: 10),
          _summary(report),
          const SizedBox(height: 18),
          KeyedSubtree(key: _actionKey, child: _actionSection(report)),
          const SizedBox(height: 18),
          KeyedSubtree(key: _dealsKey, child: _dealsSection(report)),
          const SizedBox(height: 18),
          KeyedSubtree(key: _completedKey, child: _completedSection(report)),
        ],
      ),
    );
  }

  Widget _dayHeader(Jalali jalali, {required bool isToday}) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          IconButton(
            tooltip: 'روز قبل',
            onPressed: () => _moveDay(-1),
            icon: const Icon(
              Icons.chevron_right,
              textDirection: TextDirection.ltr,
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDay,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (isToday)
                        TextSpan(
                          text: 'امروز · ',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      TextSpan(
                        text: formatJalaliDate(jalali),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'روز بعد',
            onPressed: _dateOnly(_selectedDay).isBefore(_dateOnly(_now()))
                ? () => _moveDay(1)
                : null,
            icon: const Icon(
              Icons.chevron_left,
              textDirection: TextDirection.ltr,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _summary(ZarDailyOperationalReport report) => Row(
    children: [
      Expanded(child: _metric('نیازمند اقدام', report.actionCount, _actionKey)),
      const SizedBox(width: 8),
      Expanded(child: _metric('خرید و فروش', report.dealCount, _dealsKey)),
      const SizedBox(width: 8),
      Expanded(
        child: _metric(
          'دریافت و پرداخت',
          report.completedMovementCount,
          _completedKey,
        ),
      ),
    ],
  );

  Widget _metric(String label, int value, GlobalKey targetKey) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _scrollTo(targetKey),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          children: [
            Text(
              toPersianDigits(value.toString()),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _scrollTo(GlobalKey targetKey) async {
    final target = targetKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Widget _actionSection(ZarDailyOperationalReport report) {
    final hasActions =
        report.overdueOpenIds.isNotEmpty || report.openDueIds.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('نیازمند اقدام', report.actionCount),
        const SizedBox(height: 6),
        if (!hasActions)
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
              actionDue: true,
            ),
        ],
      ],
    );
  }

  Widget _dealsSection(ZarDailyOperationalReport report) {
    final hasDeals =
        report.buyDealIds.isNotEmpty || report.sellDealIds.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('خرید و فروش', report.dealCount),
        const SizedBox(height: 6),
        if (!hasDeals)
          const _DailyEmptyState(
            icon: Icons.swap_horiz,
            text: 'موردی برای خرید یا فروش در این روز ثبت نشده است.',
          )
        else ...[
          if (report.buyDealIds.isNotEmpty)
            _section('خرید', report.buyDealIds, emptyText: ''),
          if (report.sellDealIds.isNotEmpty)
            _section('فروش', report.sellDealIds, emptyText: ''),
        ],
      ],
    );
  }

  Widget _completedSection(ZarDailyOperationalReport report) {
    final hasCompleted =
        report.completedReceiveIds.isNotEmpty ||
        report.completedDeliverIds.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('دریافت و پرداخت', report.completedMovementCount),
        const SizedBox(height: 6),
        if (!hasCompleted)
          const _DailyEmptyState(
            icon: Icons.inventory_2_outlined,
            text: 'دریافت یا پرداخت تکمیل‌شده‌ای در این روز ثبت نشده است.',
          )
        else ...[
          if (report.completedReceiveIds.isNotEmpty)
            _section('دریافت', report.completedReceiveIds, emptyText: ''),
          if (report.completedDeliverIds.isNotEmpty)
            _section('پرداخت', report.completedDeliverIds, emptyText: ''),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, int count) => Text(
    '$title · ${toPersianDigits(count.toString())}',
    style: Theme.of(context).textTheme.titleMedium,
  );

  Widget _section(
    String title,
    List<String> ids, {
    required String emptyText,
    bool emphasize = false,
    bool actionDue = false,
  }) {
    final records = ids
        .map((id) => _recordsById[id])
        .whereType<AppRecord>()
        .toList(growable: false);
    final collapsed = emphasize && !_showAllOverdue && records.length > 4;
    final visible = collapsed
        ? records.take(4).toList(growable: false)
        : records;
    final accent = emphasize
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.45)
        : Theme.of(context).dividerColor;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                if (emphasize) ...[
                  Icon(
                    Icons.schedule,
                    size: 17,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    '$title · ${toPersianDigits(ids.length.toString())}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            if (visible.isEmpty)
              Text(emptyText)
            else
              for (var index = 0; index < visible.length; index++) ...[
                _recordRow(
                  visible[index],
                  overdue: emphasize,
                  actionDue: actionDue,
                ),
                if (index != visible.length - 1) const Divider(height: 1),
              ],
            if (collapsed)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => setState(() => _showAllOverdue = true),
                  child: Text(
                    'مشاهده همه ${toPersianDigits(ids.length.toString())} مورد',
                  ),
                ),
              )
            else if (emphasize && _showAllOverdue && records.length > 4)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => setState(() => _showAllOverdue = false),
                  child: const Text('نمایش کمتر'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _recordRow(
    AppRecord record, {
    bool overdue = false,
    bool actionDue = false,
  }) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => widget.onOpenRecord(record),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _recordDetails(
              record,
              overdue: overdue,
              actionDue: actionDue,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 126, child: _recordAmount(record)),
          const SizedBox(width: 3),
          const _DailyDisclosureChevron(),
        ],
      ),
    ),
  );

  Widget _recordDetails(
    AppRecord record, {
    required bool overdue,
    required bool actionDue,
  }) {
    final secondary = overdue
        ? _overdueSummary(record)
        : _recordDateTimeLabel(record, timeOnly: actionDue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _naturalDescription(record),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          secondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: overdue
              ? Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                )
              : Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _naturalDescription(AppRecord record) {
    final person = widget.personName(record.personId);
    return switch (record.operationDisplayLabel) {
      'خرید' => 'خرید از $person',
      'فروش' => 'فروش به $person',
      'دریافت' => 'دریافت از $person',
      'پرداخت' || 'تحویل' => 'پرداخت به $person',
      final other => '$other $person',
    };
  }

  String _overdueSummary(AppRecord record) {
    final due = _recordDateTime(record);
    final now = _now();
    final dueDay = _dateOnly(due);
    final today = _dateOnly(now);
    final days = today.difference(dueDay).inDays;
    final lateness = days > 0
        ? '${toPersianDigits(days.toString())} روز عقب‌افتاده'
        : 'امروز عقب‌افتاده';
    return '$lateness · ${_recordDateTimeLabel(record)}';
  }

  String _recordDateTimeLabel(AppRecord record, {bool timeOnly = false}) {
    final date = record.date.toGregorian();
    final time = record.time;
    if (time == null) return formatJalaliDate(record.date);
    if (timeOnly) return _timeLabel(time);
    return _compactDateTime(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  String _compactDateTime(DateTime value) {
    final local = value.toLocal();
    final jalali = Jalali.fromDateTime(local);
    final currentYear = Jalali.fromDateTime(_now()).year;
    final date = jalali.year == currentYear
        ? '${toPersianDigits(jalali.day.toString())} ${monthName(jalali.month)}'
        : formatJalaliDate(jalali);
    return '$date · ${_timeLabel(TimeOfDay.fromDateTime(local))}';
  }

  String _timeLabel(TimeOfDay time) =>
      '${toPersianDigits(time.hour.toString().padLeft(2, '0'))}:${toPersianDigits(time.minute.toString().padLeft(2, '0'))}';

  DateTime _recordDateTime(AppRecord record) {
    final date = record.date.toGregorian();
    final time = record.time;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
  }

  Widget _recordAmount(AppRecord record) {
    if (record.coinLines.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in record.coinLines)
            Row(
              textDirection: TextDirection.rtl,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    line.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 58,
                  child: ZarAmountDisplay(
                    amount: toPersianDigits(line.quantity.toString()),
                    unit: 'عدد',
                    amountStyle: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    unitStyle: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
        ],
      );
    }

    final numeric =
        RegExp(
          r'[-+]?[0-9۰-۹٬,٫.]+',
        ).firstMatch(record.amountDisplay)?.group(0) ??
        toPersianNumberText(record.amountDisplay);
    final amount = toPersianNumberText(numeric);
    final unit =
        record.currencyCode ??
        (record.assetLabel == 'وجه نقد'
            ? 'تومان'
            : record.assetLabel == 'سکه'
            ? 'عدد'
            : record.assetLabel);
    final negative = amount.startsWith('-');
    return ZarAmountDisplay(
      amount: negative ? amount.substring(1) : amount,
      unit: unit,
      negative: negative,
      amountStyle: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      unitStyle: Theme.of(context).textTheme.bodySmall,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => _dateOnly(a) == _dateOnly(b);

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

class _DailyDisclosureChevron extends StatelessWidget {
  const _DailyDisclosureChevron();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.chevron_left,
    textDirection: TextDirection.ltr,
    size: 20,
  );
}

class _DailyEmptyState extends StatelessWidget {
  const _DailyEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}
