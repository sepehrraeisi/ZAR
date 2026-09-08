import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'app_core.dart';
import 'application/operational_dashboard_projector.dart';
import 'application/operational_inventory_projector.dart';
import 'features/notifications/notification_center.dart';
import 'features/people/archived_people_screen.dart';
import 'features/reminders/record_reminder_registry.dart';
import 'features/reminders/reminder_model.dart';
import 'domain/zar_domain_models.dart';

void main() {
  runApp(const ZarPlusPhaseA2App());
}

class ZarPlusPhaseA2App extends StatelessWidget {
  const ZarPlusPhaseA2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZAR+',
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.light,
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink()),
      home: const PhaseA2Shell(),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const accent = Color(0xFFC08A3D);
    final surface = isDark ? const Color(0xFF151515) : const Color(0xFFFBFAF8);
    final card = isDark ? const Color(0xFF1D1D1D) : Colors.white;
    final primaryText = isDark ? const Color(0xFFF4F4F4) : const Color(0xFF121212);
    final secondaryText = isDark ? const Color(0xFFA9A9A9) : const Color(0xFF707070);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Vazirmatn',
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: brightness, surface: card),
      dividerColor: isDark ? const Color(0xFF303030) : const Color(0xFFECEAE6),
      textTheme: TextTheme(
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: primaryText, height: 1.35),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: primaryText, height: 1.35),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: primaryText, height: 1.45),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: primaryText, height: 1.55),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: secondaryText, height: 1.6),
      ),
      appBarTheme: AppBarTheme(elevation: 0, backgroundColor: surface, foregroundColor: primaryText, centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF252525) : const Color(0xFFF6F4F1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.2),
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

class PhaseA2Shell extends StatefulWidget {
  const PhaseA2Shell({super.key});

  @override
  State<PhaseA2Shell> createState() => _PhaseA2ShellState();
}

class _PhaseA2ShellState extends State<PhaseA2Shell> {
  int _index = 0;
  ZarNotificationPreferences _notificationPreferences = const ZarNotificationPreferences();
  final RecordReminderRegistry _reminders = RecordReminderRegistry();

  final List<AppPerson> _people = [
    AppPerson(id: 'p1', name: 'علی رضایی', phone: '۰۹۱۲۱۲۳۴۵۶۷', note: 'مشتری ثابت'),
    AppPerson(id: 'p2', name: 'رضا محمدی', phone: '۰۹۱۲۴۴۴۵۵۶۶'),
    AppPerson(id: 'p3', name: 'حسن کریمی', phone: '۰۹۱۲۳۳۳۴۴۵۵'),
    AppPerson(id: 'p4', name: 'مهدی احمدی', note: 'ترجیح تماس بعدازظهر'),
    AppPerson(id: 'p5', name: 'کامران حسینی', phone: '۰۹۱۲۹۹۹۸۸۷۷', archived: true),
  ];

  late final List<AppRecord> _records = [
    AppRecord(
      id: 's1',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p2',
      amountDisplay: r'$10,000',
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
      id: 's5',
      type: RecordType.settlement,
      operationLabel: 'تحویل',
      personId: 'p2',
      amountDisplay: r'$8,000',
      assetLabel: 'ارز',
      currencyCode: 'USD',
      date: Jalali.now().addDays(-2),
      time: const TimeOfDay(hour: 12, minute: 20),
      status: SettlementStatus.completed,
    ),
  ];

  @override
  void initState() {
    super.initState();
    for (final record in _records.where((r) => r.isObligation && r.status == SettlementStatus.open)) {
      unawaited(
        _reminders.setPlan(
          record: record,
          plan: ReminderPlan(
            rules: [ReminderRule.offset(id: 'seed-${record.id}', minutesBefore: _notificationPreferences.defaultReminderMinutes)],
          ),
          personName: personName(record.personId),
        ),
      );
    }
  }

  String personName(String id) => _people
      .firstWhere(
        (e) => e.id == id,
        orElse: () => AppPerson(id: '-', name: 'نامشخص'),
      )
      .name;

  List<AppPerson> get activePeople => _people.where((p) => !p.archived).toList(growable: false);
  List<AppPerson> get archivedPeople => _people.where((p) => p.archived).toList(growable: false);
  List<AppRecord> get openObligations => _records.where((r) => r.isObligation && r.status == SettlementStatus.open).toList(growable: false);
  List<AppRecord> get historyRecords => _records.where((r) => r.type == RecordType.deal || r.status != SettlementStatus.open).toList(growable: false);

  int openCountFor(String personId) => _records.where((r) => r.personId == personId && r.isObligation && r.status == SettlementStatus.open).length;

  void _updateRecord(AppRecord updated) {
    final index = _records.indexWhere((r) => r.id == updated.id);
    if (index == -1) return;
    setState(() => _records[index] = updated);
    unawaited(_reminders.onRecordChanged(record: updated, personName: personName(updated.personId)));
  }

  void _savePerson(AppPerson person) {
    final index = _people.indexWhere((p) => p.id == person.id);
    setState(() {
      if (index == -1) {
        _people.add(person);
      } else {
        _people[index] = person;
      }
    });
  }

  Future<void> _archivePerson(AppPerson person) async {
    final shouldArchive = await confirmArchiveWithOpenObligations(context, openObligations: openCountFor(person.id));
    if (!mounted || !shouldArchive) return;
    _savePerson(person.copyWith(archived: true));
    if (mounted) Navigator.of(context).maybePop();
  }

  void _restorePerson(String personId) {
    final index = _people.indexWhere((p) => p.id == personId);
    if (index == -1) return;
    _savePerson(_people[index].copyWith(archived: false));
  }

  Future<void> _openArchivedPeople() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArchivedPeopleScreen(
          people: archivedPeople.map((p) => ArchivedPersonViewData(id: p.id, name: p.name, phone: p.phone, openObligations: openCountFor(p.id))).toList(growable: false),
          onOpenPerson: (id) {
            final person = _people.firstWhere((p) => p.id == id);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => _buildPersonDetail(person)));
          },
          onRestore: (id) {
            _restorePerson(id);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openQuickAdd() async {
    final draft = await showModalBottomSheet<QuickAddDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuickAddSheet(people: activePeople),
    );
    if (draft == null) return;
    final isCurrency = draft.asset == 'ارز';
    final record = AppRecord(
      id: 'n${DateTime.now().millisecondsSinceEpoch}',
      type: (draft.operation == 'دریافت' || draft.operation == 'تحویل') ? RecordType.settlement : RecordType.deal,
      operationLabel: draft.operation,
      personId: draft.personId,
      amountDisplay: isCurrency && draft.currencyCode != null ? formatCurrencyAmount(draft.amount, draft.currencyCode!) : draft.amount,
      assetLabel: draft.asset == 'طلا' ? 'گرم طلا' : 'ارز',
      currencyCode: draft.currencyCode,
      date: draft.date,
      time: draft.time,
      note: draft.note.isEmpty ? null : draft.note,
    );
    setState(() => _records.add(record));
    if (record.isObligation) {
      final plan = reminderPlanFromLegacyLabel(draft.reminder);
      unawaited(_reminders.setPlan(record: record, plan: plan, personName: personName(record.personId)));
    }
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
          if (updated != null) _updateRecord(updated);
        },
        onReschedule: () async {
          final date = await pickJalaliDate(context, record.date);
          if (!mounted || date == null) return;
          final time = await pickCupertinoTime(context, record.time);
          if (!mounted) return;
          _updateRecord(record.copyWith(date: date, time: time));
          Navigator.pop(context);
        },
        onSnooze: () async {
          final value = await showReminderPickerBottomSheet(context, initialDate: record.date, initialTime: record.time);
          if (value == null) return;
          await _reminders.snooze(record: record, until: dueDateTimeFromJalali(value.$1, value.$2), personName: personName(record.personId));
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  List<ZarNotificationItem> _notificationItemsFor(Iterable<AppRecord> records, {bool overdue = false}) {
    return records
        .map(
          (r) => ZarNotificationItem(
            id: 'notification-${r.id}',
            recordId: r.id,
            title: '${r.operationDisplayLabel} • ${personName(r.personId)}',
            subtitle: _notificationPreferences.privacy == NotificationPrivacy.private
                ? 'یک یادآوری کاری دارید.'
                : _notificationPreferences.privacy == NotificationPrivacy.limited
                ? '${r.operationDisplayLabel} برای ${personName(r.personId)}'
                : '${r.assetLabel} • ${r.amountDisplay}',
            timeLabel: r.timeLabel(),
            isOverdue: overdue,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _openNotificationCenter() async {
    final now = Jalali.now();
    final overdue = openObligations.where((r) => r.date.compareTo(now) < 0);
    final today = openObligations.where((r) => isSameJalali(r.date, now));
    final upcoming = openObligations.where((r) => r.date.compareTo(now) > 0);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(
          overdue: _notificationItemsFor(overdue, overdue: true),
          today: _notificationItemsFor(today),
          upcoming: _notificationItemsFor(upcoming),
          onOpenRecord: (recordId) {
            final record = _records.firstWhere((r) => r.id == recordId);
            Navigator.of(context).pop();
            _openRecord(record);
          },
          onOpenSettings: _openNotificationSettings,
        ),
      ),
    );
  }

  Future<void> _openNotificationSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationSettingsScreen(initial: _notificationPreferences, onChanged: (value) => setState(() => _notificationPreferences = value)),
      ),
    );
  }

  Widget _buildPersonDetail(AppPerson person) {
    return PersonDetailScreen(
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
        if (edited != null) _savePerson(edited);
      },
      onArchivePerson: (_) => _archivePerson(person),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      PhaseA2HomeScreen(records: openObligations, personName: personName, onTapRecord: _openRecord, onOpenNotifications: _openNotificationCenter, unreadCount: openObligations.length),
      CalendarScreen(records: openObligations, personName: personName, onTapRecord: _openRecord),
      const SizedBox.shrink(),
      PhaseA2PeopleScreen(
        people: activePeople,
        records: _records,
        archivedCount: archivedPeople.length,
        onAddPerson: () async {
          final person = await showModalBottomSheet<AppPerson>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const PersonEditorSheet());
          if (person != null) _savePerson(person);
        },
        onOpenPerson: (person) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _buildPersonDetail(person))),
        onOpenArchive: _openArchivedPeople,
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
            _openQuickAdd();
          } else {
            setState(() => _index = value);
          }
        },
      ),
    );
  }
}

bool isRecordOverdueAt(AppRecord record, DateTime now) =>
    dueDateTimeFromJalali(record.date, record.time).isBefore(now);

String _homeDueLabel(AppRecord record, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final gregorian = record.date.toGregorian();
  final dueDay = DateTime(gregorian.year, gregorian.month, gregorian.day);
  final dayDelta = dueDay.difference(today).inDays;
  final time = record.time == null ? null : record.timeLabel();
  if (dueDateTimeFromJalali(record.date, record.time).isBefore(now)) {
    if (dayDelta == 0) return 'عقب‌افتاده';
  }
  if (dayDelta < 0) {
    return '${toPersianDigits((-dayDelta).toString())} روز عقب‌افتاده';
  }
  if (dayDelta == 0) {
    return time == null ? 'سررسید امروز' : 'سررسید: امروز $time';
  }
  if (dayDelta == 1) {
    return time == null ? 'سررسید فردا' : 'سررسید: فردا $time';
  }
  return '${toPersianDigits(dayDelta.toString())} روز مانده';
}

String _homeActivityTimestamp(AppRecord record, DateTime now) {
  final current = Jalali.fromDateTime(now);
  final time = record.time == null ? null : record.timeLabel();
  final suffix = time == null ? '' : ' $time';
  if (isSameJalali(record.date, current)) return 'امروز$suffix';
  if (isSameJalali(record.date, current.addDays(-1))) return 'دیروز$suffix';
  if (isSameJalali(record.date, current.addDays(1))) return 'فردا$suffix';
  return '${formatJalaliDate(record.date)}$suffix';
}

class PhaseA2HomeScreen extends StatelessWidget {
  const PhaseA2HomeScreen({super.key, required this.records, required this.personName, required this.onTapRecord, required this.onOpenNotifications, required this.unreadCount, this.onOpenSettings, this.onOpenInventory, this.onOpenDailyReport, this.onOpenOverdue, this.onOpenHistory, this.dashboard, this.recentRecords = const [], this.onOpenPendingReceive, this.onOpenPendingDeliver, this.now});

  final List<AppRecord> records;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTapRecord;
  final VoidCallback onOpenNotifications;
  final int unreadCount;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenInventory;
  final VoidCallback? onOpenDailyReport;
  final VoidCallback? onOpenOverdue;
  final VoidCallback? onOpenHistory;
  final ZarOperationalDashboardProjection? dashboard;
  final List<AppRecord> recentRecords;
  final VoidCallback? onOpenPendingReceive;
  final VoidCallback? onOpenPendingDeliver;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final currentTime = now ?? DateTime.now();
    final currentDate = Jalali.fromDateTime(currentTime);
    final overdue = records.where((r) => isRecordOverdueAt(r, currentTime)).toList(growable: false);
    final today = records.where((r) => isSameJalali(r.date, currentDate) && !isRecordOverdueAt(r, currentTime)).toList(growable: false);
    final tomorrow = records.where((r) => isSameJalali(r.date, currentDate.addDays(1))).toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Directionality(textDirection: TextDirection.ltr, child: Text('ZAR+')),
          actions: [
            if (onOpenSettings != null)
              IconButton(
                tooltip: 'تنظیمات و داده‌ها',
                onPressed: onOpenSettings,
                icon: const Icon(CupertinoIcons.settings),
              ),
            _NotificationBell(count: unreadCount, onTap: onOpenNotifications),
            const SizedBox(width: 8),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('امروز', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(formatJalaliDate(currentDate), style: Theme.of(context).textTheme.bodyMedium),
                if (onOpenInventory != null || onOpenDailyReport != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    if (onOpenInventory != null)
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: onOpenInventory,
                            icon: const Icon(CupertinoIcons.cube_box),
                            label: const Text('موجودی'),
                            style: _homeQuickActionStyle(context),
                          ),
                        ),
                      ),
                    if (onOpenInventory != null && onOpenDailyReport != null) const SizedBox(width: 8),
                    if (onOpenDailyReport != null)
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: onOpenDailyReport,
                            icon: const Icon(CupertinoIcons.doc_text_search),
                            label: const Text('گزارش روزانه'),
                            style: _homeQuickActionStyle(context),
                          ),
                        ),
                      ),
                  ]),
                ],
              ],
            ),
          ),
        ),
        if (dashboard != null) _dashboardSections(context, dashboard!),
        if (overdue.isNotEmpty) _section(context, 'عقب‌افتاده', overdue, overdue: true, maxItems: 3, onViewAll: onOpenOverdue ?? onOpenNotifications, now: currentTime),
        if (recentRecords.isNotEmpty) _recentSection(context, currentTime),
        if (today.isNotEmpty) _section(context, 'امروز', today, maxItems: 3, onViewAll: onOpenNotifications, now: currentTime),
        if (tomorrow.isNotEmpty) _section(context, 'فردا', tomorrow, maxItems: 3, onViewAll: onOpenNotifications, now: currentTime),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<AppRecord> items, {bool overdue = false, int? maxItems, VoidCallback? onViewAll, required DateTime now}) {
    final visible = maxItems == null ? items : items.take(maxItems).toList(growable: false);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeSectionHeading(
              title: title,
              titleColor: overdue ? const Color(0xFF9D3636) : null,
              onTap: maxItems != null && items.length > maxItems ? onViewAll : null,
              actionLabel: maxItems != null && items.length > maxItems ? 'مشاهده همه (${toPersianDigits(items.length.toString())})' : null,
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              _HomeContainer(child: const Padding(padding: EdgeInsets.all(12), child: Text('موردی ثبت نشده است.')))
            else
              _HomeActionList(items: visible, personName: personName, onTap: onTapRecord, overdue: overdue, now: now),
          ],
        ),
      ),
    );
  }

  Widget _dashboardSections(BuildContext context, ZarOperationalDashboardProjection value) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _HomeObligationCard(title: 'دریافتنی‌ها', count: value.pendingReceiveCount, items: value.inventory.pendingReceive, records: records, personName: personName, onTapRecord: onTapRecord, onTap: onOpenPendingReceive, accent: const Color(0xFF9A6700))),
              const SizedBox(width: 8),
              Expanded(child: _HomeObligationCard(title: 'پرداختنی‌ها', count: value.pendingDeliverCount, items: value.inventory.pendingDeliver, records: records, personName: personName, onTapRecord: onTapRecord, onTap: onOpenPendingDeliver, accent: const Color(0xFF6C5A42))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentSection(BuildContext context, DateTime currentTime) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeSectionHeading(
              title: 'فعالیت اخیر',
              onTap: onOpenHistory,
              actionLabel: onOpenHistory == null ? null : 'مشاهده همه',
            ),
            const SizedBox(height: 8),
            _HomeRecentActivity(
              records: recentRecords.take(5).toList(growable: false),
              personName: personName,
              onTap: onTapRecord,
              now: currentTime,
            ),
          ],
        ),
      ),
    );
  }

}

ButtonStyle _homeQuickActionStyle(BuildContext context) {
  final theme = Theme.of(context);
  return OutlinedButton.styleFrom(
    minimumSize: Size.zero,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    side: BorderSide(color: theme.dividerColor),
    textStyle: theme.textTheme.labelLarge,
  );
}

class _HomeSectionHeading extends StatelessWidget {
  const _HomeSectionHeading({required this.title, this.onTap, this.actionLabel, this.titleColor});
  final String title;
  final VoidCallback? onTap;
  final String? actionLabel;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: titleColor)),
      if (onTap != null && actionLabel != null)
        TextButton(onPressed: onTap, child: Text(actionLabel!)),
    ],
  );
}

class _HomeObligationCard extends StatelessWidget {
  const _HomeObligationCard({required this.title, required this.count, required this.items, required this.records, required this.personName, required this.onTapRecord, required this.onTap, required this.accent});
  final String title;
  final int count;
  final List<ZarOperationalInventoryItem> items;
  final List<AppRecord> records;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTapRecord;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey('home-obligation-$title'),
    child: _HomeContainer(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
        const SizedBox(height: 2),
        Text('${toPersianDigits(count.toString())} مورد', style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const _PhaseA2EmptyRow(label: 'موردی ثبت نشده است.')
        else ...[
          ...items.take(3).map((item) {
            final names = <String, AppRecord>{};
            for (final movement in item.movements) {
              AppRecord? record;
              for (final candidate in records) {
                if (candidate.id == movement.recordId) {
                  record = candidate;
                  break;
                }
              }
              final matchedRecord = record;
              if (matchedRecord != null) names.putIfAbsent(personName(movement.personId), () => matchedRecord);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _HomeInventoryLine(item: item, accent: accent),
                if (names.isNotEmpty)
                  Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                    Text(title.contains('دریافت') ? 'از' : 'به', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                    const SizedBox(width: 4),
                    ...names.entries.take(2).map((entry) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: InkWell(onTap: () => onTapRecord(entry.value), child: Text(entry.key, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11))),
                    )),
                  ]),
              ]),
            );
          }),
          if (items.length > 3 || onTap != null)
            Align(alignment: AlignmentDirectional.centerStart, child: TextButton(onPressed: onTap, child: const Text('مشاهده همه'))),
        ],
        ]),
      ),
    ),
  );
}

class _HomeInventoryLine extends StatelessWidget {
  const _HomeInventoryLine({required this.item, required this.accent});
  final ZarOperationalInventoryItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final display = switch (item) {
      ZarGoldInventoryItem(:final fineness, :final grams) => _HomeAmountParts(_dashboardDecimal(grams), 'گرم طلا', fineness == null ? 'عیار نامشخص' : 'عیار ${toPersianDigits(fineness)}'),
      ZarCoinInventoryItem(:final displayName, :final quantity) => _HomeAmountParts(toPersianDigits(quantity.toString()), 'عدد ${toPersianDigits(displayName)}', null),
      ZarCurrencyInventoryItem(:final code, :final decimalAmount) => _HomeAmountParts(_dashboardDecimal(decimalAmount), code == 'TOMAN' ? 'تومان' : code, null),
    };
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _HomeAmountText(amount: display.amount, unit: display.unit, color: accent)),
      if (display.detail != null) ...[
        const SizedBox(width: 8),
        Text(display.detail!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ]);
  }
}

class _HomeAmountParts {
  const _HomeAmountParts(this.amount, this.unit, this.detail);
  final String amount;
  final String unit;
  final String? detail;
}

class _HomeAmountText extends StatelessWidget {
  const _HomeAmountText({required this.amount, required this.unit, required this.color});
  final String amount;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(text: amount, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          TextSpan(text: ' $unit', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}

class _HomeRecentActivity extends StatelessWidget {
  const _HomeRecentActivity({required this.records, required this.personName, required this.onTap, required this.now});
  final List<AppRecord> records;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTap;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const _HomeContainer(child: Padding(padding: EdgeInsets.all(16), child: Text('هنوز فعالیتی ثبت نشده است.')));
    return _HomeContainer(
      child: Column(
        children: [
          for (var index = 0; index < records.length; index++) ...[
            _HomeRecentRow(record: records[index], personName: personName, onTap: onTap, now: now),
            if (index < records.length - 1) const Divider(height: 1, indent: 12, endIndent: 12),
          ],
        ],
      ),
    );
  }
}

class _HomeRecentRow extends StatelessWidget {
  const _HomeRecentRow({required this.record, required this.personName, required this.onTap, required this.now});
  final AppRecord record;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTap;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final relation = record.type == RecordType.deal ? 'با' : record.operationLabel == 'دریافت' ? 'از' : 'به';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(record),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 12, 7),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  '${record.operationDisplayLabel} ${record.assetLabel} $relation ${personName(record.personId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _HomeRecordAmountText(record: record, color: Theme.of(context).colorScheme.onSurface),
                    const SizedBox(height: 2),
                    Text(
                      _homeActivityTimestamp(record, now),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.chevron_left, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeContainer extends StatelessWidget {
  const _HomeContainer({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decorated = Container(
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor)),
      child: child,
    );
    return onTap == null ? decorated : InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: decorated);
  }
}

class _HomeActionList extends StatelessWidget {
  const _HomeActionList({required this.items, required this.personName, required this.onTap, required this.overdue, required this.now});
  final List<AppRecord> items;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTap;
  final bool overdue;
  final DateTime now;

  @override
  Widget build(BuildContext context) => _HomeContainer(
    child: Column(children: [
      for (var index = 0; index < items.length; index++) ...[
        _HomeActionRow(record: items[index], person: personName(items[index].personId), overdue: overdue, onTap: () => onTap(items[index]), now: now),
        if (index < items.length - 1) const Divider(height: 1, indent: 12, endIndent: 12),
      ],
    ]),
  );
}

class _HomeActionRow extends StatelessWidget {
  const _HomeActionRow({required this.record, required this.person, required this.overdue, required this.onTap, required this.now});
  final AppRecord record;
  final String person;
  final bool overdue;
  final VoidCallback onTap;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(record.operationDisplayLabel, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 1),
            Text(person, style: Theme.of(context).textTheme.bodySmall),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _HomeRecordAmountText(record: record, color: overdue ? const Color(0xFF9D3636) : const Color(0xFF9A6700), fontSize: 14),
            const SizedBox(height: 1),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(record.statusLabel(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: overdue ? const Color(0xFF9D3636) : null, fontSize: 11)),
              const SizedBox(width: 4),
              Text(_homeDueLabel(record, now), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: overdue ? const Color(0xFF9D3636) : null, fontSize: 11)),
            ]),
          ]),
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.chevron_left, size: 17),
        ]),
      ),
    ),
  );
}

_HomeAmountParts _homeRecordParts(AppRecord record) {
  if (record.coinLines.isNotEmpty) {
    if (record.coinLines.length == 1) {
      final line = record.coinLines.single;
      return _HomeAmountParts(toPersianDigits(line.quantity.toString()), 'عدد ${line.name}', null);
    }
    return _HomeAmountParts(toPersianDigits(record.coinLines.length.toString()), 'نوع سکه', null);
  }
  if (record.currencyCode != null) {
    final numeric = RegExp(r'[-+]?[0-9۰-۹٬,٫.]+').firstMatch(record.amountDisplay)?.group(0) ?? record.amountDisplay;
    return _HomeAmountParts(toPersianNumberText(numeric), record.currencyCode!, null);
  }
  if (record.assetLabel == 'وجه نقد') {
    final numeric = RegExp(r'[-+]?[0-9۰-۹٬,٫.]+').firstMatch(record.amountDisplay)?.group(0) ?? record.amountDisplay;
    return _HomeAmountParts(toPersianNumberText(numeric), 'تومان', null);
  }
  if (record.assetLabel == 'گرم طلا' || record.goldFineness != null) {
    final numeric = RegExp(r'[-+]?[0-9۰-۹٬,٫.]+').firstMatch(record.amountDisplay)?.group(0) ?? record.amountDisplay;
    final unit = record.goldInputUnit == ZarGoldUnit.mesghal.name ? 'مثقال طلا' : 'گرم طلا';
    final purity = record.goldFineness == null ? null : 'عیار ${toPersianNumberText(record.goldFineness!)}';
    return _HomeAmountParts(toPersianNumberText(numeric), unit, purity);
  }
  return _HomeAmountParts(toPersianNumberText(record.amountDisplay), record.assetLabel, null);
}

class _HomeRecordAmountText extends StatelessWidget {
  const _HomeRecordAmountText({required this.record, required this.color, this.fontSize = 13});
  final AppRecord record;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final display = _homeRecordParts(record);
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: fontSize);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: display.amount, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            TextSpan(text: ' ${display.unit}'),
            if (display.detail != null) TextSpan(text: ' • ${display.detail}'),
          ],
        ),
      ),
    );
  }
}

String _dashboardDecimal(String value) {
  final negative = value.startsWith('-');
  final raw = negative ? value.substring(1) : value;
  final parts = raw.split('.');
  final digits = parts.first;
  final grouped = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    grouped.insert(0, digits.substring(end < 3 ? 0 : end - 3, end));
  }
  final number = parts.length == 1 ? grouped.join('٬') : '${grouped.join('٬')}٫${parts[1]}';
  return toPersianDigits('${negative ? '-' : ''}$number');
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(tooltip: 'اعلان‌ها', onPressed: onTap, icon: const Icon(CupertinoIcons.bell)),
        if (count > 0)
          Positioned(
            top: 5,
            left: 5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFF9D3636), borderRadius: BorderRadius.circular(20)),
              child: Text(
                toPersianDigits(count > 99 ? '99+' : count.toString()),
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, height: 1),
              ),
            ),
          ),
      ],
    );
  }
}

class PhaseA2PeopleScreen extends StatefulWidget {
  const PhaseA2PeopleScreen({super.key, required this.people, required this.records, required this.archivedCount, required this.onAddPerson, required this.onOpenPerson, required this.onOpenArchive});

  final List<AppPerson> people;
  final List<AppRecord> records;
  final int archivedCount;
  final VoidCallback onAddPerson;
  final ValueChanged<AppPerson> onOpenPerson;
  final VoidCallback onOpenArchive;

  @override
  State<PhaseA2PeopleScreen> createState() => _PhaseA2PeopleScreenState();
}

class _PhaseA2PeopleScreenState extends State<PhaseA2PeopleScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.people.where((p) => p.name.contains(query.trim())).toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('اشخاص'),
        actions: [
          TextButton.icon(
            onPressed: widget.onOpenArchive,
            icon: const Icon(CupertinoIcons.archivebox, size: 17),
            label: Text(widget.archivedCount == 0 ? 'بایگانی' : 'بایگانی (${toPersianDigits(widget.archivedCount.toString())})'),
          ),
          const SizedBox(width: 6),
        ],
      ),
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
              child: filtered.isEmpty
                  ? const Center(child: Text('شخصی پیدا نشد.'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(color: Theme.of(context).dividerColor),
                      itemBuilder: (context, index) {
                        final person = filtered[index];
                        final openCount = widget.records.where((r) => r.personId == person.id && r.status == SettlementStatus.open && r.isObligation).length;
                        final dealCount = widget.records.where((r) => r.personId == person.id && r.type == RecordType.deal).length;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                            child: Text(person.name.isEmpty ? '-' : person.name[0], style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                          ),
                          title: Text(person.name, style: Theme.of(context).textTheme.bodyLarge),
                          subtitle: Text(
                            '${toPersianDigits(dealCount.toString())} معامله • ${toPersianDigits(openCount.toString())} تعهد باز',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
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

class _PhaseA2EmptyRow extends StatelessWidget {
  const _PhaseA2EmptyRow({required this.label});
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
