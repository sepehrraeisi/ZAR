import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:url_launcher/url_launcher.dart';

import 'features/reminders/reminder_model.dart';
import 'application/customer_position_projector.dart';

void main() {
  runApp(const ZarPlusApp());
}

class ZarPlusApp extends StatelessWidget {
  const ZarPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZAR+',
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.light,
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink());
      },
      home: const ZarShell(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const warmAccent = Color(0xFFC08A3D);
    final surface = isDark ? const Color(0xFF151515) : const Color(0xFFFBFAF8);
    final card = isDark ? const Color(0xFF1D1D1D) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF4F4F4) : const Color(0xFF121212);
    final textSecondary = isDark ? const Color(0xFFA9A9A9) : const Color(0xFF707070);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Vazirmatn',
      colorScheme: ColorScheme.fromSeed(seedColor: warmAccent, brightness: brightness, surface: card),
      textTheme: TextTheme(
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary, height: 1.35),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary, height: 1.35),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary, height: 1.45),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary, height: 1.55),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary, height: 1.6),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      dividerColor: isDark ? const Color(0xFF303030) : const Color(0xFFECEAE6),
      appBarTheme: AppBarTheme(elevation: 0, backgroundColor: surface, foregroundColor: textPrimary, centerTitle: false),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF252525) : const Color(0xFFF6F4F1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: warmAccent, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
    );
  }
}

enum RecordType { settlement, deal }

enum SettlementStatus { open, completed, cancelled }

enum HistoryFilter { all, buy, sell, receive, deliver, completed, cancelled }

class AppPerson {
  AppPerson({required this.id, required this.name, this.phone, this.note, this.archived = false});

  final String id;
  final String name;
  final String? phone;
  final String? note;
  final bool archived;

  AppPerson copyWith({String? name, String? phone, String? note, bool? archived}) {
    return AppPerson(id: id, name: name ?? this.name, phone: phone ?? this.phone, note: note ?? this.note, archived: archived ?? this.archived);
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
    this.linkedSettlementIds = const [],
    this.goldFineness,
    this.goldPriceReferenceFineness,
    this.goldInputWeight,
    this.goldInputUnit,
    this.goldPriceUnit,
    this.goldEquivalentWeight,
    this.goldEquivalentPrice,
    this.tomanRate,
    this.totalToman,
  });

  final String id;
  final RecordType type;
  final String operationLabel;
  final String personId;
  final String amountDisplay;
  final String assetLabel;
  final Jalali date;
  final String? currencyCode;
  final TimeOfDay? time;
  final SettlementStatus status;
  final String? note;
  final List<String> linkedSettlementIds;
  final String? goldFineness;
  final String? goldPriceReferenceFineness;
  final String? goldInputWeight;
  final String? goldInputUnit;
  final String? goldPriceUnit;
  final String? goldEquivalentWeight;
  final String? goldEquivalentPrice;
  final String? tomanRate;
  final int? totalToman;

  bool get isObligation => type == RecordType.settlement && (operationLabel == 'دریافت' || operationLabel == 'تحویل');

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
      linkedSettlementIds: linkedSettlementIds,
      goldFineness: goldFineness ?? this.goldFineness,
      goldPriceReferenceFineness: goldPriceReferenceFineness ?? this.goldPriceReferenceFineness,
      goldInputWeight: goldInputWeight ?? this.goldInputWeight,
      goldInputUnit: goldInputUnit ?? this.goldInputUnit,
      goldPriceUnit: goldPriceUnit ?? this.goldPriceUnit,
      goldEquivalentWeight: goldEquivalentWeight ?? this.goldEquivalentWeight,
      goldEquivalentPrice: goldEquivalentPrice ?? this.goldEquivalentPrice,
      tomanRate: tomanRate ?? this.tomanRate,
      totalToman: totalToman ?? this.totalToman,
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
}

String formatJalaliDate(Jalali date) => '${toPersianDigits(date.day.toString())} ${monthName(date.month)} ${toPersianDigits(date.year.toString())}';

String monthName(int month) {
  const months = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
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

bool isSameJalali(Jalali a, Jalali b) => a.year == b.year && a.month == b.month && a.day == b.day;

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
  const CurrencyOption({required this.code, required this.persianName, required this.shortLabel});

  final String code;
  final String persianName;
  final String shortLabel;

  String get displayLabel => '$persianName — $code';
}

const List<CurrencyOption> kCurrencyOptions = [
  CurrencyOption(code: 'USD', persianName: 'دلار آمریکا', shortLabel: 'دلار'),
  CurrencyOption(code: 'EUR', persianName: 'یورو', shortLabel: 'یورو'),
  CurrencyOption(code: 'AED', persianName: 'درهم امارات', shortLabel: 'درهم'),
  CurrencyOption(code: 'TRY', persianName: 'لیر ترکیه', shortLabel: 'لیر'),
  CurrencyOption(code: 'GBP', persianName: 'پوند انگلیس', shortLabel: 'پوند'),
  CurrencyOption(code: 'CAD', persianName: 'دلار کانادا', shortLabel: 'دلار کانادا'),
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
  final digitsOnly = RegExp(r'\d+').allMatches(english).map((e) => e.group(0)!).join();
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

class ZarShell extends StatefulWidget {
  const ZarShell({super.key});

  @override
  State<ZarShell> createState() => _ZarShellState();
}

class _ZarShellState extends State<ZarShell> {
  int _index = 0;

  final List<AppPerson> _people = [
    AppPerson(id: 'p1', name: 'علی رضایی', phone: '۰۹۱۲۱۲۳۴۵۶۷', note: 'مشتری ثابت'),
    AppPerson(id: 'p2', name: 'رضا محمدی', phone: '۰۹۱۲۴۴۴۵۵۶۶'),
    AppPerson(id: 'p3', name: 'حسن کریمی', phone: '۰۹۱۲۳۳۳۴۴۵۵'),
    AppPerson(id: 'p4', name: 'مهدی احمدی', note: 'ترجیح تماس بعدازظهر'),
  ];

  late final List<AppRecord> _records = [
    AppRecord(
      id: 's1',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p2',
      amountDisplay: '\$10,000',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali.now().addDays(-1),
      time: const TimeOfDay(hour: 11, minute: 0),
    ),
    AppRecord(
      id: 's2',
      type: RecordType.settlement,
      operationLabel: 'دریافت',
      personId: 'p1',
      amountDisplay: '۲۵۰',
      assetLabel: 'گرم طلا',
      date: Jalali.now(),
      time: const TimeOfDay(hour: 10, minute: 30),
    ),
    AppRecord(
      id: 's3',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p3',
      amountDisplay: '€5,000',
      assetLabel: 'ارز',
      currencyCode: 'EUR',
      date: Jalali.now(),
      time: const TimeOfDay(hour: 14, minute: 45),
    ),
    AppRecord(id: 's4', type: RecordType.settlement, operationLabel: 'دریافت', personId: 'p4', amountDisplay: '۴۰۰', assetLabel: 'گرم طلا', date: Jalali.now().addDays(1)),
    AppRecord(
      id: 'd1',
      type: RecordType.deal,
      operationLabel: 'خرید',
      personId: 'p1',
      amountDisplay: '۳۵۰',
      assetLabel: 'گرم طلا',
      date: Jalali.now(),
      linkedSettlementIds: const ['s2'],
      note: 'معامله نقدی با تسویه مرحله‌ای',
    ),
    AppRecord(
      id: 's5',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p2',
      amountDisplay: '\$8,000',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali.now().addDays(-2),
      time: const TimeOfDay(hour: 12, minute: 20),
      status: SettlementStatus.completed,
    ),
    AppRecord(
      id: 's6',
      type: RecordType.settlement,
      operationLabel: 'دریافت',
      personId: 'p1',
      amountDisplay: '۳۰۰',
      assetLabel: 'گرم طلا',
      date: Jalali.now().addDays(-1),
      time: const TimeOfDay(hour: 9, minute: 10),
      status: SettlementStatus.cancelled,
    ),
  ];

  String personName(String id) {
    return _people
        .firstWhere(
          (e) => e.id == id,
          orElse: () => AppPerson(id: '-', name: 'نامشخص'),
        )
        .name;
  }

  List<AppPerson> get activePeople => _people.where((p) => !p.archived).toList(growable: false);

  List<AppRecord> get openObligations => _records.where((r) => r.isObligation && r.status == SettlementStatus.open).toList(growable: false);

  List<AppRecord> get calendarRecords => _records.where((r) => r.status == SettlementStatus.open).toList(growable: false);

  List<AppRecord> get historyRecords =>
      _records.where((r) => r.type == RecordType.deal || r.status == SettlementStatus.completed || r.status == SettlementStatus.cancelled).toList(growable: false)
        ..sort((a, b) => b.date.compareTo(a.date));

  void _updateRecord(AppRecord updated) {
    final index = _records.indexWhere((r) => r.id == updated.id);
    if (index == -1) return;
    setState(() {
      _records[index] = updated;
    });
  }

  Future<void> _openQuickAddSheet() async {
    final draft = await showModalBottomSheet<QuickAddDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuickAddSheet(people: activePeople),
    );
    if (draft == null) return;

    final isCurrency = draft.asset == 'ارز';
    final newRecord = AppRecord(
      id: 'n${DateTime.now().millisecondsSinceEpoch}',
      type: (draft.operation == 'دریافت' || draft.operation == 'تحویل') ? RecordType.settlement : RecordType.deal,
      operationLabel: draft.operation,
      personId: draft.personId,
      amountDisplay: isCurrency && draft.currencyCode != null ? formatCurrencyAmount(draft.amount, draft.currencyCode!) : draft.amount,
      assetLabel: draft.asset == 'طلا' ? 'گرم طلا' : 'ارز',
      currencyCode: isCurrency ? draft.currencyCode : null,
      date: draft.date,
      time: draft.time,
      note: draft.note.isEmpty ? null : 'یادآوری: ${draft.reminder} • ${draft.note}',
    );

    setState(() {
      _records.add(newRecord);
    });
  }

  Future<void> _openRecord(AppRecord record) async {
    if (record.type == RecordType.deal) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => DealDetailSheet(
          record: record,
          personName: personName(record.personId),
          linkedSettlements: _records.where((e) => record.linkedSettlementIds.contains(e.id)).toList(growable: false),
          onOpenSettlement: (settlement) {
            Navigator.pop(context);
            _openRecord(settlement);
          },
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SettlementActionSheet(
        record: record,
        personName: personName(record.personId),
        onComplete: () {
          _updateRecord(record.copyWith(status: SettlementStatus.completed));
          Navigator.pop(context);
        },
        onCancel: () {
          _updateRecord(record.copyWith(status: SettlementStatus.cancelled));
          Navigator.pop(context);
        },
        onEdit: () async {
          final updated = await showModalBottomSheet<AppRecord>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => EditRecordSheet(record: record, personName: personName(record.personId)),
          );
          if (updated != null) {
            _updateRecord(updated);
          }
        },
        onReschedule: () async {
          final navigator = Navigator.of(context);
          final date = await pickJalaliDate(context, record.date);
          if (!mounted || date == null) return;
          final time = await pickCupertinoTime(context, record.time);
          if (!mounted) return;
          _updateRecord(record.copyWith(date: date, time: time));
          navigator.pop();
        },
        onSnooze: () async {
          final dateTime = await showReminderPickerBottomSheet(context, initialDate: record.date, initialTime: record.time);
          if (dateTime == null) return;
          _updateRecord(record.copyWith(date: dateTime.$1, time: dateTime.$2));
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _savePerson(AppPerson person) async {
    final index = _people.indexWhere((p) => p.id == person.id);
    setState(() {
      if (index == -1) {
        _people.add(person);
      } else {
        _people[index] = person;
      }
    });
  }

  void _archivePerson(String personId) {
    final index = _people.indexWhere((p) => p.id == personId);
    if (index == -1) return;
    setState(() {
      _people[index] = _people[index].copyWith(archived: true);
    });
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(records: openObligations, personName: personName, onTapRecord: _openRecord),
      CalendarScreen(records: calendarRecords, personName: personName, onTapRecord: _openRecord),
      const SizedBox.shrink(),
      PeopleScreen(
        people: activePeople,
        records: _records,
        onAddPerson: () async {
          final person = await showModalBottomSheet<AppPerson>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const PersonEditorSheet());
          if (person != null) {
            await _savePerson(person);
          }
        },
        onOpenPerson: (person) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PersonDetailScreen(
                person: person,
                records: _records,
                personName: personName,
                onTapRecord: _openRecord,
                onEditPerson: (target) async {
                  final edited = await showModalBottomSheet<AppPerson>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => PersonEditorSheet(existing: target),
                  );
                  if (edited != null) {
                    await _savePerson(edited);
                  }
                },
                onArchivePerson: _archivePerson,
              ),
            ),
          );
        },
      ),
      HistoryScreen(records: historyRecords, personName: personName, onTapRecord: _openRecord),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: ZBottomBar(
        currentIndex: _index,
        onTap: (value) {
          if (value == 2) {
            _openQuickAddSheet();
            return;
          }
          setState(() => _index = value);
        },
      ),
    );
  }
}

class ZBottomBar extends StatelessWidget {
  const ZBottomBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final inactive = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    Widget navItem({required int index, required IconData icon, required String label}) {
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
                  style: TextStyle(fontSize: 11.5, color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
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
                  navItem(index: 1, icon: CupertinoIcons.calendar, label: 'تقویم'),
                  const SizedBox(width: 76),
                  navItem(index: 3, icon: CupertinoIcons.person_2, label: 'اشخاص'),
                  navItem(index: 4, icon: CupertinoIcons.clock, label: 'سوابق'),
                ],
              ),
              GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: active,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: active.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 6))],
                  ),
                  child: const Icon(CupertinoIcons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.records, required this.personName, required this.onTapRecord});

  final List<AppRecord> records;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTapRecord;

  @override
  Widget build(BuildContext context) {
    final now = Jalali.now();
    final overdue = records.where((r) => r.date.compareTo(now) < 0).toList(growable: false);
    final today = records.where((r) => isSameJalali(r.date, now)).toList(growable: false);
    final tomorrow = records.where((r) => isSameJalali(r.date, now.addDays(1))).toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Directionality(textDirection: TextDirection.ltr, child: Text('ZAR+')),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text('امروز\n${formatJalaliDate(now)}', style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        _section(context, 'عقب‌افتاده', overdue, overdue: true),
        _section(context, 'امروز', today),
        _section(context, 'فردا', tomorrow),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<AppRecord> items, {bool overdue = false}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: overdue ? const Color(0xFF9D3636) : null)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const _ZEmptyRow(label: 'موردی ثبت نشده است.')
            else
              ...items.map((item) => SettlementRow(record: item, personName: personName(item.personId), onTap: () => onTapRecord(item), showOverdueTone: overdue)),
          ],
        ),
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.records, required this.personName, required this.onTapRecord});

  final List<AppRecord> records;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTapRecord;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Jalali _month = Jalali.now().withDay(1);
  Jalali _selected = Jalali.now();

  double _expandedHeaderExtent(BuildContext context) {
    const horizontalPadding = 32.0;
    const headerAndVerticalPadding = 66.0;
    const gridVerticalPadding = 16.0;
    const cellAspectRatio = 0.9;
    final gridWidth = MediaQuery.sizeOf(context).width - horizontalPadding;
    final cellHeight = (gridWidth / 7) / cellAspectRatio;
    return headerAndVerticalPadding +
        gridVerticalPadding +
        (CalendarMonthGrid.rowCountFor(_month) * cellHeight);
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = widget.records.where((e) => isSameJalali(e.date, _selected)).toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverAppBar(title: const Text('تقویم'), pinned: true),
        SliverPersistentHeader(
          pinned: true,
          delegate: _CalendarHeaderDelegate(
            minExtentValue: 74,
            maxExtentValue: _expandedHeaderExtent(context),
            builder: (context, shrink) {
              final compact = shrink > 0.7;
              return Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(onPressed: () => setState(() => _month = _month.addMonths(-1)), icon: const Icon(CupertinoIcons.chevron_right)),
                        Expanded(
                          child: Center(child: Text('${monthName(_month.month)} ${toPersianDigits(_month.year.toString())}', style: Theme.of(context).textTheme.titleMedium)),
                        ),
                        IconButton(onPressed: () => setState(() => _month = _month.addMonths(1)), icon: const Icon(CupertinoIcons.chevron_left)),
                      ],
                    ),
                    if (!compact)
                      Expanded(
                        child: CalendarMonthGrid(
                          month: _month,
                          selected: _selected,
                          eventDays: widget.records.map((e) => e.date).toList(growable: false),
                          onDayTap: (date) => setState(() => _selected = date),
                        ),
                      ),
                    if (compact)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Text('برنامه روز ${formatJalaliDate(_selected)}', style: Theme.of(context).textTheme.bodyLarge),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Text('برنامه روز • ${formatJalaliDate(_selected)}', style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (selectedEvents.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('برای این روز موردی ثبت نشده است.')),
            ),
          )
        else
          SliverList.builder(
            itemCount: selectedEvents.length,
            itemBuilder: (context, index) {
              final item = selectedEvents[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SettlementRow(record: item, personName: widget.personName(item.personId), onTap: () => widget.onTapRecord(item)),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, required this.people, required this.records, required this.onAddPerson, required this.onOpenPerson});

  final List<AppPerson> people;
  final List<AppRecord> records;
  final VoidCallback onAddPerson;
  final ValueChanged<AppPerson> onOpenPerson;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.people.where((p) => p.name.contains(query.trim())).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('اشخاص')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'جستجو در اشخاص', prefixIcon: Icon(CupertinoIcons.search)),
                    onChanged: (value) => setState(() => query = value),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(onPressed: widget.onAddPerson, icon: const Icon(CupertinoIcons.add, size: 16), label: const Text('افزودن')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(color: Theme.of(context).dividerColor),
                itemBuilder: (context, index) {
                  final person = filtered[index];
                  final openCount = widget.records.where((r) => r.personId == person.id && r.status == SettlementStatus.open && r.isObligation).length;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                      child: Text(person.name.isEmpty ? '-' : person.name[0], style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    ),
                    title: Text(person.name, style: Theme.of(context).textTheme.bodyLarge),
                    subtitle: Text('${toPersianDigits(openCount.toString())} تعهد باز', style: Theme.of(context).textTheme.bodyMedium),
                    trailing: const Icon(CupertinoIcons.chevron_left, size: 18),
                    onTap: () => widget.onOpenPerson(person),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({super.key, required this.person, required this.records, required this.personName, required this.onTapRecord, required this.onEditPerson, required this.onArchivePerson, this.position = const ZarCustomerPosition.empty()});

  final AppPerson person;
  final List<AppRecord> records;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTapRecord;
  final ValueChanged<AppPerson> onEditPerson;
  final ValueChanged<String> onArchivePerson;
  final ZarCustomerPosition position;

  @override
  Widget build(BuildContext context) {
    final personItems = records.where((e) => e.personId == person.id).toList(growable: false)..sort((a, b) => b.date.compareTo(a.date));
    final openItems = personItems.where((e) => e.status == SettlementStatus.open && e.isObligation).toList(growable: false);
    final historyItems = personItems
        .where(
          (e) =>
              e.type == RecordType.deal ||
              e.status != SettlementStatus.open,
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('جزئیات شخص')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(person.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(person.phone ?? 'شماره تماس ثبت نشده است.', style: Theme.of(context).textTheme.bodyMedium),
          if ((person.note ?? '').trim().isNotEmpty) ...[const SizedBox(height: 4), Text(person.note!, style: Theme.of(context).textTheme.bodyMedium)],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(onPressed: () => onEditPerson(person), icon: const Icon(CupertinoIcons.pencil, size: 16), label: const Text('ویرایش')),
              FilledButton.tonalIcon(
                onPressed: person.phone == null
                    ? null
                    : () async {
                        final uri = Uri(scheme: 'tel', path: phoneToEnglishDigits(person.phone!));
                        await launchUrl(uri);
                      },
                icon: const Icon(CupertinoIcons.phone, size: 16),
                label: const Text('تماس'),
              ),
              TextButton.icon(onPressed: () => onArchivePerson(person.id), icon: const Icon(CupertinoIcons.archivebox, size: 16), label: const Text('آرشیو')),
            ],
          ),
          const SizedBox(height: 16),
          _customerCard(
            context,
            title: 'تعهدات باز',
            children: [
              _positionSide(context, 'باید دریافت کنم', position.receive),
              const SizedBox(height: 12),
              _positionSide(context, 'باید تحویل بدهم', position.deliver),
              const Divider(height: 24),
              if (openItems.isEmpty)
                const _ZEmptyRow(label: 'تعهد باز وجود ندارد.')
              else
                ...openItems.map((e) => SettlementRow(record: e, personName: personName(e.personId), onTap: () => onTapRecord(e))),
            ],
          ),
          const SizedBox(height: 18),
          _customerCard(
            context,
            title: 'سوابق معاملات',
            children: historyItems.isEmpty
                ? const [_ZEmptyRow(label: 'معامله یا تسویه‌ای ثبت نشده است.')]
                : historyItems.map((e) => SettlementRow(record: e, personName: personName(e.personId), onTap: () => onTapRecord(e))).toList(growable: false),
          ),
          const SizedBox(height: 18),
          _customerCard(
            context,
            title: 'خلاصه فعالیت',
            children: [
              _activityRow('خرید', position.buyCount),
              _activityRow('فروش', position.sellCount),
              _activityRow('دریافت', position.receiveCount),
              _activityRow('تحویل', position.deliverCount),
              const Divider(height: 20),
              Text('آخرین فعالیت: ${_lastActivityLabel(position.lastActivityAt)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _customerCard(BuildContext context, {required String title, required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 12), ...children]),
  );

  Widget _positionSide(BuildContext context, String title, List<ZarCustomerPositionItem> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 6),
      if (items.isEmpty)
        Text('موردی وجود ندارد.', style: Theme.of(context).textTheme.bodyMedium)
      else
        ...items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 4), child: _positionItem(item))),
    ],
  );

  Widget _positionItem(ZarCustomerPositionItem item) {
    const gold = Color(0xFF9A6700);
    const currency = Color(0xFF2F6F73);
    return switch (item) {
      ZarCustomerGoldPosition(:final fineness, :final grams) => Text(
        'طلای ${fineness == null ? 'عیار نامشخص' : 'عیار ${toPersianDigits(fineness)}'}: ${_formatPositionDecimal(grams)} گرم',
        style: const TextStyle(color: gold, fontWeight: FontWeight.w600),
      ),
      ZarCustomerCurrencyPosition(:final code, :final decimalAmount) => Directionality(
        textDirection: TextDirection.rtl,
        child: Text('${code == 'TOMAN' ? 'تومان' : code}: ${_formatPositionDecimal(decimalAmount)}', style: const TextStyle(color: currency, fontWeight: FontWeight.w600)),
      ),
    };
  }

  Widget _activityRow(String label, int count) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(toPersianDigits(count.toString()))]),
  );

  String _lastActivityLabel(DateTime? value) {
    if (value == null) return 'ثبت نشده';
    final local = value.toLocal();
    final jalali = Jalali.fromDateTime(local);
    return '${formatJalaliDate(jalali)}، ${toPersianDigits(local.hour.toString().padLeft(2, '0'))}:${toPersianDigits(local.minute.toString().padLeft(2, '0'))}';
  }

  String _formatPositionDecimal(String value) {
    final parts = value.split('.');
    final grouped = parts.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '٬');
    return toPersianDigits(parts.length == 1 ? grouped : '$grouped٫${parts[1]}');
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.records, required this.personName, this.onTapRecord});

  final List<AppRecord> records;
  final String Function(String) personName;
  final ValueChanged<AppRecord>? onTapRecord;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String query = '';
  HistoryFilter filter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final items =
        widget.records
            .where(_matchesFilter)
            .where((record) {
              if (normalizedQuery.isEmpty) return true;
              final searchable = <String>[
                widget.personName(record.personId),
                record.operationLabel,
                record.assetLabel,
                record.amountDisplay,
                record.currencyCode ?? '',
                record.note ?? '',
                if (record.type == RecordType.settlement) record.statusLabel(),
              ].join(' ').toLowerCase();
              return searchable.contains(normalizedQuery);
            })
            .toList(growable: false)
          ..sort(_compareNewestFirst);

    return Scaffold(
      appBar: AppBar(title: const Text('سوابق')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(CupertinoIcons.search), hintText: 'جستجو'),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(context, 'همه', HistoryFilter.all),
                  _filterChip(context, 'خرید', HistoryFilter.buy),
                  _filterChip(context, 'فروش', HistoryFilter.sell),
                  _filterChip(context, 'دریافت', HistoryFilter.receive),
                  _filterChip(context, 'تحویل', HistoryFilter.deliver),
                  _filterChip(context, 'انجام‌شده', HistoryFilter.completed),
                  _filterChip(context, 'لغوشده', HistoryFilter.cancelled),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('نتیجه‌ای پیدا نشد.'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return HistoryRecordRow(
                          key: ValueKey('history-record-${item.id}'),
                          record: item,
                          personName: widget.personName(item.personId),
                          onTap: widget.onTapRecord == null ? null : () => widget.onTapRecord!(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(BuildContext context, String label, HistoryFilter value) {
    final selected = filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
      side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35) : Theme.of(context).dividerColor),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      onSelected: (_) => setState(() => filter = value),
    );
  }

  bool _matchesFilter(AppRecord record) {
    switch (filter) {
      case HistoryFilter.all:
        return true;
      case HistoryFilter.buy:
        return record.type == RecordType.deal && record.operationLabel == 'خرید';
      case HistoryFilter.sell:
        return record.type == RecordType.deal && record.operationLabel == 'فروش';
      case HistoryFilter.receive:
        return record.type == RecordType.settlement && record.operationLabel == 'دریافت';
      case HistoryFilter.deliver:
        return record.type == RecordType.settlement && record.operationLabel == 'تحویل';
      case HistoryFilter.completed:
        return record.type == RecordType.settlement && record.status == SettlementStatus.completed;
      case HistoryFilter.cancelled:
        return record.type == RecordType.settlement && record.status == SettlementStatus.cancelled;
    }
  }

  int _compareNewestFirst(AppRecord a, AppRecord b) {
    final date = b.date.compareTo(a.date);
    if (date != 0) return date;
    final aMinutes = (a.time?.hour ?? -1) * 60 + (a.time?.minute ?? 0);
    final bMinutes = (b.time?.hour ?? -1) * 60 + (b.time?.minute ?? 0);
    return bMinutes.compareTo(aMinutes);
  }
}

class HistoryRecordRow extends StatelessWidget {
  const HistoryRecordRow({super.key, required this.record, required this.personName, this.onTap});

  final AppRecord record;
  final String personName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSettlement = record.type == RecordType.settlement;
    final statusColor = record.status == SettlementStatus.completed ? const Color(0xFF2F7D4C) : const Color(0xFF9D3636);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
                  Text(record.operationLabel, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(personName, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AmountText(record.amountDisplay),
                      Text(record.assetLabel, style: theme.textTheme.bodyMedium),
                      if (record.currencyCode != null)
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(record.currencyCode!, style: theme.textTheme.bodyMedium),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatJalaliDate(record.date), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(record.timeLabel(), style: theme.textTheme.bodyMedium),
                if (isSettlement) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.statusLabel(),
                    style: theme.textTheme.bodyMedium?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettlementRow extends StatelessWidget {
  const SettlementRow({super.key, required this.record, required this.personName, this.onTap, this.showOverdueTone = false});

  final AppRecord record;
  final String personName;
  final VoidCallback? onTap;
  final bool showOverdueTone;

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
                  Text(record.operationLabel, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(personName, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.84))),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      AmountText(record.amountDisplay),
                      Text(record.assetLabel, style: theme.textTheme.bodyMedium),
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
                    style: theme.textTheme.bodyMedium?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
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

class _ZEmptyRow extends StatelessWidget {
  const _ZEmptyRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
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
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class SettlementActionSheet extends StatelessWidget {
  const SettlementActionSheet({
    super.key,
    required this.record,
    required this.personName,
    required this.onComplete,
    required this.onEdit,
    required this.onReschedule,
    required this.onSnooze,
    required this.onCancel,
  });

  final AppRecord record;
  final String personName;
  final VoidCallback onComplete;
  final VoidCallback onEdit;
  final VoidCallback onReschedule;
  final VoidCallback onSnooze;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${record.operationLabel} • $personName', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('${record.assetLabel} • ${record.amountDisplay}', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          _action(context, 'انجام شد', CupertinoIcons.check_mark_circled, onComplete),
          _action(context, 'ویرایش', CupertinoIcons.pencil, onEdit),
          _action(context, 'زمان‌بندی مجدد', CupertinoIcons.calendar, onReschedule),
          _action(context, 'یادآوری بعداً', CupertinoIcons.bell, onSnooze),
          _action(context, 'لغو', CupertinoIcons.xmark_circle, onCancel, destructive: true),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, String text, IconData icon, VoidCallback onTap, {bool destructive = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: destructive ? Colors.red : null),
      title: Text(text, style: TextStyle(color: destructive ? Colors.red : null)),
      onTap: onTap,
    );
  }
}

class DealDetailSheet extends StatelessWidget {
  const DealDetailSheet({super.key, required this.record, required this.personName, required this.linkedSettlements, required this.onOpenSettlement});

  final AppRecord record;
  final String personName;
  final List<AppRecord> linkedSettlements;
  final ValueChanged<AppRecord> onOpenSettlement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('جزئیات معامله (${record.operationLabel})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(personName, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AmountText(record.amountDisplay),
              Text(record.assetLabel),
              if (record.currencyCode != null)
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(record.currencyCode!),
                ),
              Text(formatJalaliDate(record.date), style: Theme.of(context).textTheme.bodyMedium),
              Text(record.timeLabel(), style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          if (record.goldFineness != null) ...[
            const SizedBox(height: 8),
            Text('عیار: ${toPersianDigits(record.goldFineness.toString())}', style: Theme.of(context).textTheme.bodyMedium),
            if (record.goldInputWeight != null)
              Text(
                'وزن ثبت‌شده: ${toPersianDigits(record.goldInputWeight!)} ${record.goldInputUnit == 'mesghal' ? 'مثقال' : 'گرم'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (record.goldEquivalentWeight != null)
              Text(
                'معادل وزن: ${toPersianDigits(record.goldEquivalentWeight!)} ${record.goldInputUnit == 'mesghal' ? 'گرم' : 'مثقال'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
          if (record.tomanRate != null) ...[
            const SizedBox(height: 6),
            Text(
              record.assetLabel == 'ارز'
                  ? 'نرخ هر واحد: ${toPersianDigits(record.tomanRate!)} تومان'
                  : 'قیمت هر ${record.goldPriceUnit == 'mesghal' ? 'مثقال' : 'گرم'}: ${toPersianDigits(record.tomanRate!)} تومان',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (record.goldEquivalentPrice != null)
              Text(
                'قیمت معادل هر ${record.goldPriceUnit == 'mesghal' ? 'گرم' : 'مثقال'}: ${toPersianDigits(record.goldEquivalentPrice!)} تومان',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
          if (record.totalToman != null) ...[
            const SizedBox(height: 6),
            Text(
              'مبلغ کل: ${toPersianDigits(NumberFormat.decimalPattern('en_US').format(record.totalToman))} تومان',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          if ((record.note ?? '').isNotEmpty) ...[const SizedBox(height: 8), Text(record.note!, style: Theme.of(context).textTheme.bodyMedium)],
          const SizedBox(height: 14),
          Text('تعهدهای لینک‌شده', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (linkedSettlements.isEmpty) const Text('تعهد لینک‌شده‌ای ندارد.') else ...linkedSettlements.map((e) => SettlementRow(record: e, personName: personName, onTap: () => onOpenSettlement(e))),
        ],
      ),
    );
  }
}

class EditRecordSheet extends StatefulWidget {
  const EditRecordSheet({super.key, required this.record, required this.personName});

  final AppRecord record;
  final String personName;

  @override
  State<EditRecordSheet> createState() => _EditRecordSheetState();
}

class _EditRecordSheetState extends State<EditRecordSheet> {
  late final TextEditingController _amountController = TextEditingController(text: widget.record.amountDisplay);
  late final TextEditingController _noteController = TextEditingController(text: widget.record.note ?? '');
  late String? _currencyCode = widget.record.currencyCode ?? (widget.record.assetLabel == 'ارز' ? 'USD' : null);

  CurrencyOption? get _selectedCurrency => currencyByCode(_currencyCode);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ویرایش تعهد', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (widget.record.assetLabel == 'ارز')
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('نوع ارز'),
                subtitle: Text(_selectedCurrency?.displayLabel ?? 'انتخاب نوع ارز'),
                trailing: const Icon(CupertinoIcons.chevron_down),
                onTap: () async {
                  final selected = await showCurrencyPickerBottomSheet(context, _currencyCode);
                  if (selected != null) {
                    setState(() => _currencyCode = selected.code);
                  }
                },
              ),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'مبلغ/مقدار'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'توضیحات'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final amountInput = _amountController.text.trim();
                  final amountDisplay = widget.record.assetLabel == 'ارز' && _currencyCode != null ? formatCurrencyAmount(amountInput, _currencyCode!) : amountInput;
                  Navigator.pop(
                    context,
                    widget.record.copyWith(amountDisplay: amountDisplay, currencyCode: widget.record.assetLabel == 'ارز' ? _currencyCode : null, note: _noteController.text.trim()),
                  );
                },
                child: const Text('ذخیره'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PersonEditorSheet extends StatefulWidget {
  const PersonEditorSheet({super.key, this.existing});

  final AppPerson? existing;

  @override
  State<PersonEditorSheet> createState() => _PersonEditorSheetState();
}

class _PersonEditorSheetState extends State<PersonEditorSheet> {
  late final TextEditingController _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _phoneController = TextEditingController(text: widget.existing?.phone ?? '');
  late final TextEditingController _noteController = TextEditingController(text: widget.existing?.note ?? '');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'افزودن شخص' : 'ویرایش شخص', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'نام'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'شماره تماس (اختیاری)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'یادداشت (اختیاری)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  final person = AppPerson(
                    id: widget.existing?.id ?? 'p${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
                    note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
                    archived: widget.existing?.archived ?? false,
                  );
                  Navigator.pop(context, person);
                },
                child: const Text('ذخیره'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key, required this.people});

  final List<AppPerson> people;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  String? _operation;
  String? _asset;
  String? _currencyCode;
  AppPerson? _person;
  Jalali _date = Jalali.now();
  TimeOfDay? _time;
  String _reminder = '۱۵ دقیقه';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  CurrencyOption? get _selectedCurrency => currencyByCode(_currencyCode);

  @override
  Widget build(BuildContext context) {
    final currencyReady = _asset != 'ارز' || _currencyCode != null;
    final ready = _operation != null && _asset != null && _person != null && currencyReady && _amountController.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(100)),
              ),
            ),
            const SizedBox(height: 16),
            Text('ثبت سریع', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['خرید', 'فروش', 'دریافت', 'تحویل'].map((value) => _chip(context, value, _operation == value, () => setState(() => _operation = value))).toList(),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['طلا', 'ارز']
                  .map(
                    (value) => _chip(
                      context,
                      value,
                      _asset == value,
                      _operation == null
                          ? null
                          : () => setState(() {
                              _asset = value;
                              if (_asset != 'ارز') {
                                _currencyCode = null;
                              } else {
                                _currencyCode ??= 'USD';
                              }
                            }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('شخص'),
              subtitle: Text(_person?.name ?? 'انتخاب شخص'),
              trailing: const Icon(CupertinoIcons.chevron_down),
              onTap: () async {
                final selected = await showPersonPickerBottomSheet(context, widget.people);
                if (selected != null) setState(() => _person = selected);
              },
            ),
            if (_asset == 'ارز')
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('نوع ارز'),
                subtitle: Text(_selectedCurrency?.displayLabel ?? 'انتخاب نوع ارز'),
                trailing: const Icon(CupertinoIcons.chevron_down),
                onTap: () async {
                  final selected = await showCurrencyPickerBottomSheet(context, _currencyCode);
                  if (selected != null) {
                    setState(() => _currencyCode = selected.code);
                  }
                },
              ),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _asset == 'طلا' ? 'مقدار' : 'مبلغ'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تاریخ'),
              subtitle: Text(formatJalaliDate(_date)),
              trailing: const Icon(CupertinoIcons.calendar),
              onTap: () async {
                final selected = await pickJalaliDate(context, _date);
                if (selected != null) setState(() => _date = selected);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ساعت'),
              subtitle: Text(_time == null ? 'بدون ساعت' : '${toPersianDigits(_time!.hour.toString().padLeft(2, '0'))}:${toPersianDigits(_time!.minute.toString().padLeft(2, '0'))}'),
              trailing: const Icon(CupertinoIcons.time),
              onTap: () async {
                final selected = await pickCupertinoTime(context, _time);
                if (selected != null) setState(() => _time = selected);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('یادآوری'),
              subtitle: Text(_reminder),
              trailing: const Icon(CupertinoIcons.bell),
              onTap: () async {
                final selected = await showReminderTextPickerBottomSheet(context, _reminder);
                if (selected != null) setState(() => _reminder = selected);
              },
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: ready
                    ? () {
                        Navigator.pop(
                          context,
                          QuickAddDraft(
                            operation: _operation!,
                            asset: _asset!,
                            personId: _person!.id,
                            amount: _amountController.text.trim(),
                            date: _date,
                            time: _time,
                            reminder: _reminder,
                            note: _noteController.text.trim(),
                            currencyCode: _currencyCode,
                          ),
                        );
                      }
                    : null,
                child: const Text('ثبت'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, bool selected, VoidCallback? onTap) {
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      showCheckmark: false,
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
      side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35) : Theme.of(context).dividerColor),
      onSelected: onTap == null ? null : (_) => onTap(),
    );
  }
}

class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({super.key, required this.month, required this.selected, required this.eventDays, required this.onDayTap});

  final Jalali month;
  final Jalali selected;
  final List<Jalali> eventDays;
  final ValueChanged<Jalali> onDayTap;

  @override
  Widget build(BuildContext context) {
    const weekTitles = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final firstWeekday = ((month.toDateTime().weekday + 1) % 7);
    final daysInMonth = month.monthLength;
    final cells = <Widget>[];

    for (final title in weekTitles) {
      cells.add(Center(child: Text(title, style: Theme.of(context).textTheme.bodyMedium)));
    }
    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = month.withDay(day);
      final hasEvent = eventDays.any((e) => isSameJalali(e, date));
      final isSelected = isSameJalali(date, selected);
      cells.add(
        GestureDetector(
          key: ValueKey('calendar-day-$day'),
          onTap: () => onDayTap(date),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(toPersianDigits(day.toString()), style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                if (hasEvent)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.75), shape: BoxShape.circle),
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
      child: GridView.count(shrinkWrap: true, crossAxisCount: 7, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 0.9, children: cells),
    );
  }

  static int rowCountFor(Jalali month) {
    final firstWeekday = ((month.toDateTime().weekday + 1) % 7);
    final cellCount = 7 + firstWeekday + month.monthLength;
    return (cellCount / 7).ceil();
  }
}

class _CalendarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CalendarHeaderDelegate({required this.minExtentValue, required this.maxExtentValue, required this.builder});

  final double minExtentValue;
  final double maxExtentValue;
  final Widget Function(BuildContext, double) builder;

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return builder(context, progress);
  }

  @override
  bool shouldRebuild(covariant _CalendarHeaderDelegate oldDelegate) {
    return oldDelegate.minExtentValue != minExtentValue || oldDelegate.maxExtentValue != maxExtentValue;
  }
}

Future<AppPerson?> showPersonPickerBottomSheet(BuildContext context, List<AppPerson> people) {
  return showModalBottomSheet<AppPerson>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PersonPickerSheet(people: people),
  );
}

class _PersonPickerSheet extends StatefulWidget {
  const _PersonPickerSheet({required this.people});
  final List<AppPerson> people;

  @override
  State<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends State<_PersonPickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.people.where((e) => e.name.contains(query.trim())).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(CupertinoIcons.search), hintText: 'جستجو'),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final person = filtered[index];
                return ListTile(title: Text(person.name), onTap: () => Navigator.pop(context, person));
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<CurrencyOption?> showCurrencyPickerBottomSheet(BuildContext context, String? currentCode) {
  return showModalBottomSheet<CurrencyOption>(
    context: context,
    useSafeArea: true,
    builder: (_) => _CurrencyPickerSheet(currentCode: currentCode),
  );
}

class _CurrencyPickerSheet extends StatelessWidget {
  const _CurrencyPickerSheet({required this.currentCode});

  final String? currentCode;

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
          ...kCurrencyOptions.map(
            (option) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(option.displayLabel),
              trailing: currentCode == option.code ? const Icon(CupertinoIcons.check_mark) : null,
              onTap: () => Navigator.pop(context, option),
            ),
          ),
        ],
      ),
    );
  }
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
                IconButton(onPressed: () => setState(() => month = month.addMonths(-1)), icon: const Icon(CupertinoIcons.chevron_right)),
                Expanded(child: Center(child: Text('${monthName(month.month)} ${toPersianDigits(month.year.toString())}'))),
                IconButton(onPressed: () => setState(() => month = month.addMonths(1)), icon: const Icon(CupertinoIcons.chevron_left)),
              ],
            ),
            SizedBox(
              height: 280,
              child: CalendarMonthGrid(month: month, selected: selected, eventDays: const [], onDayTap: (d) => setState(() => selected = d)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('تایید')),
      ],
    );
  }
}

Future<TimeOfDay?> pickCupertinoTime(BuildContext context, TimeOfDay? initial) async {
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
              children: [CupertinoButton(onPressed: () => Navigator.pop(context), child: const Text('تایید'))],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(2025, 1, 1, selected.hour, selected.minute),
                use24hFormat: true,
                onDateTimeChanged: (value) => selected = TimeOfDay(hour: value.hour, minute: value.minute),
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
  final selected = await showReminderTextPickerBottomSheet(context, initialSelection);
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
  return (Jalali.fromDateTime(target), TimeOfDay(hour: target.hour, minute: target.minute));
}

Future<String?> showReminderTextPickerBottomSheet(BuildContext context, String current) async {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (_) {
      final items = ['۱۵ دقیقه', '۳۰ دقیقه', '۱ ساعت', '۳ ساعت', '۱ روز', 'فردا', 'سفارشی'];
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: ListView(
          shrinkWrap: true,
          children: items.map((e) => ListTile(title: Text(e), trailing: e == current ? const Icon(CupertinoIcons.check_mark) : null, onTap: () => Navigator.pop(context, e))).toList(),
        ),
      );
    },
  );
}
