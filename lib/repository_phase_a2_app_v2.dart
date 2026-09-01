import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'app_core.dart';
import 'application/persisted_reminder_coordinator.dart';
import 'application/zar_backup_manager.dart';
import 'application/zar_legacy_presentation_bridge.dart';
import 'application/zar_phase_a2_store.dart';
import 'application/zar_write_coordinator.dart';
import 'data/zar_domain_repository.dart';
import 'domain/zar_amount_formatter.dart';
import 'domain/zar_amount_parser.dart';
import 'domain/zar_domain_models.dart';
import 'domain/zar_reminder_plan.dart';
import 'features/editors/confirmed_editors.dart';
import 'features/backup/backup_screen.dart';
import 'features/coins/coin_catalog_screen.dart';
import 'features/editors/confirmed_quick_add_sheet.dart';
import 'features/notifications/native_notification_runtime.dart';
import 'features/notifications/notification_center.dart';
import 'features/people/archived_people_screen.dart';
import 'features/reminders/record_reminder_registry.dart';
import 'features/reminders/reminder_model.dart';
import 'features/reminders/reminder_plan_editor.dart';
import 'features/settlements/repository_settlement_action_sheet.dart';
import 'main_phase_a2.dart'
    show PhaseA2HomeScreen, PhaseA2PeopleScreen, isRecordOverdueAt;
import 'repository_phase_a2_app.dart' show buildPhaseA2PreviewRepository;

/// Phase A.2 live shell with persisted reminder editing and confirmed editor
/// writes wired into the approved Persian-first UI.
class RepositoryZarPlusAppV2 extends StatelessWidget {
  const RepositoryZarPlusAppV2({
    super.key,
    this.repository,
    this.businessId = 'preview-business',
  });

  final ZarDomainRepository? repository;
  final String businessId;

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
      home: _RepositoryPhaseA2ShellV2(
        repository: repository ?? buildPhaseA2PreviewRepository(),
        businessId: businessId,
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const accent = Color(0xFFC08A3D);
    final surface = isDark ? const Color(0xFF151515) : const Color(0xFFFBFAF8);
    final card = isDark ? const Color(0xFF1D1D1D) : Colors.white;
    final primary = isDark ? const Color(0xFFF4F4F4) : const Color(0xFF121212);
    final secondary = isDark
        ? const Color(0xFFA9A9A9)
        : const Color(0xFF707070);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Vazirmatn',
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
        surface: card,
      ),
      dividerColor: isDark ? const Color(0xFF303030) : const Color(0xFFECEAE6),
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: primary,
          height: 1.35,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primary,
          height: 1.35,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: primary,
          height: 1.45,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: primary,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: secondary,
          height: 1.6,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: surface,
        foregroundColor: primary,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF252525) : const Color(0xFFF6F4F1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

class _RepositoryPhaseA2ShellV2 extends StatefulWidget {
  const _RepositoryPhaseA2ShellV2({
    required this.repository,
    required this.businessId,
  });

  final ZarDomainRepository repository;
  final String businessId;

  @override
  State<_RepositoryPhaseA2ShellV2> createState() =>
      _RepositoryPhaseA2ShellV2State();
}

class _RepositoryPhaseA2ShellV2State extends State<_RepositoryPhaseA2ShellV2> {
  static const _bridge = ZarLegacyPresentationBridge(
    businessId: 'preview-business',
    userId: 'preview-user',
  );

  late final ZarPhaseA2Store _store = ZarPhaseA2Store(
    repository: widget.repository,
    bridge: _bridge,
  );
  final RecordReminderRegistry _registry = RecordReminderRegistry();
  final ZarWriteCoordinator _writes = ZarWriteCoordinator();
  late final PersistedReminderCoordinator _persistedReminders =
      PersistedReminderCoordinator(
        store: _store,
        registry: _registry,
        personName: _store.personName,
      );
  late final ZarBackupManager _backupManager = ZarBackupManager(
    repository: widget.repository,
    store: _store,
    businessId: widget.businessId,
    reconcileRemindersAfterRestore: () =>
        _persistedReminders.reconcileAfterReplacement(records),
  );

  late ZarNotificationPreferences _notificationPreferences;
  int _index = 0;
  bool _ready = false;
  bool _writing = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _notificationPreferences =
        ZarNativeNotificationRuntime.instance.preferences;
    unawaited(_load());
  }

  @override
  void dispose() {
    ZarNativeNotificationRuntime.instance.setRecordTapHandler(null);
    super.dispose();
  }

  List<AppRecord> get records => _store.records;

  List<AppRecord> get openObligations => records
      .where(
        (record) =>
            record.type == RecordType.settlement &&
            record.status == SettlementStatus.open,
      )
      .toList(growable: false);

  List<AppRecord> get historyRecords => records
      .where(
        (record) =>
            record.type == RecordType.deal ||
            record.status != SettlementStatus.open,
      )
      .toList(growable: false);

  Future<void> _load() async {
    try {
      await _store.refresh();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _loadError = null;
      });
      ZarNativeNotificationRuntime.instance.setRecordTapHandler(
        _handleNativeRecordTap,
      );
      try {
        await _persistedReminders.reconcileAll(records);
      } catch (_) {
        // Business data is already loaded. Native delivery can be repaired from
        // the persisted reminder plans later without blocking app access.
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _handleNativeRecordTap(String recordId) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ready) return;
      final record = _store.recordById(recordId);
      if (record == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('این یادآوری دیگر در دسترس نیست.')),
        );
        return;
      }
      unawaited(_openRecord(record));
    });
  }

  Future<bool> _runWrite(Future<void> Function() action) async {
    if (_writing) return false;
    setState(() => _writing = true);
    final result = await _writes.run(action);
    if (!mounted) return result.succeeded;
    setState(() => _writing = false);

    if (result.succeeded) {
      setState(() {});
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('اطلاعات ثبت نشد. دوباره تلاش کنید.'),
        duration: const Duration(seconds: 6),
        action: result.canRetry
            ? SnackBarAction(
                label: 'تلاش دوباره',
                onPressed: () => unawaited(_retryLastWrite()),
              )
            : null,
      ),
    );
    return false;
  }

  Future<bool> _retryLastWrite() async {
    if (_writing || !_writes.hasRetryableFailure) return false;
    setState(() => _writing = true);
    final result = await _writes.retryLastFailure();
    if (!mounted) return result.succeeded;
    setState(() => _writing = false);

    if (result.succeeded) {
      setState(() {});
      try {
        await _persistedReminders.reconcileAll(records);
      } catch (_) {}
      if (!mounted) return result.succeeded;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.succeeded
              ? 'اطلاعات با موفقیت ثبت شد.'
              : 'ثبت اطلاعات دوباره ناموفق بود.',
        ),
        action: !result.succeeded && result.canRetry
            ? SnackBarAction(
                label: 'تلاش دوباره',
                onPressed: () => unawaited(_retryLastWrite()),
              )
            : null,
      ),
    );
    return result.succeeded;
  }

  Future<void> _savePersonOrThrow(AppPerson person) async {
    if (_writing) throw StateError('Write already in progress.');
    setState(() => _writing = true);
    try {
      await _store.savePerson(person);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _saveRecordOrThrow(
    AppRecord record, {
    String action = 'edit',
  }) async {
    if (_writing) throw StateError('Write already in progress.');
    setState(() => _writing = true);
    try {
      await _store.saveRecord(record, auditAction: action);
      final persisted = _store.recordById(record.id);
      if (persisted != null) {
        try {
          await _persistedReminders.reconcileRecord(persisted);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'اطلاعات ثبت شد، اما یادآوری دستگاه به‌روزرسانی نشد.',
                ),
              ),
            );
          }
        }
      }
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _saveQuickAddDraftOrThrow(QuickAddDraft draft) async {
    if (_writing) throw StateError('Write already in progress.');

    final isSettlement =
        draft.operation == 'دریافت' || draft.operation == 'تحویل';
    if (draft.asset == 'سکه') {
      await _saveCoinQuickAdd(draft, isSettlement: isSettlement);
      return;
    }
    final isCurrency = draft.asset == 'ارز' || draft.asset == 'وجه نقد';
    final currencyCode = draft.currencyCode;

    if (isCurrency && currencyCode == null) {
      throw const FormatException('Currency code is required.');
    }

    int? totalToman;
    String? tomanRate;
    if (!isSettlement) {
      if (draft.tomanRate == null) {
        throw const FormatException('Deal pricing is required.');
      }
      tomanRate = normalizeDecimal(draft.tomanRate!);
      if (!isCurrency && tomanRate.contains('.')) {
        throw const FormatException('Gold price must be a whole Toman amount.');
      }
      if (isCurrency) {
        totalToman = ZarCurrencyDealPricing.calculate(
          amount: draft.amount,
          tomanPerUnit: tomanRate,
        ).totalToman.wholeTomans;
      } else {
        totalToman = ZarGoldDealPricing.calculate(
          fineness: draft.goldFineness!,
          priceReferenceFineness:
              draft.goldPriceReferenceFineness ?? draft.goldFineness!,
          inputWeight: draft.amount,
          inputWeightUnit: ZarGoldUnit.values.byName(
            draft.goldInputUnit ?? ZarGoldUnit.gram.name,
          ),
          priceUnit: ZarGoldUnit.values.byName(
            draft.goldPriceUnit ?? ZarGoldUnit.gram.name,
          ),
          pricePerUnitToman: ZarTomanAmount(int.parse(tomanRate)),
        ).totalToman.wholeTomans;
      }
    }

    final amountDisplay = isCurrency
        ? ZarAmountFormatter.currency(
            ZarAmountParser.currency(
              draft.amount,
              code: currencyCode!,
              minorUnitScale: currencyCode == 'TOMAN' ? 0 : 2,
            ),
          )
        : toPersianDigits(ZarAmountParser.gold(draft.amount).decimal);

    final record = AppRecord(
      id: 'n${DateTime.now().microsecondsSinceEpoch}',
      type: isSettlement ? RecordType.settlement : RecordType.deal,
      operationLabel: draft.operation,
      personId: draft.personId,
      amountDisplay: amountDisplay,
      assetLabel: draft.asset == 'وجه نقد'
          ? 'وجه نقد'
          : isCurrency
          ? 'ارز'
          : 'گرم طلا',
      currencyCode: currencyCode,
      date: draft.date,
      time: draft.time,
      note: draft.note.isEmpty ? null : draft.note,
      goldFineness: !isCurrency ? draft.goldFineness : null,
      goldPriceReferenceFineness: !isCurrency
          ? draft.goldPriceReferenceFineness
          : null,
      goldInputWeight: !isCurrency ? normalizeDecimal(draft.amount) : null,
      goldInputUnit: !isCurrency
          ? (draft.goldInputUnit ?? ZarGoldUnit.gram.name)
          : null,
      goldPriceUnit: !isSettlement && !isCurrency
          ? (draft.goldPriceUnit ?? ZarGoldUnit.gram.name)
          : null,
      tomanRate: tomanRate,
      totalToman: totalToman,
    );
    final runtimePlan = isSettlement
        ? reminderPlanFromLegacyLabel(draft.reminder)
        : const ReminderPlan();

    setState(() => _writing = true);
    try {
      await _store.saveRecord(
        record,
        auditAction: 'create',
        reminderPlan: isSettlement ? reminderPlanToDomain(runtimePlan) : null,
      );
      final persisted = _store.recordById(record.id);
      if (persisted?.isObligation == true) {
        try {
          await _persistedReminders.reconcileRecord(persisted!);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'اطلاعات ثبت شد، اما یادآوری دستگاه به‌روزرسانی نشد.',
                ),
              ),
            );
          }
        }
      }
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _saveCoinQuickAdd(
    QuickAddDraft draft, {
    required bool isSettlement,
  }) async {
    if (draft.coinLines.isEmpty) {
      throw const FormatException('Coin lines are required.');
    }
    final now = DateTime.now().toUtc();
    final gregorian = draft.date.toGregorian();
    final eventAt = DateTime(
      gregorian.year,
      gregorian.month,
      gregorian.day,
      draft.time?.hour ?? 12,
      draft.time?.minute ?? 0,
    ).toUtc();
    final id = 'n${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _writing = true);
    try {
      if (isSettlement) {
        final runtimePlan = reminderPlanFromLegacyLabel(draft.reminder);
        await _store.saveCoinSettlement(
          ZarSettlement(
            id: id,
            businessId: widget.businessId,
            personId: draft.personId,
            direction: draft.operation == 'دریافت'
                ? ZarSettlementDirection.receive
                : ZarSettlementDirection.deliver,
            amount: ZarCoinBundleAmount(draft.coinLines),
            scheduledAt: eventAt,
            hasTime: draft.time != null,
            reminderPlan: reminderPlanToDomain(runtimePlan),
            coinValuation: draft.coinSettlementValuation,
            note: draft.note.isEmpty ? null : draft.note,
            createdBy: 'local-user',
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await _store.saveCoinDeal(
          ZarDeal(
            id: id,
            businessId: widget.businessId,
            type: draft.operation == 'خرید'
                ? ZarDealType.buy
                : ZarDealType.sell,
            personId: draft.personId,
            amount: ZarCoinBundleAmount(draft.coinLines),
            pricing: draft.coinDealPricing,
            dealAt: eventAt,
            note: draft.note.isEmpty ? null : draft.note,
            createdBy: 'local-user',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      final persisted = _store.recordById(id);
      if (persisted?.isObligation == true) {
        await _persistedReminders.reconcileRecord(persisted!);
      }
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _archivePerson(AppPerson person) async {
    final shouldArchive = await confirmArchiveWithOpenObligations(
      context,
      openObligations: _store.openCountFor(person.id),
    );
    if (!mounted || !shouldArchive) return;
    final saved = await _runWrite(() => _store.archivePerson(person));
    if (mounted && saved) Navigator.of(context).maybePop();
  }

  Future<bool> _restorePerson(String personId) async {
    final person = _store.personById(personId);
    if (person == null) return false;
    return _runWrite(() => _store.restorePerson(person));
  }

  Future<bool> _updateRecord(
    AppRecord updated, {
    String action = 'edit',
  }) async {
    final saved = await _runWrite(
      () => _store.saveRecord(updated, auditAction: action),
    );
    if (!saved) return false;
    final persisted = _store.recordById(updated.id);
    if (persisted != null) {
      try {
        await _persistedReminders.reconcileRecord(persisted);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'اطلاعات ثبت شد، اما یادآوری دستگاه به‌روزرسانی نشد.',
              ),
            ),
          );
        }
      }
    }
    return true;
  }

  Future<void> _openQuickAdd() async {
    await showModalBottomSheet<QuickAddDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: !_writing,
      enableDrag: !_writing,
      builder: (_) => ConfirmedQuickAddSheet(
        people: _store.activePeople,
        coinTypes: _store.coinTypes,
        onSave: _saveQuickAddDraftOrThrow,
        initialReminder: reminderPresetLabel(
          _notificationPreferences.defaultReminderMinutes,
        ),
      ),
    );
  }

  String _reminderSummary(AppRecord record) {
    final plan = _store.reminderPlanFor(record.id);
    final enabled = plan.rules.where((rule) => rule.enabled).length;
    if (enabled == 0 && plan.snoozedUntil == null) return 'بدون یادآوری';
    if (plan.snoozedUntil != null) {
      return enabled == 0
          ? 'یک تعویق فعال'
          : '${toPersianDigits(enabled.toString())} یادآوری + تعویق';
    }
    return '${toPersianDigits(enabled.toString())} یادآوری فعال';
  }

  Future<DateTime?> _pickCustomReminderTime(AppRecord record) async {
    final date = await pickJalaliDate(context, record.date);
    if (!mounted || date == null) return null;
    final time = await pickCupertinoTime(context, record.time);
    if (!mounted) return null;
    return dueDateTimeFromJalali(date, time);
  }

  Future<void> _openReminderEditor(AppRecord record) async {
    final plan = await showModalBottomSheet<ZarReminderPlan>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReminderPlanEditorSheet(
        initialPlan: _store.reminderPlanFor(record.id),
        onPickCustomTime: () => _pickCustomReminderTime(record),
      ),
    );
    if (plan == null) return;

    final saved = await _runWrite(
      () => _store.saveReminderPlan(
        record.id,
        plan,
        auditAction: 'reminder_update',
      ),
    );
    if (!saved) return;
    final persisted = _store.recordById(record.id);
    if (persisted != null) {
      try {
        await _persistedReminders.reconcileRecord(persisted);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'یادآوری ذخیره شد، اما اعلان دستگاه به‌روزرسانی نشد.',
              ),
            ),
          );
        }
      }
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
              .where((item) => record.linkedSettlementIds.contains(item.id))
              .toList(growable: false),
          onOpenSettlement: (settlement) {
            Navigator.of(context).pop();
            unawaited(_openRecord(settlement));
          },
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RepositorySettlementActionSheet(
        record: record,
        personName: _store.personName(record.personId),
        reminderSummary: _reminderSummary(record),
        onComplete: () async {
          final saved = await _updateRecord(
            record.copyWith(status: SettlementStatus.completed),
            action: 'complete',
          );
          if (mounted && saved) Navigator.of(context).pop();
        },
        onCancel: () async {
          final saved = await _updateRecord(
            record.copyWith(status: SettlementStatus.cancelled),
            action: 'cancel',
          );
          if (mounted && saved) Navigator.of(context).pop();
        },
        onEdit: () async {
          await showModalBottomSheet<AppRecord>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => ConfirmedRecordEditorSheet(
              record: record,
              personName: _store.personName(record.personId),
              onSave: (updated) => _saveRecordOrThrow(updated),
            ),
          );
        },
        onReschedule: () async {
          final date = await pickJalaliDate(context, record.date);
          if (!mounted || date == null) return;
          final time = await pickCupertinoTime(context, record.time);
          if (!mounted) return;
          final saved = await _updateRecord(
            record.copyWith(date: date, time: time),
            action: 'reschedule',
          );
          if (mounted && saved) Navigator.of(context).pop();
        },
        onEditReminders: () => unawaited(_openReminderEditor(record)),
        onSnooze: () async {
          final value = await showReminderPickerBottomSheet(
            context,
            initialDate: record.date,
            initialTime: record.time,
            initialSelection: reminderPresetLabel(
              _notificationPreferences.defaultSnoozeMinutes,
            ),
          );
          if (value == null) return;
          final until = dueDateTimeFromJalali(value.$1, value.$2);
          final current = _store.reminderPlanFor(record.id);
          final snoozed = current.copyWith(snoozedUntil: until.toUtc());
          final saved = await _runWrite(
            () => _store.saveReminderPlan(
              record.id,
              snoozed,
              auditAction: 'snooze',
            ),
          );
          if (!saved) return;
          final persisted = _store.recordById(record.id);
          if (persisted != null) {
            try {
              await _persistedReminders.reconcileRecord(persisted);
            } catch (_) {}
          }
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _openArchive() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArchivedPeopleScreen(
          people: _store.archivedPeople
              .map(
                (person) => ArchivedPersonViewData(
                  id: person.id,
                  name: person.name,
                  phone: person.phone,
                  openObligations: _store.openCountFor(person.id),
                ),
              )
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
            final restored = await _restorePerson(id);
            if (mounted && restored) Navigator.of(context).pop();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _buildPersonDetail(AppPerson person) => PersonDetailScreen(
    person: person,
    records: records,
    position: _store.customerPositionFor(person.id),
    personName: _store.personName,
    onTapRecord: _openRecord,
    onEditPerson: (target) async {
      await showModalBottomSheet<AppPerson>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ConfirmedPersonEditorSheet(
          existing: target,
          onSave: _savePersonOrThrow,
        ),
      );
    },
    onArchivePerson: (_) => _archivePerson(person),
  );

  List<ZarNotificationItem> _notificationItemsFor(
    Iterable<AppRecord> source, {
    bool overdue = false,
  }) => source
      .map(
        (record) => ZarNotificationItem(
          id: 'notification-${record.id}',
          recordId: record.id,
          title:
              '${record.operationLabel} • ${_store.personName(record.personId)}',
          subtitle:
              _notificationPreferences.privacy == NotificationPrivacy.private
              ? 'یک یادآوری کاری دارید.'
              : _notificationPreferences.privacy == NotificationPrivacy.limited
              ? '${record.operationLabel} برای ${_store.personName(record.personId)}'
              : '${record.assetLabel} • ${record.amountDisplay}',
          timeLabel: record.timeLabel(),
          isOverdue: overdue,
        ),
      )
      .toList(growable: false);

  Future<void> _openNotificationCenter() async {
    final currentTime = DateTime.now();
    final currentDate = Jalali.fromDateTime(currentTime);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(
          overdue: _notificationItemsFor(
            openObligations.where(
              (record) => isRecordOverdueAt(record, currentTime),
            ),
            overdue: true,
          ),
          today: _notificationItemsFor(
            openObligations.where(
              (record) =>
                  isSameJalali(record.date, currentDate) &&
                  !isRecordOverdueAt(record, currentTime),
            ),
          ),
          upcoming: _notificationItemsFor(
            openObligations.where(
              (record) => record.date.compareTo(currentDate) > 0,
            ),
          ),
          onOpenRecord: (recordId) {
            final target = _store.recordById(recordId);
            Navigator.of(context).pop();
            if (target != null) unawaited(_openRecord(target));
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
          onChanged: (value) =>
              setState(() => _notificationPreferences = value),
        ),
      ),
    );
  }

  Future<void> _openBackup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BackupScreen(
          manager: _backupManager,
          onOpenCoinCatalog: _openCoinCatalog,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openCoinCatalog() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoinCatalogScreen(
          types: _store.coinTypes,
          onSave: (value) async {
            await _store.saveCoinType(value);
            if (mounted) setState(() {});
          },
          onArchive: (value) async {
            await _store.archiveCoinType(value);
            if (mounted) setState(() {});
          },
          onRestore: (value) async {
            await _store.restoreCoinType(value);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null && !_ready) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('بارگذاری اطلاعات انجام نشد.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _load,
                child: const Text('تلاش دوباره'),
              ),
            ],
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
        onOpenSettings: _openBackup,
        unreadCount: openObligations.length,
      ),
      CalendarScreen(
        records: records,
        personName: _store.personName,
        onTapRecord: _openRecord,
      ),
      const SizedBox.shrink(),
      PhaseA2PeopleScreen(
        people: _store.activePeople,
        records: records,
        archivedCount: _store.archivedPeople.length,
        onAddPerson: () async {
          await showModalBottomSheet<AppPerson>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) =>
                ConfirmedPersonEditorSheet(onSave: _savePersonOrThrow),
          );
        },
        onOpenPerson: (person) => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => _buildPersonDetail(person))),
        onOpenArchive: _openArchive,
      ),
      HistoryScreen(
        records: historyRecords,
        personName: _store.personName,
        onTapRecord: _openRecord,
      ),
    ];

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: IndexedStack(index: _index, children: pages),
          ),
          bottomNavigationBar: ZBottomBar(
            currentIndex: _index,
            onTap: (value) {
              if (value == 2) {
                unawaited(_openQuickAdd());
              } else {
                setState(() => _index = value);
              }
            },
          ),
        ),
        if (_writing)
          const Positioned.fill(
            child: AbsorbPointer(
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
