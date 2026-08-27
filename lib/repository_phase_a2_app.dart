import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'app_core.dart';
import 'application/zar_legacy_presentation_bridge.dart';
import 'application/zar_phase_a2_store.dart';
import 'data/zar_domain_repository.dart';
import 'domain/zar_domain_models.dart';
import 'features/notifications/notification_center.dart';
import 'features/people/archived_people_screen.dart';
import 'features/reminders/record_reminder_registry.dart';
import 'features/reminders/reminder_model.dart';
import 'main_phase_a2.dart' show PhaseA2HomeScreen, PhaseA2PeopleScreen;

/// Default pre-Firebase application shell backed by the production repository
/// boundary rather than direct mutable lists inside widgets.
class RepositoryZarPlusApp extends StatelessWidget {
  const RepositoryZarPlusApp({super.key, this.repository});

  final ZarDomainRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZAR+',
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.light,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: RepositoryPhaseA2Shell(repository: repository ?? buildPhaseA2PreviewRepository()),
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
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: surface,
        foregroundColor: primaryText,
        centerTitle: false,
      ),
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

class RepositoryPhaseA2Shell extends StatefulWidget {
  const RepositoryPhaseA2Shell({super.key, required this.repository});

  final ZarDomainRepository repository;

  @override
  State<RepositoryPhaseA2Shell> createState() => _RepositoryPhaseA2ShellState();
}

class _RepositoryPhaseA2ShellState extends State<RepositoryPhaseA2Shell> {
  static const _bridge = ZarLegacyPresentationBridge(
    businessId: 'preview-business',
    userId: 'preview-user',
  );

  late final ZarPhaseA2Store _store = ZarPhaseA2Store(
    repository: widget.repository,
    bridge: _bridge,
  );
  final RecordReminderRegistry _reminders = RecordReminderRegistry();
  ZarNotificationPreferences _notificationPreferences = const ZarNotificationPreferences();
  int _index = 0;
  bool _ready = false;
  Object? _loadError;
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _store.refresh();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _loadError = null;
      });
      for (final record in openObligations) {
        unawaited(
          _reminders.setPlan(
            record: record,
            plan: ReminderPlan(
              rules: [
                ReminderRule.offset(
                  id: 'seed-${record.id}',
                  minutesBefore: _notificationPreferences.defaultReminderMinutes,
                ),
              ],
            ),
            personName: _store.personName(record.personId),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  List<AppRecord> get records => _store.records;
  List<AppRecord> get openObligations => records
      .where((r) => r.type == RecordType.settlement && r.status == SettlementStatus.open)
      .toList(growable: false);
  List<AppRecord> get historyRecords => records
      .where((r) => r.type == RecordType.settlement && r.status != SettlementStatus.open)
      .toList(growable: false);

  Future<void> _runWrite(Future<void> Function() action) async {
    if (_writing) return;
    setState(() => _writing = true);
    try {
      await action();
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اطلاعات ثبت نشد. دوباره تلاش کنید.')),
      );
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _savePerson(AppPerson person) => _runWrite(() => _store.savePerson(person));

  Future<void> _archivePerson(AppPerson person) async {
    final shouldArchive = await confirmArchiveWithOpenObligations(
      context,
      openObligations: _store.openCountFor(person.id),
    );
    if (!mounted || !shouldArchive) return;
    await _runWrite(() => _store.archivePerson(person));
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _restorePerson(String personId) async {
    final person = _store.personById(personId);
    if (person == null) return;
    await _runWrite(() => _store.restorePerson(person));
  }

  Future<void> _updateRecord(AppRecord updated, {String action = 'edit'}) async {
    await _runWrite(() => _store.saveRecord(updated, auditAction: action));
    final persisted = _store.recordById(updated.id);
    if (persisted != null) {
      unawaited(
        _reminders.onRecordChanged(
          record: persisted,
          personName: _store.personName(persisted.personId),
        ),
      );
    }
  }

  Future<void> _openQuickAdd() async {
    final draft = await showModalBottomSheet<QuickAddDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuickAddSheet(people: _store.activePeople),
    );
    if (draft == null) return;
    final isCurrency = draft.asset == 'ارز';
    final record = AppRecord(
      id: 'n${DateTime.now().microsecondsSinceEpoch}',
      type: (draft.operation == 'دریافت' || draft.operation == 'تحویل')
          ? RecordType.settlement
          : RecordType.deal,
      operationLabel: draft.operation,
      personId: draft.personId,
      amountDisplay: isCurrency && draft.currencyCode != null
          ? formatCurrencyAmount(draft.amount, draft.currencyCode!)
          : draft.amount,
      assetLabel: draft.asset == 'طلا' ? 'گرم طلا' : 'ارز',
      currencyCode: draft.currencyCode,
      date: draft.date,
      time: draft.time,
      note: draft.note.isEmpty ? null : draft.note,
    );
    await _runWrite(() => _store.saveRecord(record, auditAction: 'create'));
    final persisted = _store.recordById(record.id);
    if (persisted?.isObligation == true) {
      unawaited(
        _reminders.setPlan(
          record: persisted!,
          plan: reminderPlanFromLegacyLabel(draft.reminder),
          personName: _store.personName(persisted.personId),
        ),
      );
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
          personName: _store.personName(record.personId),
          linkedSettlements: records
              .where((e) => record.linkedSettlementIds.contains(e.id))
              .toList(growable: false),
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
        personName: _store.personName(record.personId),
        onComplete: () async {
          await _updateRecord(record.copyWith(status: SettlementStatus.completed), action: 'complete');
          if (mounted) Navigator.pop(context);
        },
        onCancel: () async {
          await _updateRecord(record.copyWith(status: SettlementStatus.cancelled), action: 'cancel');
          if (mounted) Navigator.pop(context);
        },
        onEdit: () async {
          final updated = await showModalBottomSheet<AppRecord>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => EditRecordSheet(
              record: record,
              personName: _store.personName(record.personId),
            ),
          );
          if (updated != null) await _updateRecord(updated);
        },
        onReschedule: () async {
          final date = await pickJalaliDate(context, record.date);
          if (!mounted || date == null) return;
          final time = await pickCupertinoTime(context, record.time);
          if (!mounted) return;
          await _updateRecord(record.copyWith(date: date, time: time), action: 'reschedule');
          if (mounted) Navigator.pop(context);
        },
        onSnooze: () async {
          final value = await showReminderPickerBottomSheet(
            context,
            initialDate: record.date,
            initialTime: record.time,
          );
          if (value == null) return;
          await _reminders.snooze(
            record: record,
            until: dueDateTimeFromJalali(value.$1, value.$2),
            personName: _store.personName(record.personId),
          );
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _openArchive() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArchivedPeopleScreen(
          people: _store.archivedPeople
              .map((p) => ArchivedPersonViewData(
                    id: p.id,
                    name: p.name,
                    phone: p.phone,
                    openObligations: _store.openCountFor(p.id),
                  ))
              .toList(growable: false),
          onOpenPerson: (id) {
            final person = _store.personById(id);
            if (person != null) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => _buildPersonDetail(person)),
              );
            }
          },
          onRestore: (id) async {
            await _restorePerson(id);
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _buildPersonDetail(AppPerson person) => PersonDetailScreen(
        person: person,
        records: records,
        personName: _store.personName,
        onTapRecord: _openRecord,
        onEditPerson: (target) async {
          final edited = await showModalBottomSheet<AppPerson>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => PersonEditorSheet(existing: target),
          );
          if (edited != null) await _savePerson(edited);
        },
        onArchivePerson: (_) => _archivePerson(person),
      );

  List<ZarNotificationItem> _notificationItemsFor(
    Iterable<AppRecord> source, {
    bool overdue = false,
  }) =>
      source
          .map((record) => ZarNotificationItem(
                id: 'notification-${record.id}',
                recordId: record.id,
                title: '${record.operationLabel} • ${_store.personName(record.personId)}',
                subtitle: _notificationPreferences.privacy == NotificationPrivacy.private
                    ? 'یک یادآوری کاری دارید.'
                    : _notificationPreferences.privacy == NotificationPrivacy.limited
                        ? '${record.operationLabel} برای ${_store.personName(record.personId)}'
                        : '${record.assetLabel} • ${record.amountDisplay}',
                timeLabel: record.timeLabel(),
                isOverdue: overdue,
              ))
          .toList(growable: false);

  Future<void> _openNotificationCenter() async {
    final now = Jalali.now();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(
          overdue: _notificationItemsFor(
            openObligations.where((r) => r.date.compareTo(now) < 0),
            overdue: true,
          ),
          today: _notificationItemsFor(
            openObligations.where((r) => isSameJalali(r.date, now)),
          ),
          upcoming: _notificationItemsFor(
            openObligations.where((r) => r.date.compareTo(now) > 0),
          ),
          onOpenRecord: (recordId) {
            final record = _store.recordById(recordId);
            Navigator.of(context).pop();
            if (record != null) _openRecord(record);
          },
          onOpenSettings: _openNotificationSettings,
        ),
      ),
    );
  }

  Future<void> _openNotificationSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationSettingsScreen(
          initial: _notificationPreferences,
          onChanged: (value) => setState(() => _notificationPreferences = value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null && !_ready) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('بارگذاری اطلاعات انجام نشد.'),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _load, child: const Text('تلاش دوباره')),
              ],
            ),
          ),
        ),
      );
    }
    if (!_ready) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }

    final pages = [
      PhaseA2HomeScreen(
        records: openObligations,
        personName: _store.personName,
        onTapRecord: _openRecord,
        onOpenNotifications: _openNotificationCenter,
        unreadCount: openObligations.length,
      ),
      CalendarScreen(
        records: openObligations,
        personName: _store.personName,
        onTapRecord: _openRecord,
      ),
      const SizedBox.shrink(),
      PhaseA2PeopleScreen(
        people: _store.activePeople,
        records: records,
        archivedCount: _store.archivedPeople.length,
        onAddPerson: () async {
          final person = await showModalBottomSheet<AppPerson>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const PersonEditorSheet(),
          );
          if (person != null) await _savePerson(person);
        },
        onOpenPerson: (person) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _buildPersonDetail(person)),
        ),
        onOpenArchive: _openArchive,
      ),
      HistoryScreen(records: historyRecords, personName: _store.personName),
    ];

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(child: IndexedStack(index: _index, children: pages)),
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
        ),
        if (_writing)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Color(0x11000000),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: CupertinoActivityIndicator(radius: 9),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Deterministic preview data is stored as production domain objects so the
/// default app exercises the same repository path that Firestore will use.
ZarDomainRepository buildPhaseA2PreviewRepository() {
  final now = DateTime.now();
  final today = Jalali.fromDateTime(now);
  DateTime at(Jalali date, int hour, [int minute = 0]) {
    final g = date.toGregorian();
    return DateTime(g.year, g.month, g.day, hour, minute).toUtc();
  }

  final created = now.subtract(const Duration(days: 90)).toUtc();
  final people = [
    ZarPerson(id: 'p1', displayName: 'علی رضایی', phone: '۰۹۱۲۱۲۳۴۵۶۷', note: 'مشتری ثابت', createdAt: created, updatedAt: created, createdBy: 'preview-user'),
    ZarPerson(id: 'p2', displayName: 'رضا محمدی', phone: '۰۹۱۲۴۴۴۵۵۶۶', createdAt: created, updatedAt: created, createdBy: 'preview-user'),
    ZarPerson(id: 'p3', displayName: 'حسن کریمی', phone: '۰۹۱۲۳۳۳۴۴۵۵', createdAt: created, updatedAt: created, createdBy: 'preview-user'),
    ZarPerson(id: 'p4', displayName: 'مهدی احمدی', note: 'ترجیح تماس بعدازظهر', createdAt: created, updatedAt: created, createdBy: 'preview-user'),
    ZarPerson(id: 'p5', displayName: 'کامران حسینی', phone: '۰۹۱۲۹۹۹۸۸۷۷', archived: true, createdAt: created, updatedAt: created, createdBy: 'preview-user'),
  ];
  ZarCurrencyAssetAmount usd(String amount) => ZarCurrencyAssetAmount(
        ZarCurrencyAmount(code: 'USD', minorUnits: int.parse(amount) * 100),
      );
  final settlements = [
    ZarSettlement(id: 's1', businessId: 'preview-business', personId: 'p2', direction: ZarSettlementDirection.deliver, amount: usd('10000'), scheduledAt: at(today.addDays(-1), 11), hasTime: true, createdBy: 'preview-user', createdAt: created, updatedAt: created),
    ZarSettlement(id: 's2', businessId: 'preview-business', personId: 'p1', direction: ZarSettlementDirection.receive, amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '250')), scheduledAt: at(today, 10, 30), hasTime: true, createdBy: 'preview-user', createdAt: created, updatedAt: created),
    ZarSettlement(id: 's3', businessId: 'preview-business', personId: 'p3', direction: ZarSettlementDirection.deliver, amount: ZarCurrencyAssetAmount(ZarCurrencyAmount(code: 'EUR', minorUnits: 500000)), scheduledAt: at(today, 14, 45), hasTime: true, createdBy: 'preview-user', createdAt: created, updatedAt: created),
    ZarSettlement(id: 's4', businessId: 'preview-business', personId: 'p4', direction: ZarSettlementDirection.receive, amount: ZarGoldAssetAmount(ZarGoldQuantity(decimal: '400')), scheduledAt: at(today.addDays(1), 12), hasTime: false, createdBy: 'preview-user', createdAt: created, updatedAt: created),
    ZarSettlement(id: 's5', businessId: 'preview-business', personId: 'p2', direction: ZarSettlementDirection.deliver, amount: usd('8000'), scheduledAt: at(today.addDays(-2), 12, 20), hasTime: true, status: ZarSettlementStatus.completed, completedAt: at(today.addDays(-2), 12, 25), completedBy: 'preview-user', createdBy: 'preview-user', createdAt: created, updatedAt: created),
  ];
  return InMemoryZarDomainRepository(people: people, settlements: settlements);
}
