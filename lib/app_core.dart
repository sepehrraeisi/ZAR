import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'application/customer_operational_balance_projector.dart';
import 'features/people/customer_balance_card.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'features/reminders/reminder_model.dart';
import 'application/customer_position_projector.dart';
import 'domain/zar_domain_models.dart';
import 'widgets/zar_amount_display.dart';

enum RecordType { settlement, deal }

enum SettlementStatus { open, completed, cancelled }

enum HistoryFilter { all, buy, sell, receive, deliver, completed, cancelled }

class AppPerson {
  AppPerson({
    required this.id,
    required this.name,
    this.phone,
    this.note,
    this.archived = false,
  });

  final String id;
  final String name;
  final String? phone;
  final String? note;
  final bool archived;

  AppPerson copyWith({
    String? name,
    String? phone,
    String? note,
    bool? archived,
  }) {
    return AppPerson(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      archived: archived ?? this.archived,
    );
  }
}

class AppRecord {
  AppRecord({
    required this.id,
    required this.type,
    required this.operationLabel,
    required this.personId,
    required this.amountDisplay,
    required this.assetLabel,
    required this.date,
    this.currencyCode,
    this.time,
    this.status = SettlementStatus.open,
    this.note,
    this.dealId,
    this.linkedSettlementIds = const [],
    this.calendarAt,
    this.goldFineness,
    this.goldPriceReferenceFineness,
    this.goldInputWeight,
    this.goldInputUnit,
    this.goldPriceUnit,
    this.goldEquivalentWeight,
    this.goldEquivalentPrice,
    this.tomanRate,
    this.totalToman,
    this.coinLines = const [],
  });

  final String id;
  final RecordType type;
  final String operationLabel;
  // Keep legacy presentation/backup values stable; localize only at display.
  String get operationDisplayLabel =>
      operationLabel == 'تحویل' ? 'پرداخت' : operationLabel;
  final String personId;
  final String amountDisplay;
  final String assetLabel;
  final Jalali date;
  final String? currencyCode;
  final TimeOfDay? time;
  final SettlementStatus status;
  final String? note;

  /// Domain settlement linkage to the priced deal this movement belongs to.
  /// Populated by the presentation bridge; the live V2 shell derives linked
  /// settlements from it.
  final String? dealId;
  final List<String> linkedSettlementIds;

  /// Optional semantic timestamp used by Calendar projections. For deals this
  /// is the deal timestamp; for settlements it is scheduledAt while open and
  /// completedAt after completion. Legacy UI callers may omit it and fall
  /// back to [date]/[time].
  final DateTime? calendarAt;
  final String? goldFineness;
  final String? goldPriceReferenceFineness;
  final String? goldInputWeight;
  final String? goldInputUnit;
  final String? goldPriceUnit;
  final String? goldEquivalentWeight;
  final String? goldEquivalentPrice;
  final String? tomanRate;
  final int? totalToman;
  final List<AppCoinLine> coinLines;

  bool get isObligation =>
      type == RecordType.settlement &&
      (operationLabel == 'دریافت' || operationLabel == 'تحویل');

  AppRecord copyWith({
    String? operationLabel,
    String? personId,
    String? amountDisplay,
    String? assetLabel,
    Jalali? date,
    String? currencyCode,
    TimeOfDay? time,
    bool clearTime = false,
    SettlementStatus? status,
    String? note,
    String? dealId,
    DateTime? calendarAt,
    String? goldFineness,
    String? goldPriceReferenceFineness,
    String? goldInputWeight,
    String? goldInputUnit,
    String? goldPriceUnit,
    String? goldEquivalentWeight,
    String? goldEquivalentPrice,
    String? tomanRate,
    int? totalToman,
  }) {
    return AppRecord(
      id: id,
      type: type,
      operationLabel: operationLabel ?? this.operationLabel,
      personId: personId ?? this.personId,
      amountDisplay: amountDisplay ?? this.amountDisplay,
      assetLabel: assetLabel ?? this.assetLabel,
      date: date ?? this.date,
      currencyCode: currencyCode ?? this.currencyCode,
      time: clearTime ? null : (time ?? this.time),
      status: status ?? this.status,
      note: note ?? this.note,
      dealId: dealId ?? this.dealId,
      linkedSettlementIds: linkedSettlementIds,
      calendarAt: calendarAt ?? this.calendarAt,
      goldFineness: goldFineness ?? this.goldFineness,
      goldPriceReferenceFineness:
          goldPriceReferenceFineness ?? this.goldPriceReferenceFineness,
      goldInputWeight: goldInputWeight ?? this.goldInputWeight,
      goldInputUnit: goldInputUnit ?? this.goldInputUnit,
      goldPriceUnit: goldPriceUnit ?? this.goldPriceUnit,
      goldEquivalentWeight: goldEquivalentWeight ?? this.goldEquivalentWeight,
      goldEquivalentPrice: goldEquivalentPrice ?? this.goldEquivalentPrice,
      tomanRate: tomanRate ?? this.tomanRate,
      totalToman: totalToman ?? this.totalToman,
      coinLines: coinLines,
    );
  }

  String timeLabel() {
    if (time == null) return 'بدون ساعت';
    final h = toPersianDigits(time!.hour.toString().padLeft(2, '0'));
    final m = toPersianDigits(time!.minute.toString().padLeft(2, '0'));
    return '$h:$m';
  }

  String statusLabel() {
    switch (status) {
      case SettlementStatus.open:
        return 'در انتظار';
      case SettlementStatus.completed:
        return 'انجام شد';
      case SettlementStatus.cancelled:
        return 'لغو شد';
    }
  }
}

class AppCoinLine {
  const AppCoinLine({
    required this.name,
    required this.quantity,
    this.weightGrams,
    this.fineness,
    this.pricingMethod,
    this.unitPriceToman,
    this.rowTotalToman,
  });
  final String name;
  final int quantity;
  final String? weightGrams;
  final String? fineness;
  final String? pricingMethod;
  final int? unitPriceToman;
  final int? rowTotalToman;
}

class QuickAddDraft {
  QuickAddDraft({
    required this.operation,
    required this.asset,
    required this.personId,
    required this.amount,
    required this.date,
    required this.time,
    required this.reminder,
    required this.note,
    this.currencyCode,
    this.goldFineness,
    this.goldPriceReferenceFineness,
    this.goldInputUnit,
    this.goldPriceUnit,
    this.tomanRate,
    this.totalToman,
    this.coinLines = const [],
    this.coinDealPricing,
    this.coinSettlementValuation,
    this.customReminderAt,
  });

  final String operation;
  final String asset;
  final String personId;
  final String amount;
  final Jalali date;
  final TimeOfDay? time;
  final String reminder;
  final String note;
  final String? currencyCode;
  final String? goldFineness;
  final String? goldPriceReferenceFineness;
  final String? goldInputUnit;
  final String? goldPriceUnit;
  final String? tomanRate;
  final String? totalToman;
  final List<ZarCoinLine> coinLines;
  final ZarCoinDealPricing? coinDealPricing;
  final ZarCoinSettlementValuation? coinSettlementValuation;
  final DateTime? customReminderAt;
}

String formatJalaliDate(Jalali date) =>
    '${toPersianDigits(date.day.toString())} ${monthName(date.month)} ${toPersianDigits(date.year.toString())}';

String monthName(int month) {
  const months = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];
  return months[month - 1];
}

String toPersianDigits(String input) {
  const latin = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var output = input;
  for (int i = 0; i < latin.length; i++) {
    output = output.replaceAll(latin[i], persian[i]);
  }
  return output;
}

/// Localizes and groups numeric runs for display without changing stored values.
String toPersianNumberText(String input) {
  return input.replaceAllMapped(
    RegExp(r'[0-9۰-۹]+(?:[٬,][0-9۰-۹]+)*(?:[٫.][0-9۰-۹]+)?'),
    (match) {
      var raw = match.group(0)!;
      const persian = '۰۱۲۳۴۵۶۷۸۹';
      for (var index = 0; index < persian.length; index++) {
        raw = raw.replaceAll(persian[index], index.toString());
      }
      raw = raw.replaceAll('٬', '').replaceAll(',', '').replaceAll('٫', '.');
      final parts = raw.split('.');
      final whole = parts.first;
      final groups = <String>[];
      for (var end = whole.length; end > 0; end -= 3) {
        groups.insert(0, whole.substring(end < 3 ? 0 : end - 3, end));
      }
      final localized = parts.length == 1
          ? groups.join('٬')
          : '${groups.join('٬')}٫${parts.sublist(1).join()}';
      return toPersianDigits(localized);
    },
  );
}

bool isSameJalali(Jalali a, Jalali b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String phoneToEnglishDigits(String input) {
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var output = input;
  for (int i = 0; i < persian.length; i++) {
    output = output.replaceAll(persian[i], i.toString());
  }
  return output;
}

String formatAmountWithGrouping(int amount) {
  final formatter = NumberFormat('#,###');
  return toPersianDigits(formatter.format(amount));
}

class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.persianName,
    required this.shortLabel,
  });

  final String code;
  final String persianName;
  final String shortLabel;

  String get displayLabel => '$persianName — $code';
}

CurrencyOption currencyOptionFromDomain(ZarCurrencyType value) =>
    CurrencyOption(
      code: value.code,
      persianName: value.name,
      shortLabel: value.name,
    );

const List<CurrencyOption> kCurrencyOptions = [
  CurrencyOption(code: 'USD', persianName: 'دلار آمریکا', shortLabel: 'دلار'),
  CurrencyOption(code: 'EUR', persianName: 'یورو', shortLabel: 'یورو'),
  CurrencyOption(code: 'AED', persianName: 'درهم امارات', shortLabel: 'درهم'),
  CurrencyOption(code: 'TRY', persianName: 'لیر ترکیه', shortLabel: 'لیر'),
  CurrencyOption(code: 'GBP', persianName: 'پوند انگلیس', shortLabel: 'پوند'),
  CurrencyOption(
    code: 'CAD',
    persianName: 'دلار کانادا',
    shortLabel: 'دلار کانادا',
  ),
  CurrencyOption(code: 'OTHER', persianName: 'سایر', shortLabel: 'سایر'),
];

CurrencyOption? currencyByCode(String? code) {
  if (code == null) return null;
  for (final option in kCurrencyOptions) {
    if (option.code == code) return option;
  }
  return null;
}

String digitsToEnglish(String input) {
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var output = input;
  for (int i = 0; i < persian.length; i++) {
    output = output.replaceAll(persian[i], i.toString());
  }
  return output;
}

String formatCurrencyAmount(String amountInput, String currencyCode) {
  final english = digitsToEnglish(amountInput).replaceAll(',', '').trim();
  final digitsOnly = RegExp(
    r'\d+',
  ).allMatches(english).map((e) => e.group(0)!).join();
  final amount = int.tryParse(digitsOnly) ?? 0;
  final grouped = NumberFormat('#,###').format(amount);

  switch (currencyCode) {
    case 'USD':
      return '\$$grouped';
    case 'EUR':
      return '€$grouped';
    case 'GBP':
      return '£$grouped';
    case 'TRY':
      return '₺$grouped';
    case 'AED':
      return 'AED $grouped';
    case 'CAD':
      return 'CAD $grouped';
    default:
      return 'OTHER $grouped';
  }
}

class ZBottomBar extends StatelessWidget {
  const ZBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final inactive = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    Widget navItem({
      required int index,
      required IconData icon,
      required String label,
    }) {
      final selected = currentIndex == index;
      final color = selected ? active : inactive;
      return Expanded(
        child: InkWell(
          onTap: () => onTap(index),
          child: SizedBox(
            height: 62,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  navItem(index: 0, icon: CupertinoIcons.house, label: 'خانه'),
                  navItem(
                    index: 1,
                    icon: CupertinoIcons.calendar,
                    label: 'تقویم',
                  ),
                  const SizedBox(width: 76),
                  navItem(
                    index: 3,
                    icon: CupertinoIcons.person_2,
                    label: 'اشخاص',
                  ),
                  navItem(index: 4, icon: CupertinoIcons.clock, label: 'سوابق'),
                ],
              ),
              Semantics(
                button: true,
                label: 'ثبت معامله جدید',
                child: GestureDetector(
                  onTap: () => onTap(2),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: active,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: active.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.add,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.records,
    required this.personName,
    required this.onTapRecord,
    this.onSelectedDateChanged,
    this.clock,
    this.onAdd,
  });

  final List<AppRecord> records;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTapRecord;
  final ValueChanged<Jalali>? onSelectedDateChanged;
  final DateTime Function()? clock;
  final VoidCallback? onAdd;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Jalali _month = Jalali.now().withDay(1);
  Jalali _selected = Jalali.now();

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  List<_CalendarActivity> get _activities => widget.records
      .map((record) => _CalendarActivity.fromRecord(record, now: _now))
      .toList(growable: false);

  void _selectDate(Jalali date) {
    setState(() => _selected = date);
    widget.onSelectedDateChanged?.call(date);
  }

  void _moveMonth(int delta) {
    final candidate = _month.addMonths(delta);
    final day = _selected.day <= candidate.monthLength
        ? _selected.day
        : candidate.monthLength;
    setState(() {
      _month = candidate;
      _selected = candidate.withDay(day);
    });
    widget.onSelectedDateChanged?.call(_selected);
  }

  Widget _monthSection(
    BuildContext context,
    List<_CalendarActivity> activities,
  ) {
    final theme = Theme.of(context);
    final eventDays = activities.map((item) => item.date).toSet().toList();
    final overdueDays = activities
        .where((item) => item.overdue)
        .map((item) => item.date)
        .toSet()
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.ltr,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  tooltip: 'ماه قبل',
                  onPressed: () => _moveMonth(-1),
                  icon: const Icon(CupertinoIcons.chevron_left, size: 20),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${monthName(_month.month)} ${toPersianDigits(_month.year.toString())}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  tooltip: 'ماه بعد',
                  onPressed: () => _moveMonth(1),
                  icon: const Icon(CupertinoIcons.chevron_right, size: 20),
                ),
              ),
            ],
          ),
          CalendarMonthGrid(
            month: _month,
            selected: _selected,
            eventDays: eventDays,
            overdueDays: overdueDays,
            onDayTap: _selectDate,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activities = _activities;
    final selectedEvents =
        activities.where((e) => isSameJalali(e.date, _selected)).toList()
          ..sort(_compareCalendarActivities);

    return CustomScrollView(
      key: const ValueKey('calendar-scroll'),
      slivers: [
        SliverAppBar(title: const Text('تقویم'), pinned: true),
        SliverToBoxAdapter(child: _monthSection(context, activities)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _CalendarAgendaHeaderDelegate(
            selected: _selected,
            summary: _agendaSummary(selectedEvents),
          ),
        ),
        if (selectedEvents.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 34, 20, 34),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('برای این روز فعالیتی ثبت نشده'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onAdd,
                      child: const Text('ثبت جدید'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: selectedEvents.length,
            itemBuilder: (context, index) {
              final item = selectedEvents[index];
              return _CalendarAgendaRow(
                activity: item,
                personName: widget.personName(item.record.personId),
                onTap: () => widget.onTapRecord(item.record),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  String _agendaSummary(List<_CalendarActivity> selectedEvents) {
    final pending = selectedEvents
        .where(
          (item) =>
              item.record.type == RecordType.settlement &&
              item.record.status == SettlementStatus.open,
        )
        .length;
    final overdue = selectedEvents.where((item) => item.overdue).length;
    final completed = selectedEvents
        .where(
          (item) =>
              item.record.type == RecordType.settlement &&
              item.record.status == SettlementStatus.completed,
        )
        .length;
    final cancelled = selectedEvents
        .where(
          (item) =>
              item.record.type == RecordType.settlement &&
              item.record.status == SettlementStatus.cancelled,
        )
        .length;
    return <String>[
      if (selectedEvents.isNotEmpty)
        '${toPersianDigits(selectedEvents.length.toString())} مورد',
      if (pending > 0) '${toPersianDigits(pending.toString())} در انتظار',
      if (overdue > 0) '${toPersianDigits(overdue.toString())} عقب‌افتاده',
      if (completed > 0) '${toPersianDigits(completed.toString())} انجام‌شده',
      if (cancelled > 0) '${toPersianDigits(cancelled.toString())} لغوشده',
    ].join(' · ');
  }
}

class _CalendarActivity {
  const _CalendarActivity({
    required this.record,
    required this.date,
    required this.time,
    required this.sortAt,
    required this.overdue,
  });

  factory _CalendarActivity.fromRecord(
    AppRecord record, {
    required DateTime now,
  }) {
    final timestamp =
        record.calendarAt?.toLocal() ?? _fallbackTimestamp(record);
    final date = Jalali.fromDateTime(timestamp);
    final overdue =
        record.type == RecordType.settlement &&
        record.status == SettlementStatus.open &&
        timestamp.isBefore(now);
    final time = record.time == null && record.calendarAt == null
        ? null
        : TimeOfDay(hour: timestamp.hour, minute: timestamp.minute);
    return _CalendarActivity(
      record: record,
      date: date,
      time: time,
      sortAt: timestamp,
      overdue: overdue,
    );
  }

  final AppRecord record;
  final Jalali date;
  final TimeOfDay? time;
  final DateTime sortAt;
  final bool overdue;

  static DateTime _fallbackTimestamp(AppRecord record) {
    final gregorian = record.date.toGregorian();
    final due = record.type == RecordType.settlement
        ? dueDateTimeFromJalali(record.date, record.time)
        : DateTime(
            gregorian.year,
            gregorian.month,
            gregorian.day,
            record.time?.hour ?? 12,
            record.time?.minute ?? 0,
          );
    return due;
  }
}

int _compareCalendarActivities(_CalendarActivity a, _CalendarActivity b) {
  final byTime = b.sortAt.compareTo(a.sortAt);
  return byTime != 0 ? byTime : b.record.id.compareTo(a.record.id);
}

class _CalendarAgendaHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CalendarAgendaHeaderDelegate({
    required this.selected,
    required this.summary,
  });

  final Jalali selected;
  final String summary;

  @override
  double get minExtent => 76;

  @override
  double get maxExtent => 76;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('calendar-agenda-header'),
      width: double.infinity,
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'فعالیت‌های ${toPersianDigits(selected.day.toString())} ${monthName(selected.month)}',
            key: const ValueKey('calendar-agenda-title'),
            textAlign: TextAlign.right,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            summary.isEmpty ? 'برای این روز فعالیتی ثبت نشده' : summary,
            key: const ValueKey('calendar-agenda-summary'),
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CalendarAgendaHeaderDelegate oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.summary != summary;
}

class _CalendarAgendaRow extends StatelessWidget {
  const _CalendarAgendaRow({
    required this.activity,
    required this.personName,
    required this.onTap,
  });

  final _CalendarActivity activity;
  final String personName;
  final VoidCallback onTap;

  String get _statusLabel {
    if (activity.record.type == RecordType.deal) return 'ثبت شده';
    if (activity.overdue) return 'عقب‌افتاده';
    return activity.record.statusLabel();
  }

  Color _statusColor(BuildContext context) {
    if (activity.overdue ||
        activity.record.status == SettlementStatus.cancelled) {
      return const Color(0xFF9D3636);
    }
    if (activity.record.status == SettlementStatus.completed) {
      return const Color(0xFF2F7D4C);
    }
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('calendar-agenda-row-${activity.record.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
        child: Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 52,
              child: Center(
                key: ValueKey('calendar-agenda-chevron-${activity.record.id}'),
                child: Icon(
                  CupertinoIcons.chevron_left,
                  size: 18,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            SizedBox(
              key: ValueKey('calendar-agenda-meta-${activity.record.id}'),
              width: 82,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.time == null
                        ? 'بدون ساعت'
                        : _formatTime(activity.time!),
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _statusColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              key: ValueKey('calendar-agenda-info-${activity.record.id}'),
              child: Column(
                key: ValueKey(
                  'calendar-agenda-info-column-${activity.record.id}',
                ),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    activity.record.operationDisplayLabel,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    personName,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  _calendarAmount(activity.record),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) =>
      '${toPersianDigits(time.hour.toString().padLeft(2, '0'))}:${toPersianDigits(time.minute.toString().padLeft(2, '0'))}';

  Widget _calendarAmount(AppRecord record) {
    final numeric =
        RegExp(
          r'[-+]?[0-9۰-۹٬,٫.]+',
        ).firstMatch(record.amountDisplay)?.group(0) ??
        record.amountDisplay;
    if (record.coinLines.isNotEmpty) {
      return Align(
        alignment: Alignment.centerRight,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            toPersianNumberText(record.amountDisplay),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    if (record.currencyCode != null && record.currencyCode != 'TOMAN') {
      return _rightAlignedAmount(
        child: ZarAmountDisplay(
          amount: toPersianNumberText(numeric),
          unit: record.currencyCode!,
          contentAlignment: Alignment.centerRight,
          amountStyle: const TextStyle(fontWeight: FontWeight.w700),
          unitStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }
    if (record.assetLabel == 'وجه نقد' || record.currencyCode == 'TOMAN') {
      return _rightAlignedAmount(
        child: ZarAmountDisplay(
          amount: toPersianNumberText(numeric),
          unit: 'تومان',
          contentAlignment: Alignment.centerRight,
          amountStyle: const TextStyle(fontWeight: FontWeight.w700),
          unitStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }
    if (record.assetLabel == 'گرم طلا') {
      return _rightAlignedAmount(
        child: ZarAmountDisplay(
          amount: toPersianNumberText(numeric),
          unit: 'گرم طلا',
          contentAlignment: Alignment.centerRight,
          amountStyle: const TextStyle(fontWeight: FontWeight.w700),
          unitStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        toPersianNumberText(record.amountDisplay),
        style: const TextStyle(fontWeight: FontWeight.w700),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _rightAlignedAmount({required Widget child}) => Align(
    alignment: Alignment.centerRight,
    child: IntrinsicWidth(child: child),
  );
}

class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({
    super.key,
    required this.person,
    required this.records,
    required this.personName,
    required this.onTapRecord,
    required this.onEditPerson,
    required this.onArchivePerson,
    this.position = const ZarCustomerPosition.empty(),
    this.balance,
    this.ledger,
    this.onShareStatement,
    this.onShareBalanceBucket,
    this.onQuickEntry,
  });

  final AppPerson person;
  final List<AppRecord> records;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTapRecord;
  final ValueChanged<AppPerson> onEditPerson;
  final ValueChanged<String> onArchivePerson;
  final ZarCustomerPosition position;
  final ZarCustomerOperationalBalance? balance;
  final ZarCustomerLedgerProjection? ledger;
  final VoidCallback? onShareStatement;
  final ValueChanged<ZarCustomerBalanceAssetBucket>? onShareBalanceBucket;
  final VoidCallback? onQuickEntry;

  @override
  Widget build(BuildContext context) {
    final personItems =
        records.where((e) => e.personId == person.id).toList(growable: false)
          ..sort(_comparePersonRecords);
    final openItems = personItems
        .where((e) => e.status == SettlementStatus.open && e.isObligation)
        .toList(growable: false);
    final historyItems = personItems
        .where(
          (e) => e.type == RecordType.deal || e.status != SettlementStatus.open,
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('جزئیات شخص')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _personProfileHeader(context),
          const SizedBox(height: 12),
          if (balance != null) ...[
            CustomerBalanceCard(
              balance: balance!,
              onShareBucket: onShareBalanceBucket,
              onTapBucket: ledger == null
                  ? null
                  : (bucket) => _showBalanceProvenance(context, bucket),
            ),
            const SizedBox(height: 16),
          ],
          _customerCard(
            context,
            title: 'تعهدات باز',
            children: [
              if (balance == null) ...[
                _positionSide(context, 'باید از او بگیرم', position.receive),
                const SizedBox(height: 12),
                _positionSide(context, 'باید به او بدهم', position.deliver),
              ],
              const Divider(height: 24),
              if (openItems.isEmpty)
                const _ZEmptyRow(label: 'تعهد باز وجود ندارد.')
              else
                ...openItems.map(
                  (e) =>
                      _PersonRecordRow(record: e, onTap: () => onTapRecord(e)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _customerCard(
            context,
            title: 'سوابق معاملات',
            children: historyItems.isEmpty
                ? const [_ZEmptyRow(label: 'معامله یا تسویه‌ای ثبت نشده است.')]
                : historyItems
                      .map(
                        (e) => _PersonRecordRow(
                          record: e,
                          onTap: () => onTapRecord(e),
                        ),
                      )
                      .toList(growable: false),
          ),
          const SizedBox(height: 18),
          _customerCard(
            context,
            title: 'خلاصه فعالیت',
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${toPersianDigits(position.activityCount.toString())} فعالیت',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${toPersianDigits(openItems.length.toString())} تعهد باز',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _activityPill(context, 'خرید', position.buyCount),
                  _activityPill(context, 'فروش', position.sellCount),
                  _activityPill(context, 'دریافت', position.receiveCount),
                  _activityPill(context, 'پرداخت', position.deliverCount),
                ],
              ),
              const Divider(height: 20),
              Text(
                'آخرین فعالیت: ${_lastActivityLabel(position.lastActivityAt)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showBalanceProvenance(
    BuildContext context,
    ZarCustomerBalanceAssetBucket bucket,
  ) async {
    final currentLedger = ledger;
    if (currentLedger == null) return;
    final lines = currentLedger.statementFor(bucket.assetKey);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.58,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text('منشأ مانده', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                _balanceBucketIdentity(bucket),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              _balanceBucketAmount(bucket),
              const SizedBox(height: 14),
              if (lines.isEmpty)
                const Text('منشأ قابل نمایش برای این مانده پیدا نشد.')
              else
                ...lines.map((line) => _provenanceLine(sheetContext, line)),
              if (lines.isNotEmpty) ...[
                const Divider(height: 24),
                Text('مانده فعلی', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                _runningAmount(
                  sheetContext,
                  bucket,
                  lines.last.runningAmount,
                  lines.last.runningDirection,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _provenanceLine(
    BuildContext context,
    ZarCustomerLedgerStatementLine line,
  ) {
    final posting = line.posting;
    final record = records.cast<AppRecord?>().firstWhere(
      (item) => item?.id == posting.sourceRecordId,
      orElse: () => null,
    );
    final title =
        posting.sourceLabel ??
        (posting.sourceType == ZarCustomerLedgerSourceType.deal
            ? 'معامله'
            : 'حرکت ثبت‌شده');
    final date = Jalali.fromDateTime(posting.occurredAt.toLocal());
    final time = posting.occurredAt.toLocal();
    final amount = _postingAmount(posting);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  record == null ? title : record.operationDisplayLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${formatJalaliDate(date)} · ${toPersianDigits(time.hour.toString().padLeft(2, '0'))}:${toPersianDigits(time.minute.toString().padLeft(2, '0'))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 5),
          amount,
          const SizedBox(height: 4),
          Text(
            'مانده پس از این رویداد: ${_runningLabel(line.runningDirection, line.runningAmount)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _balanceBucketAmount(ZarCustomerBalanceAssetBucket bucket) {
    final parts = _bucketParts(bucket);
    return ZarAmountDisplay(
      amount: parts.amount,
      unit: parts.unit,
      amountStyle: const TextStyle(fontWeight: FontWeight.w800),
      unitStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  Widget _runningAmount(
    BuildContext context,
    ZarCustomerBalanceAssetBucket bucket,
    String amount,
    ZarSettlementDirection? direction,
  ) {
    if (direction == null) return const Text('تسویه شده');
    final copy = ZarCustomerBalanceAssetBucket(
      direction: direction,
      assetType: bucket.assetType,
      amount: amount,
      currencyCode: bucket.currencyCode,
      goldFineness: bucket.goldFineness,
      coinIdentity: bucket.coinIdentity,
      displayName: bucket.displayName,
    );
    return _balanceBucketAmount(copy);
  }

  Widget _postingAmount(ZarCustomerLedgerPosting posting) {
    final bucket = ZarCustomerBalanceAssetBucket(
      direction: posting.direction,
      assetType: posting.assetType,
      amount: posting.amount,
      currencyCode: posting.currencyCode,
      goldFineness: posting.goldFineness,
      coinIdentity: posting.coinIdentity,
      displayName: posting.displayName,
    );
    return _balanceBucketAmount(bucket);
  }

  ({String amount, String unit}) _bucketParts(
    ZarCustomerBalanceAssetBucket bucket,
  ) {
    final formatted = toPersianNumberText(bucket.amount);
    return switch (bucket.assetType) {
      ZarAssetType.currency => (
        amount: formatted,
        unit: bucket.isToman ? 'تومان' : bucket.currencyCode ?? 'ارز',
      ),
      ZarAssetType.gold => (amount: formatted, unit: 'گرم طلا'),
      ZarAssetType.coin => (amount: formatted, unit: 'عدد'),
    };
  }

  String _balanceBucketIdentity(ZarCustomerBalanceAssetBucket bucket) {
    return switch (bucket.assetType) {
      ZarAssetType.currency =>
        bucket.isToman ? 'وجه نقد' : 'ارز ${bucket.currencyCode ?? ''}'.trim(),
      ZarAssetType.gold =>
        bucket.goldFineness == null
            ? 'طلای عیار نامشخص'
            : 'طلای عیار ${toPersianNumberText(bucket.goldFineness!)}',
      ZarAssetType.coin => bucket.displayName ?? 'سکه',
    };
  }

  String _runningLabel(ZarSettlementDirection? direction, String amount) {
    if (direction == null) return 'تسویه شده';
    final label = direction == ZarSettlementDirection.receive
        ? 'باید از او بگیرم'
        : 'باید به او بدهم';
    return '$label · ${toPersianNumberText(amount)}';
  }

  Widget _personProfileHeader(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhone = (person.phone ?? '').trim().isNotEmpty;
    final phoneLabel = hasPhone ? person.phone! : 'شماره تماس ثبت نشده است.';
    final note = (person.note ?? '').trim();
    final buttonPadding = const EdgeInsets.symmetric(horizontal: 5);
    final compactButtonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      padding: WidgetStatePropertyAll(buttonPadding),
      visualDensity: VisualDensity.compact,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.14,
                ),
                child: Text(
                  person.name.trim().isEmpty ? '-' : person.name.trim()[0],
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phoneLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('person-primary-new-entry'),
                  onPressed: onQuickEntry,
                  style: compactButtonStyle,
                  icon: const Icon(CupertinoIcons.add, size: 17),
                  label: const Text('ثبت جدید'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('person-primary-share-statement'),
                  onPressed: onShareStatement,
                  style: compactButtonStyle,
                  icon: const Icon(CupertinoIcons.share, size: 17),
                  label: const Text('اشتراک صورتحساب'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasPhone
                      ? () async {
                          final uri = Uri(
                            scheme: 'tel',
                            path: phoneToEnglishDigits(person.phone!),
                          );
                          await launchUrl(uri);
                        }
                      : null,
                  style: compactButtonStyle,
                  icon: const Icon(CupertinoIcons.phone, size: 16),
                  label: const Text('تماس'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onEditPerson(person),
                  style: compactButtonStyle,
                  icon: const Icon(CupertinoIcons.pencil, size: 16),
                  label: const Text('ویرایش'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onArchivePerson(person.id),
                  style: compactButtonStyle,
                  icon: const Icon(CupertinoIcons.archivebox, size: 16),
                  label: const Text('بایگانی'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _customerCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );

  Widget _positionSide(
    BuildContext context,
    String title,
    List<ZarCustomerPositionItem> items,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 6),
      if (items.isEmpty)
        Text('موردی وجود ندارد.', style: Theme.of(context).textTheme.bodyMedium)
      else
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _positionItem(item),
          ),
        ),
    ],
  );

  Widget _positionItem(ZarCustomerPositionItem item) {
    const gold = Color(0xFF9A6700);
    const currency = Color(0xFF2F6F73);
    return switch (item) {
      ZarCustomerGoldPosition(:final fineness, :final grams) => Text(
        '${_formatPositionDecimal(grams)} گرم طلای ${fineness == null ? 'عیار نامشخص' : 'عیار ${toPersianDigits(fineness)}'}',
        style: const TextStyle(color: gold, fontWeight: FontWeight.w600),
      ),
      ZarCustomerCurrencyPosition(:final code, :final decimalAmount) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            code == 'TOMAN'
                ? '${_formatPositionDecimal(decimalAmount)} تومان'
                : '${_formatPositionDecimal(decimalAmount)} $code',
            style: const TextStyle(
              color: currency,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ZarCustomerCoinPosition(:final displayName, :final quantity) => Text(
        '${toPersianDigits(quantity.toString())} عدد $displayName',
        style: const TextStyle(color: gold, fontWeight: FontWeight.w600),
      ),
    };
  }

  Widget _activityPill(BuildContext context, String label, int count) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '$label ${toPersianDigits(count.toString())}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      );

  String _lastActivityLabel(DateTime? value) {
    if (value == null) return 'ثبت نشده';
    final local = value.toLocal();
    final jalali = Jalali.fromDateTime(local);
    return '${formatJalaliDate(jalali)}، ${toPersianDigits(local.hour.toString().padLeft(2, '0'))}:${toPersianDigits(local.minute.toString().padLeft(2, '0'))}';
  }

  String _formatPositionDecimal(String value) {
    final parts = value.split('.');
    final grouped = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '٬',
    );
    return toPersianDigits(
      parts.length == 1 ? grouped : '$grouped٫${parts[1]}',
    );
  }
}

/// Person-profile row with a stable physical left amount column. The
/// surrounding page is RTL, but the row itself is laid out left-to-right so
/// the disclosure chevron and Amount/Unit block never jump as labels change.
class _PersonRecordRow extends StatelessWidget {
  const _PersonRecordRow({required this.record, this.onTap});

  final AppRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = record.status == SettlementStatus.completed
        ? const Color(0xFF2F7D4C)
        : record.status == SettlementStatus.cancelled
        ? const Color(0xFF9D3636)
        : theme.textTheme.bodyMedium?.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(CupertinoIcons.chevron_left, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 5,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _PersonRecordAmount(record: record),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  // In RTL, start is the physical right edge. Using end
                  // here caused the information block to drift toward the
                  // center of the row.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.operationDisplayLabel,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatJalaliDate(record.date)} · ${record.timeLabel()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      record.type == RecordType.settlement
                          ? record.statusLabel()
                          : 'معامله',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRecordAmount extends StatelessWidget {
  const _PersonRecordAmount({required this.record});

  final AppRecord record;

  @override
  Widget build(BuildContext context) {
    final parts = _personRecordAmountParts(record);
    final style = Theme.of(context).textTheme.bodyMedium;
    return ZarAmountDisplay(
      amount: parts.amount,
      unit: parts.unit,
      purity: parts.purity,
      amountStyle: style?.copyWith(fontWeight: FontWeight.w700),
      unitStyle: style,
    );
  }
}

({String amount, String unit, String? purity}) _personRecordAmountParts(
  AppRecord record,
) {
  if (record.coinLines.isNotEmpty) {
    if (record.coinLines.length == 1) {
      final line = record.coinLines.single;
      return (
        amount: toPersianDigits(line.quantity.toString()),
        unit: 'عدد ${line.name}',
        purity: line.fineness == null
            ? null
            : 'عیار ${toPersianDigits(line.fineness!)}',
      );
    }
    return (
      amount: toPersianDigits(record.coinLines.length.toString()),
      unit: 'نوع سکه',
      purity: null,
    );
  }

  final numeric =
      RegExp(
        r'[-+]?[0-9۰-۹٬,٫.]+',
      ).firstMatch(record.amountDisplay)?.group(0) ??
      record.amountDisplay;
  if (record.currencyCode != null) {
    return (
      amount: toPersianNumberText(numeric),
      unit: record.currencyCode == 'TOMAN' ? 'تومان' : record.currencyCode!,
      purity: null,
    );
  }
  if (record.assetLabel == 'وجه نقد') {
    return (amount: toPersianNumberText(numeric), unit: 'تومان', purity: null);
  }
  if (record.goldFineness != null || record.assetLabel == 'گرم طلا') {
    return (
      amount: toPersianNumberText(numeric),
      unit: record.goldInputUnit == 'mesghal' ? 'مثقال طلا' : 'گرم طلا',
      purity: record.goldFineness == null
          ? null
          : 'عیار ${toPersianDigits(record.goldFineness!)}',
    );
  }
  return (
    amount: toPersianNumberText(numeric),
    unit: record.assetLabel,
    purity: null,
  );
}

class SettlementRow extends StatelessWidget {
  const SettlementRow({
    super.key,
    required this.record,
    required this.personName,
    this.onTap,
    this.showOverdueTone = false,
    this.showPersonName = true,
  });

  final AppRecord record;
  final String personName;
  final VoidCallback? onTap;
  final bool showOverdueTone;
  final bool showPersonName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = showOverdueTone
        ? const Color(0xFF9D3636)
        : record.status == SettlementStatus.completed
        ? const Color(0xFF2F7D4C)
        : record.status == SettlementStatus.cancelled
        ? const Color(0xFF9D3636)
        : theme.textTheme.bodyMedium?.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.operationDisplayLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (showPersonName) ...[
                    Text(
                      personName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyLarge?.color?.withValues(
                          alpha: 0.84,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ] else
                    const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      AmountText(record.amountDisplay),
                      Text(
                        record.assetLabel,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(record.timeLabel(), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 3),
                if (record.type == RecordType.settlement)
                  Text(
                    record.statusLabel(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text('معامله', style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AmountText extends StatelessWidget {
  const AmountText(this.amount, {super.key});
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        amount,
        textAlign: TextAlign.left,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class HistoryDealDetailSheet extends StatelessWidget {
  const HistoryDealDetailSheet({
    super.key,
    required this.record,
    required this.personName,
    required this.linkedSettlements,
    required this.onOpenSettlement,
    this.accountingStatus,
  });

  final AppRecord record;
  final String personName;
  final List<AppRecord> linkedSettlements;
  final ValueChanged<AppRecord> onOpenSettlement;
  final String? accountingStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
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
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        record.operationDisplayLabel,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        personName,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                RecordShareButton(record: record, personName: personName),
              ],
            ),
            const SizedBox(height: 14),
            _summaryCard(context),
            const SizedBox(height: 12),
            _metaCard(context),
            if (record.coinLines.isNotEmpty ||
                record.goldFineness != null ||
                record.tomanRate != null) ...[
              const SizedBox(height: 12),
              _breakdownCard(context),
            ],
            if ((record.note ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionCard(
                context,
                title: 'یادداشت',
                child: Text(
                  record.note!.trim(),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
            if (linkedSettlements.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionCard(
                context,
                title: 'تعهدهای لینک‌شده',
                child: Column(
                  children: linkedSettlements
                      .map(
                        (settlement) => SettlementRow(
                          record: settlement,
                          personName: personName,
                          onTap: () => onOpenSettlement(settlement),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final theme = Theme.of(context);
    return _sectionCard(
      context,
      key: const ValueKey('deal-detail-summary'),
      title: 'خلاصه معامله',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('دارایی', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Directionality(
              textDirection: record.currencyCode != null
                  ? TextDirection.ltr
                  : TextDirection.rtl,
              child: Text(
                recordAssetSummary(record),
                textAlign: record.currencyCode != null
                    ? TextAlign.left
                    : TextAlign.right,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (record.totalToman != null) ...[
            const SizedBox(height: 12),
            Text('مبلغ کل', style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              '${toPersianNumberText(NumberFormat.decimalPattern('en_US').format(record.totalToman))} تومان',
              textAlign: TextAlign.right,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '${formatJalaliDate(record.date)} · ${record.timeLabel()}',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _metaCard(BuildContext context) {
    return _sectionCard(
      context,
      key: const ValueKey('deal-detail-meta'),
      title: 'اطلاعات معامله',
      child: Column(
        children: [
          _metaRow(context, 'نوع عملیات', record.operationDisplayLabel),
          _metaRow(context, 'طرف حساب', personName),
          _metaRow(context, 'تاریخ ثبت', formatJalaliDate(record.date)),
          _metaRow(context, 'ساعت ثبت', record.timeLabel()),
          if (accountingStatus != null)
            _metaRow(context, 'اثر روی حساب', accountingStatus!),
        ],
      ),
    );
  }

  Widget _breakdownCard(BuildContext context) {
    final theme = Theme.of(context);
    return _sectionCard(
      context,
      key: const ValueKey('deal-detail-breakdown'),
      title: 'جزئیات دارایی و قیمت',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (record.goldFineness != null)
            _metaRow(context, 'عیار', toPersianDigits(record.goldFineness!)),
          if (record.goldInputWeight != null)
            _metaRow(
              context,
              'وزن ثبت‌شده',
              '${toPersianDigits(record.goldInputWeight!)} ${record.goldInputUnit == 'mesghal' ? 'مثقال' : 'گرم'}',
            ),
          if (record.goldEquivalentWeight != null)
            _metaRow(
              context,
              'معادل وزن',
              '${toPersianDigits(record.goldEquivalentWeight!)} ${record.goldInputUnit == 'mesghal' ? 'گرم' : 'مثقال'}',
            ),
          if (record.tomanRate != null)
            _metaRow(
              context,
              'نرخ/قیمت واحد',
              '${toPersianNumberText(record.tomanRate!)} تومان',
            ),
          ...record.coinLines.map(
            (line) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${toPersianDigits(line.quantity.toString())} × ${line.name}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (line.weightGrams != null || line.fineness != null)
                    Text(
                      [
                        if (line.weightGrams != null)
                          '${toPersianDigits(line.weightGrams!)} گرم',
                        if (line.fineness != null)
                          'عیار ${toPersianDigits(line.fineness!)}',
                      ].join(' · '),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall,
                    ),
                  if (line.rowTotalToman != null)
                    Text(
                      'جمع ردیف: ${toPersianNumberText(NumberFormat.decimalPattern('en_US').format(line.rowTotalToman))} تومان',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    Key? key,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _metaRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.eventDays,
    this.overdueDays = const [],
    required this.onDayTap,
  });

  final Jalali month;
  final Jalali selected;
  final List<Jalali> eventDays;
  final List<Jalali> overdueDays;
  final ValueChanged<Jalali> onDayTap;

  @override
  Widget build(BuildContext context) {
    const weekTitles = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final firstWeekday = ((month.toDateTime().weekday + 1) % 7);
    final daysInMonth = month.monthLength;
    final cells = <Widget>[];

    for (final title in weekTitles) {
      cells.add(
        Center(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
            ),
          ),
        ),
      );
    }
    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = month.withDay(day);
      final hasEvent = eventDays.any((e) => isSameJalali(e, date));
      final hasOverdue = overdueDays.any((e) => isSameJalali(e, date));
      final isSelected = isSameJalali(date, selected);
      cells.add(
        InkWell(
          key: ValueKey('calendar-day-$day'),
          onTap: () => onDayTap(date),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  toPersianDigits(day.toString()),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                ),
                const SizedBox(height: 2),
                if (hasEvent)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: hasOverdue
                          ? const Color(0xFFB23A3A)
                          : Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('calendar-month-grid'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 7,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.05,
        children: cells,
      ),
    );
  }

  static int rowCountFor(Jalali month) {
    final firstWeekday = ((month.toDateTime().weekday + 1) % 7);
    final cellCount = 7 + firstWeekday + month.monthLength;
    return (cellCount / 7).ceil();
  }
}

Future<AppPerson?> showPersonPickerBottomSheet(
  BuildContext context,
  List<AppPerson> people, {
  List<AppPerson> recentPeople = const [],
}) {
  return showModalBottomSheet<AppPerson>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _PersonPickerSheet(people: people, recentPeople: recentPeople),
  );
}

Future<Jalali?> pickJalaliDate(BuildContext context, Jalali initial) {
  return showDialog<Jalali>(
    context: context,
    builder: (_) => _JalaliDateDialog(initial: initial),
  );
}

class _JalaliDateDialog extends StatefulWidget {
  const _JalaliDateDialog({required this.initial});
  final Jalali initial;

  @override
  State<_JalaliDateDialog> createState() => _JalaliDateDialogState();
}

class _JalaliDateDialogState extends State<_JalaliDateDialog> {
  late Jalali month = widget.initial.withDay(1);
  late Jalali selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('انتخاب تاریخ'),
      content: SizedBox(
        width: 330,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => month = month.addMonths(-1)),
                  icon: const Icon(CupertinoIcons.chevron_right),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${monthName(month.month)} ${toPersianDigits(month.year.toString())}',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => month = month.addMonths(1)),
                  icon: const Icon(CupertinoIcons.chevron_left),
                ),
              ],
            ),
            SizedBox(
              height: 280,
              child: CalendarMonthGrid(
                month: month,
                selected: selected,
                eventDays: const [],
                onDayTap: (d) => setState(() => selected = d),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selected),
          child: const Text('تایید'),
        ),
      ],
    );
  }
}

Future<TimeOfDay?> pickCupertinoTime(
  BuildContext context,
  TimeOfDay? initial,
) async {
  TimeOfDay selected = initial ?? TimeOfDay.now();
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (_) {
      return Container(
        height: 280,
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Row(
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('تایید'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(
                  2025,
                  1,
                  1,
                  selected.hour,
                  selected.minute,
                ),
                use24hFormat: true,
                onDateTimeChanged: (value) => selected = TimeOfDay(
                  hour: value.hour,
                  minute: value.minute,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  return selected;
}

Future<(Jalali, TimeOfDay?)?> showReminderPickerBottomSheet(
  BuildContext context, {
  required Jalali initialDate,
  required TimeOfDay? initialTime,
  String initialSelection = '۱ ساعت',
  DateTime? now,
}) async {
  final selected = await showReminderTextPickerBottomSheet(
    context,
    initialSelection,
  );
  if (!context.mounted || selected == null) return null;
  if (selected == 'سفارشی') {
    final d = await pickJalaliDate(context, initialDate);
    if (!context.mounted || d == null) return null;
    final t = await pickCupertinoTime(context, initialTime);
    return (d, t);
  }
  final target = snoozePresetDateTime(
    selected,
    now ?? DateTime.now(),
    tomorrowTime: initialTime,
  );
  if (target == null) return null;
  return (
    Jalali.fromDateTime(target),
    TimeOfDay(hour: target.hour, minute: target.minute),
  );
}

Future<String?> showReminderTextPickerBottomSheet(
  BuildContext context,
  String current,
) async {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (_) {
      final items = [
        'بدون یادآوری',
        '۱۵ دقیقه',
        '۳۰ دقیقه',
        '۱ ساعت',
        '۳ ساعت',
        '۱ روز',
        'فردا',
        'سفارشی',
      ];
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: ListView(
          shrinkWrap: true,
          children: items
              .map(
                (e) => ListTile(
                  title: Text(e),
                  trailing: e == current
                      ? const Icon(CupertinoIcons.check_mark)
                      : null,
                  onTap: () => Navigator.pop(context, e),
                ),
              )
              .toList(),
        ),
      );
    },
  );
}

/// A compact, platform-native share affordance shared by Deal and Settlement
/// detail sheets. The record itself remains typed and its lifecycle is never
/// inferred from the share presentation.
class RecordShareButton extends StatelessWidget {
  const RecordShareButton({
    super.key,
    required this.record,
    required this.personName,
  });

  final AppRecord record;
  final String personName;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'اشتراک‌گذاری',
    onPressed: () =>
        showRecordShareOptions(context, record: record, personName: personName),
    icon: const Icon(CupertinoIcons.share, size: 20),
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    padding: EdgeInsets.zero,
  );
}

/// Formats one record for messaging without exposing internal enum names or
/// presenting a Deal as a Settlement. This is intentionally pure so it can be
/// covered independently of platform share sheets.
String recordShareText(AppRecord record, String personName) {
  final lines = <String>[
    'ZAR+ — ${record.type == RecordType.deal ? 'جزئیات معامله' : 'جزئیات تسویه'}',
    'عملیات: ${record.operationDisplayLabel}',
    if (record.type == RecordType.settlement) 'وضعیت: ${record.statusLabel()}',
    'طرف حساب: $personName',
    'دارایی: ${_shareAssetSummary(record)}',
    'تاریخ ثبت: ${formatJalaliDate(record.date)}',
    'ساعت ثبت: ${record.timeLabel()}',
    if (record.tomanRate != null)
      'نرخ/قیمت واحد: ${toPersianNumberText(record.tomanRate!)} تومان',
    if (record.totalToman != null)
      'مبلغ کل: ${toPersianNumberText(NumberFormat.decimalPattern('en_US').format(record.totalToman))} تومان',
    if ((record.note ?? '').trim().isNotEmpty)
      'یادداشت: ${record.note!.trim()}',
  ];
  return lines.join('\n');
}

String _shareAssetSummary(AppRecord record) {
  if (record.coinLines.isNotEmpty) {
    return record.coinLines
        .map(
          (line) =>
              '${toPersianDigits(line.quantity.toString())} × ${line.name}'
              '${line.weightGrams == null ? '' : '، ${toPersianDigits(line.weightGrams!)} گرم'}'
              '${line.fineness == null ? '' : '، عیار ${toPersianDigits(line.fineness!)}'}',
        )
        .join('؛ ');
  }
  if (record.currencyCode != null) {
    final numeric =
        RegExp(
          r'[-+]?[0-9۰-۹٬,٫.]+',
        ).firstMatch(record.amountDisplay)?.group(0) ??
        record.amountDisplay;
    return '${toPersianNumberText(numeric)} ${record.currencyCode}';
  }
  if (record.goldFineness != null || record.assetLabel == 'گرم طلا') {
    final numeric =
        RegExp(
          r'[-+]?[0-9۰-۹٬,٫.]+',
        ).firstMatch(record.amountDisplay)?.group(0) ??
        record.amountDisplay;
    final unit = record.goldInputUnit == 'mesghal' ? 'مثقال' : 'گرم';
    return '${toPersianNumberText(numeric)} $unit طلا، عیار ${record.goldFineness == null ? 'نامشخص' : toPersianNumberText(record.goldFineness!)}';
  }
  return toPersianNumberText(record.amountDisplay);
}

/// Canonical compact asset summary shared by History and share surfaces.
///
/// The summary is derived from the record and keeps currency values in the
/// existing numeric-first format so callers can place it in an explicit LTR
/// span without changing the stored amount.
String recordAssetSummary(AppRecord record) => _shareAssetSummary(record);

Future<void> showRecordShareOptions(
  BuildContext context, {
  required AppRecord record,
  required String personName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اشتراک‌گذاری جزئیات',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(CupertinoIcons.textbox),
              title: const Text('ارسال متن'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await SharePlus.instance.share(
                  ShareParams(text: recordShareText(record, personName)),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(CupertinoIcons.photo),
              title: const Text('ارسال تصویر'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _shareRecordImage(context, record, personName);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _shareRecordImage(
  BuildContext context,
  AppRecord record,
  String personName,
) async {
  final boundaryKey = GlobalKey();
  final bytes = await showModalBottomSheet<Uint8List>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _ShareCardCapture(
      boundaryKey: boundaryKey,
      record: record,
      personName: personName,
    ),
  );
  if (!context.mounted || bytes == null) return;
  await SharePlus.instance.share(
    ShareParams(
      text: 'ZAR+ — ${record.operationDisplayLabel}',
      files: [
        XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: 'zar-${record.id}.png',
        ),
      ],
      fileNameOverrides: ['zar-${record.id}.png'],
    ),
  );
}

class _ShareCardCapture extends StatefulWidget {
  const _ShareCardCapture({
    required this.boundaryKey,
    required this.record,
    required this.personName,
  });

  final GlobalKey boundaryKey;
  final AppRecord record;
  final String personName;

  @override
  State<_ShareCardCapture> createState() => _ShareCardCaptureState();
}

class _ShareCardCaptureState extends State<_ShareCardCapture> {
  bool _captured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    if (_captured || !mounted) return;
    final renderObject = widget.boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;
    try {
      final image = await renderObject.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted || data == null) return;
      _captured = true;
      Navigator.of(context).pop(data.buffer.asUint8List());
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: RepaintBoundary(
        key: widget.boundaryKey,
        child: _RecordShareCard(
          record: widget.record,
          personName: widget.personName,
        ),
      ),
    ),
  );
}

class _RecordShareCard extends StatelessWidget {
  const _RecordShareCard({required this.record, required this.personName});

  final AppRecord record;
  final String personName;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Material(
      color: Colors.white,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFAF8),
          border: Border.all(color: const Color(0xFFE4DFD7)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ZAR+',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Text(
              record.operationDisplayLabel,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              personName,
              style: const TextStyle(fontSize: 16, color: Color(0xFF65615C)),
            ),
            const Divider(height: 24),
            Text(
              _shareAssetSummary(record),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              '${formatJalaliDate(record.date)} • ${record.timeLabel()}',
              style: const TextStyle(color: Color(0xFF65615C)),
            ),
            if (record.type == RecordType.settlement) ...[
              const SizedBox(height: 4),
              Text(
                record.statusLabel(),
                style: const TextStyle(color: Color(0xFF65615C)),
              ),
            ],
            if (record.totalToman != null) ...[
              const SizedBox(height: 10),
              Text(
                'مبلغ کل: ${toPersianNumberText(NumberFormat.decimalPattern('en_US').format(record.totalToman))} تومان',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Builds a current, derived account summary for one person. This is a
/// balance/status share, not a receipt and not an accounting statement.
String personBalanceShareText({
  required AppPerson person,
  required ZarCustomerOperationalBalance balance,
  DateTime? generatedAt,
  String? lastActivityLabel,
}) {
  final lines = <String>[
    'ZAR+',
    'وضعیت حساب با ${person.name}',
    if ((person.phone ?? '').trim().isNotEmpty) 'شماره تماس: ${person.phone}',
    '',
    'باید از او بگیرم:',
    ..._shareBucketLines(balance.receivableAssetBuckets),
    '',
    'باید به او بدهم:',
    ..._shareBucketLines(balance.payableAssetBuckets),
    if (lastActivityLabel != null) 'آخرین فعالیت: $lastActivityLabel',
    '',
    'تهیه‌شده در: ${_shareDateTime(generatedAt ?? DateTime.now())}',
  ];
  return lines.join('\n');
}

String personStatementShareText({
  required AppPerson person,
  required ZarCustomerOperationalBalance balance,
  required List<AppRecord> records,
  ZarCustomerLedgerProjection? ledger,
  DateTime? generatedAt,
  int? recentLimit,
}) {
  final personRecords =
      records.where((item) => item.personId == person.id).toList()
        ..sort(_compareShareRecords);
  final open = personRecords
      .where(
        (item) =>
            item.type == RecordType.settlement &&
            item.status == SettlementStatus.open,
      )
      .toList(growable: false);
  final history = personRecords
      .where(
        (item) =>
            item.type == RecordType.deal ||
            item.status != SettlementStatus.open,
      )
      .toList(growable: false);
  final visibleHistory = recentLimit == null || history.length <= recentLimit
      ? history
      : history.take(recentLimit).toList(growable: false);
  final unpricedDeals = visibleHistory
      .where((item) => item.type == RecordType.deal && item.totalToman == null)
      .toList(growable: false);
  final lines = <String>[
    'ZAR+',
    'صورتحساب ${person.name}',
    if ((person.phone ?? '').trim().isNotEmpty) 'شماره تماس: ${person.phone}',
    '',
    'وضعیت فعلی',
    'باید از او بگیرم:',
    ..._shareBucketLines(balance.receivableAssetBuckets),
    'باید به او بدهم:',
    ..._shareBucketLines(balance.payableAssetBuckets),
    '',
    'تعهدات باز',
    if (open.isEmpty)
      'موردی وجود ندارد.'
    else
      ...open.expand(_shareOpenRecordLines),
    '',
    'سوابق',
    if (visibleHistory.isEmpty)
      'موردی ثبت نشده است.'
    else
      ...visibleHistory.expand(_shareHistoryRecordLines),
    if (visibleHistory.length < history.length)
      'و ${toPersianDigits((history.length - visibleHistory.length).toString())} فعالیت دیگر',
    if (unpricedDeals.isNotEmpty) ...[
      '',
      'معاملات بدون مبلغ تسویه',
      ...unpricedDeals.map(
        (item) =>
            '${item.operationDisplayLabel}: ${_shareAssetSummary(item)} — مبلغ تسویه مشخص نشده',
      ),
    ],
    if (ledger != null && ledger.postings.isNotEmpty) ...[
      '',
      'گردش حساب',
      ...ledger
          .statementLines()
          .take(recentLimit ?? ledger.postings.length)
          .map(_shareLedgerStatementLine),
    ],
    '',
    'تهیه‌شده در: ${_shareDateTime(generatedAt ?? DateTime.now())}',
  ];
  return lines.join('\n');
}

String balanceBucketShareText({
  required AppPerson person,
  required ZarCustomerBalanceAssetBucket bucket,
  DateTime? generatedAt,
}) {
  final direction = bucket.direction == ZarSettlementDirection.receive
      ? 'باید از ${person.name} دریافت کنم'
      : 'باید به ${person.name} پرداخت کنم';
  return [
    'ZAR+',
    'وضعیت حساب با ${person.name}',
    '',
    direction,
    _shareBucketLine(bucket),
    if (bucket.sourceCount > 0)
      'منشأ: ${toPersianDigits(bucket.sourceCount.toString())} رکورد',
    '',
    'این مورد خلاصه مانده فعلی است، نه رسید معامله.',
    'تاریخ تهیه: ${_shareDateTime(generatedAt ?? DateTime.now())}',
  ].join('\n');
}

Future<void> showPersonStatementShareOptions(
  BuildContext context, {
  required AppPerson person,
  required ZarCustomerOperationalBalance balance,
  required List<AppRecord> records,
  ZarCustomerLedgerProjection? ledger,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اشتراک‌گذاری صورتحساب',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _shareActionTile(
              sheetContext,
              label: 'خلاصه حساب — ارسال متن',
              icon: CupertinoIcons.textbox,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await SharePlus.instance.share(
                  ShareParams(
                    text: personBalanceShareText(
                      person: person,
                      balance: balance,
                      lastActivityLabel: _latestShareActivityLabel(
                        person,
                        records,
                      ),
                    ),
                  ),
                );
              },
            ),
            _shareActionTile(
              sheetContext,
              label: 'خلاصه حساب — ارسال تصویر',
              icon: CupertinoIcons.photo,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _sharePersonImage(
                  context,
                  person: person,
                  balance: balance,
                  records: records,
                  full: false,
                );
              },
            ),
            _shareActionTile(
              sheetContext,
              label: 'صورتحساب کامل — ارسال متن',
              icon: CupertinoIcons.doc_text,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await SharePlus.instance.share(
                  ShareParams(
                    text: personStatementShareText(
                      person: person,
                      balance: balance,
                      records: records,
                      ledger: ledger,
                    ),
                  ),
                );
              },
            ),
            _shareActionTile(
              sheetContext,
              label: 'صورتحساب کامل — ارسال تصویر',
              icon: CupertinoIcons.photo_on_rectangle,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _sharePersonImage(
                  context,
                  person: person,
                  balance: balance,
                  records: records,
                  ledger: ledger,
                  full: true,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

String? _latestShareActivityLabel(AppPerson person, List<AppRecord> records) {
  final items = records.where((item) => item.personId == person.id).toList()
    ..sort(_compareShareRecords);
  if (items.isEmpty) return null;
  final item = items.first;
  return '${formatJalaliDate(item.date)} · ${item.timeLabel()}';
}

Future<void> showBalanceBucketShareOptions(
  BuildContext context, {
  required AppPerson person,
  required ZarCustomerBalanceAssetBucket bucket,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اشتراک‌گذاری این مورد',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _shareActionTile(
              sheetContext,
              label: 'ارسال متن',
              icon: CupertinoIcons.textbox,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await SharePlus.instance.share(
                  ShareParams(
                    text: balanceBucketShareText(
                      person: person,
                      bucket: bucket,
                    ),
                  ),
                );
              },
            ),
            _shareActionTile(
              sheetContext,
              label: 'ارسال تصویر',
              icon: CupertinoIcons.photo,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _shareBucketImage(
                  context,
                  person: person,
                  bucket: bucket,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _shareActionTile(
  BuildContext context, {
  required String label,
  required IconData icon,
  required VoidCallback onTap,
}) => ListTile(
  contentPadding: EdgeInsets.zero,
  leading: Icon(icon),
  title: Text(label),
  onTap: onTap,
);

Future<void> _sharePersonImage(
  BuildContext context, {
  required AppPerson person,
  required ZarCustomerOperationalBalance balance,
  required List<AppRecord> records,
  ZarCustomerLedgerProjection? ledger,
  required bool full,
}) async {
  final bytes = await _captureShareCard(
    context,
    _PersonShareCard(
      person: person,
      balance: balance,
      records: records,
      ledger: ledger,
      full: full,
    ),
  );
  if (!context.mounted || bytes == null) return;
  await SharePlus.instance.share(
    ShareParams(
      text: full ? 'صورتحساب ${person.name}' : 'وضعیت حساب با ${person.name}',
      files: [
        XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: 'zar-person-${person.id}.png',
        ),
      ],
      fileNameOverrides: ['zar-person-${person.id}.png'],
    ),
  );
}

Future<void> _shareBucketImage(
  BuildContext context, {
  required AppPerson person,
  required ZarCustomerBalanceAssetBucket bucket,
}) async {
  final bytes = await _captureShareCard(
    context,
    _BalanceBucketShareCard(person: person, bucket: bucket),
  );
  if (!context.mounted || bytes == null) return;
  await SharePlus.instance.share(
    ShareParams(
      text: balanceBucketShareText(person: person, bucket: bucket),
      files: [
        XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: 'zar-balance-${person.id}.png',
        ),
      ],
      fileNameOverrides: ['zar-balance-${person.id}.png'],
    ),
  );
}

Future<Uint8List?> _captureShareCard(BuildContext context, Widget card) async {
  final boundaryKey = GlobalKey();
  return showModalBottomSheet<Uint8List>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) =>
        _GenericShareCardCapture(boundaryKey: boundaryKey, card: card),
  );
}

class _GenericShareCardCapture extends StatefulWidget {
  const _GenericShareCardCapture({
    required this.boundaryKey,
    required this.card,
  });
  final GlobalKey boundaryKey;
  final Widget card;

  @override
  State<_GenericShareCardCapture> createState() =>
      _GenericShareCardCaptureState();
}

class _GenericShareCardCaptureState extends State<_GenericShareCardCapture> {
  bool _captured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    if (_captured || !mounted) return;
    final renderObject = widget.boundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;
    try {
      final image = await renderObject.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted || data == null) return;
      _captured = true;
      Navigator.of(context).pop(data.buffer.asUint8List());
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: RepaintBoundary(key: widget.boundaryKey, child: widget.card),
    ),
  );
}

class _PersonShareCard extends StatelessWidget {
  const _PersonShareCard({
    required this.person,
    required this.balance,
    required this.records,
    this.ledger,
    required this.full,
  });
  final AppPerson person;
  final ZarCustomerOperationalBalance balance;
  final List<AppRecord> records;
  final ZarCustomerLedgerProjection? ledger;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final currentLedger = ledger;
    final personRecords =
        records.where((item) => item.personId == person.id).toList()
          ..sort(_compareShareRecords);
    final history = personRecords
        .where(
          (item) =>
              item.type == RecordType.deal ||
              item.status != SettlementStatus.open,
        )
        .take(6)
        .toList(growable: false);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.white,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFAF8),
            border: Border.all(color: const Color(0xFFE4DFD7)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ZAR+',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                full
                    ? 'صورتحساب ${person.name}'
                    : 'وضعیت حساب با ${person.name}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Divider(height: 26),
              _shareCardDirection(
                'باید از او بگیرم',
                balance.receivableAssetBuckets,
              ),
              const SizedBox(height: 12),
              _shareCardDirection(
                'باید به او بدهم',
                balance.payableAssetBuckets,
              ),
              if (full) ...[
                const SizedBox(height: 16),
                const Text(
                  'فعالیت اخیر',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                if (history.isEmpty)
                  const Text('موردی ثبت نشده است.')
                else
                  ...history.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${record.operationDisplayLabel} — ${_shareAssetSummary(record)}\n${formatJalaliDate(record.date)} · ${record.timeLabel()}',
                      ),
                    ),
                  ),
                if (currentLedger != null &&
                    currentLedger.postings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'گردش حساب',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...currentLedger
                      .statementLines()
                      .take(6)
                      .map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(_shareLedgerStatementLine(line)),
                        ),
                      ),
                ],
              ],
              const SizedBox(height: 16),
              Text(
                'تهیه‌شده در: ${_shareDateTime(DateTime.now())}',
                style: const TextStyle(color: Color(0xFF65615C)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceBucketShareCard extends StatelessWidget {
  const _BalanceBucketShareCard({required this.person, required this.bucket});
  final AppPerson person;
  final ZarCustomerBalanceAssetBucket bucket;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Material(
      color: Colors.white,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFAF8),
          border: Border.all(color: const Color(0xFFE4DFD7)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ZAR+',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'وضعیت حساب با ${person.name}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const Divider(height: 26),
            Text(
              bucket.direction == ZarSettlementDirection.receive
                  ? 'باید از او دریافت کنم'
                  : 'باید به او پرداخت کنم',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _shareBucketLine(bucket),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            const Text('این تصویر خلاصه مانده فعلی است، نه رسید معامله.'),
            const SizedBox(height: 12),
            Text(
              'تهیه‌شده در: ${_shareDateTime(DateTime.now())}',
              style: const TextStyle(color: Color(0xFF65615C)),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _shareCardDirection(
  String title,
  List<ZarCustomerBalanceAssetBucket> buckets,
) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 6),
    if (buckets.isEmpty)
      const Text('موردی وجود ندارد.')
    else
      ...buckets.map(
        (bucket) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(_shareBucketLine(bucket)),
        ),
      ),
  ],
);

List<String> _shareBucketLines(List<ZarCustomerBalanceAssetBucket> buckets) =>
    buckets.isEmpty
    ? ['موردی وجود ندارد.']
    : buckets.map(_shareBucketLine).toList(growable: false);

String _shareBucketLine(ZarCustomerBalanceAssetBucket bucket) {
  final amount = toPersianNumberText(bucket.amount);
  return switch (bucket.assetType) {
    ZarAssetType.currency =>
      bucket.currencyCode == 'TOMAN'
          ? 'تومان $amount'
          : '${bucket.currencyCode ?? ''} $amount',
    ZarAssetType.gold =>
      'گرم طلا $amount — ${bucket.goldFineness == null ? 'عیار نامشخص' : 'عیار ${toPersianNumberText(bucket.goldFineness!)}'}',
    ZarAssetType.coin => 'عدد $amount — ${bucket.displayName ?? 'سکه'}',
  };
}

String _shareLedgerPostingLine(ZarCustomerLedgerPosting posting) {
  final operation = switch (posting.sourceType) {
    ZarCustomerLedgerSourceType.deal =>
      posting.direction == ZarSettlementDirection.receive ? 'فروش' : 'خرید',
    ZarCustomerLedgerSourceType.settlement =>
      posting.direction == ZarSettlementDirection.deliver ? 'دریافت' : 'پرداخت',
  };
  final bucket = ZarCustomerBalanceAssetBucket(
    direction: posting.direction,
    assetType: posting.assetType,
    amount: posting.amount,
    currencyCode: posting.currencyCode,
    goldFineness: posting.goldFineness,
    coinIdentity: posting.coinIdentity,
    displayName: posting.displayName,
  );
  final date = Jalali.fromDateTime(posting.occurredAt.toLocal());
  return '$operation: ${_shareBucketLine(bucket)} · ${formatJalaliDate(date)}';
}

String _shareLedgerStatementLine(ZarCustomerLedgerStatementLine line) {
  final posting = _shareLedgerPostingLine(line.posting);
  if (line.runningDirection == null) return '$posting · مانده صفر';
  final direction = line.runningDirection == ZarSettlementDirection.receive
      ? 'باید دریافت کنم'
      : 'باید پرداخت کنم';
  final amount = toPersianNumberText(line.runningAmount);
  return '$posting · مانده: $amount — $direction';
}

Iterable<String> _shareOpenRecordLines(AppRecord record) sync* {
  yield '${record.operationDisplayLabel}: ${_shareAssetSummary(record)}';
  yield '${formatJalaliDate(record.date)} · ${record.timeLabel()} · ${record.statusLabel()}';
}

Iterable<String> _shareHistoryRecordLines(AppRecord record) sync* {
  yield '${record.operationDisplayLabel}: ${_shareAssetSummary(record)}';
  yield '${formatJalaliDate(record.date)} · ${record.timeLabel()}${record.type == RecordType.settlement ? ' · ${record.statusLabel()}' : ''}';
}

int _compareShareRecords(AppRecord a, AppRecord b) {
  final date = b.date.compareTo(a.date);
  if (date != 0) return date;
  final aMinutes = (a.time?.hour ?? -1) * 60 + (a.time?.minute ?? 0);
  final bMinutes = (b.time?.hour ?? -1) * 60 + (b.time?.minute ?? 0);
  return bMinutes.compareTo(aMinutes);
}

int _comparePersonRecords(AppRecord a, AppRecord b) =>
    _compareShareRecords(a, b);

String _shareDateTime(DateTime value) {
  final local = value.toLocal();
  final jalali = Jalali.fromDateTime(local);
  final hour = toPersianDigits(local.hour.toString().padLeft(2, '0'));
  final minute = toPersianDigits(local.minute.toString().padLeft(2, '0'));
  return '${formatJalaliDate(jalali)} · $hour:$minute';
}
class _ZEmptyRow extends StatelessWidget {
  const _ZEmptyRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _PersonPickerSheet extends StatefulWidget {
  const _PersonPickerSheet({
    required this.people,
    this.recentPeople = const [],
  });
  final List<AppPerson> people;
  final List<AppPerson> recentPeople;

  @override
  State<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends State<_PersonPickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final trimmed = query.trim();
    final filtered = widget.people
        .where((e) => e.name.contains(trimmed))
        .toList(growable: false);
    final recent = trimmed.isEmpty
        ? widget.recentPeople
              .where(
                (person) => widget.people.any((item) => item.id == person.id),
              )
              .toList(growable: false)
        : const <AppPerson>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(CupertinoIcons.search),
              hintText: 'جستجو',
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (recent.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 2),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('اخیراً استفاده‌شده'),
                    ),
                  ),
                  ...recent.map(
                    (person) => ListTile(
                      title: Text(person.name),
                      onTap: () => Navigator.pop(context, person),
                    ),
                  ),
                  if (filtered.any(
                    (person) => recent.every((item) => item.id != person.id),
                  ))
                    const Divider(height: 1),
                ],
                ...filtered
                    .where(
                      (person) => recent.every((item) => item.id != person.id),
                    )
                    .map(
                      (person) => ListTile(
                        title: Text(person.name),
                        onTap: () => Navigator.pop(context, person),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<CurrencyOption?> showCurrencyPickerBottomSheet(
  BuildContext context,
  String? currentCode, {
  List<CurrencyOption>? options,
}) {
  return showModalBottomSheet<CurrencyOption>(
    context: context,
    useSafeArea: true,
    builder: (_) =>
        _CurrencyPickerSheet(currentCode: currentCode, options: options),
  );
}

class _CurrencyPickerSheet extends StatelessWidget {
  const _CurrencyPickerSheet({required this.currentCode, this.options});

  final String? currentCode;
  final List<CurrencyOption>? options;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('نوع ارز', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...(options ?? kCurrencyOptions).map(
            (option) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(option.displayLabel),
              trailing: currentCode == option.code
                  ? const Icon(CupertinoIcons.check_mark)
                  : null,
              onTap: () => Navigator.pop(context, option),
            ),
          ),
        ],
      ),
    );
  }
}

