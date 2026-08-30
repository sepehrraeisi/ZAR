import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../app_core.dart';
import '../domain/zar_amount_formatter.dart';
import '../domain/zar_amount_parser.dart';
import '../domain/zar_domain_models.dart';
import '../domain/zar_reminder_plan.dart';

/// Temporary bridge while the polished Phase A.2 widgets are migrated from the
/// original prototype models to the production domain models.
///
/// New persistence/business logic should use `Zar*` domain types. This adapter
/// keeps the current UI functional without making Firestore understand legacy
/// display strings.
class ZarLegacyPresentationBridge {
  const ZarLegacyPresentationBridge({
    required this.businessId,
    required this.userId,
  });

  final String businessId;
  final String userId;

  AppPerson personToUi(ZarPerson person) => AppPerson(
    id: person.id,
    name: person.displayName,
    phone: person.phone,
    note: person.note,
    archived: person.archived,
  );

  ZarPerson personFromUi(
    AppPerson person, {
    ZarPerson? existing,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return ZarPerson(
      id: person.id,
      displayName: person.name,
      phone: person.phone,
      note: person.note,
      archived: person.archived,
      createdAt: existing?.createdAt ?? timestamp,
      updatedAt: timestamp,
      createdBy: existing?.createdBy ?? userId,
    );
  }

  AppRecord settlementToUi(ZarSettlement settlement) {
    final local = settlement.scheduledAt.toLocal();
    return AppRecord(
      id: settlement.id,
      type: RecordType.settlement,
      operationLabel: settlement.direction == ZarSettlementDirection.receive
          ? 'دریافت'
          : 'تحویل',
      personId: settlement.personId,
      amountDisplay: _amountDisplay(settlement.amount),
      assetLabel: _assetLabel(settlement.amount),
      currencyCode: _currencyCode(settlement.amount),
      date: Jalali.fromDateTime(local),
      time: settlement.hasTime
          ? TimeOfDay(hour: local.hour, minute: local.minute)
          : null,
      status: _settlementStatusToUi(settlement.status),
      note: settlement.note,
    );
  }

  ZarSettlement settlementFromUi(
    AppRecord record, {
    ZarSettlement? existing,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final scheduled = _uiDateTime(record).toUtc();
    final status = _settlementStatusFromUi(record.status);
    final wasCompleted = existing?.status == ZarSettlementStatus.completed;
    final completion = status == ZarSettlementStatus.completed
        ? (wasCompleted ? existing!.completedAt : timestamp)
        : null;

    return ZarSettlement(
      id: record.id,
      businessId: existing?.businessId ?? businessId,
      dealId: existing?.dealId,
      personId: record.personId,
      direction: record.operationLabel == 'دریافت'
          ? ZarSettlementDirection.receive
          : ZarSettlementDirection.deliver,
      amount: _amountFromUi(record),
      scheduledAt: scheduled,
      hasTime: record.time != null,
      status: status,
      reminderPlan: existing?.reminderPlan ?? const ZarReminderPlan(),
      completedAt: completion,
      completedBy: status == ZarSettlementStatus.completed
          ? (existing?.completedBy ?? userId)
          : null,
      note: record.note,
      createdBy: existing?.createdBy ?? userId,
      createdAt: existing?.createdAt ?? timestamp,
      updatedAt: timestamp,
    );
  }

  AppRecord dealToUi(ZarDeal deal) {
    final local = deal.dealAt.toLocal();
    return AppRecord(
      id: deal.id,
      type: RecordType.deal,
      operationLabel: deal.type == ZarDealType.buy ? 'خرید' : 'فروش',
      personId: deal.personId,
      amountDisplay: _amountDisplay(deal.amount),
      assetLabel: _assetLabel(deal.amount),
      currencyCode: _currencyCode(deal.amount),
      date: Jalali.fromDateTime(local),
      time: TimeOfDay(hour: local.hour, minute: local.minute),
      status: _dealStatusToUi(deal.status),
      note: deal.note,
      goldFineness: deal.pricing is ZarGoldDealPricing
          ? (deal.pricing! as ZarGoldDealPricing).fineness
          : null,
      goldInputWeight: deal.pricing is ZarGoldDealPricing
          ? (deal.pricing! as ZarGoldDealPricing).inputWeight
          : null,
      goldInputUnit: deal.pricing is ZarGoldDealPricing
          ? (deal.pricing! as ZarGoldDealPricing).inputWeightUnit.name
          : null,
      goldPriceUnit: deal.pricing is ZarGoldDealPricing
          ? (deal.pricing! as ZarGoldDealPricing).priceUnit.name
          : null,
      goldEquivalentWeight: deal.pricing is ZarGoldDealPricing
          ? ((deal.pricing! as ZarGoldDealPricing).inputWeightUnit ==
                    ZarGoldUnit.mesghal
                ? (deal.pricing! as ZarGoldDealPricing).normalizedWeightGrams
                : (deal.pricing! as ZarGoldDealPricing).equivalentWeightMesghal)
          : null,
      goldEquivalentPrice: deal.pricing is ZarGoldDealPricing
          ? ((deal.pricing! as ZarGoldDealPricing).priceUnit ==
                    ZarGoldUnit.mesghal
                ? (deal.pricing! as ZarGoldDealPricing)
                      .equivalentPricePerGramToman
                : (deal.pricing! as ZarGoldDealPricing)
                      .equivalentPricePerMesghalToman)
          : null,
      tomanRate: switch (deal.pricing) {
        ZarGoldDealPricing() =>
          (deal.pricing! as ZarGoldDealPricing).pricePerUnitToman.wholeTomans
              .toString(),
        ZarCurrencyDealPricing() =>
          (deal.pricing! as ZarCurrencyDealPricing).tomanPerUnit,
        null => null,
      },
      totalToman: deal.pricing?.totalToman.wholeTomans,
    );
  }

  ZarDeal dealFromUi(AppRecord record, {ZarDeal? existing, DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return ZarDeal(
      id: record.id,
      businessId: existing?.businessId ?? businessId,
      type: record.operationLabel == 'خرید'
          ? ZarDealType.buy
          : ZarDealType.sell,
      personId: record.personId,
      amount: _amountFromUi(record),
      pricing: _dealPricingFromUi(record),
      dealAt: _uiDateTime(record).toUtc(),
      status: _dealStatusFromUi(record.status),
      note: record.note,
      createdBy: existing?.createdBy ?? userId,
      createdAt: existing?.createdAt ?? timestamp,
      updatedAt: timestamp,
    );
  }

  ZarAssetAmount _amountFromUi(AppRecord record) {
    if (record.currencyCode != null || record.assetLabel == 'ارز') {
      final code = record.currencyCode ?? 'USD';
      return ZarCurrencyAssetAmount(
        ZarAmountParser.currency(
          _numericOnly(record.amountDisplay),
          code: code,
        ),
      );
    }
    final inputWeight =
        record.goldInputWeight ??
        ZarAmountParser.gold(record.amountDisplay).decimal;
    final inputUnit = ZarGoldUnit.values.byName(
      record.goldInputUnit ?? ZarGoldUnit.gram.name,
    );
    return ZarGoldAssetAmount(
      ZarGoldQuantity(
        decimal: zarGoldWeightInGrams(inputWeight, inputUnit),
        unit: ZarGoldUnit.gram,
        purity: record.goldFineness?.toString(),
      ),
    );
  }

  ZarDealPricing? _dealPricingFromUi(AppRecord record) {
    if (record.tomanRate == null || record.totalToman == null) return null;
    if (record.assetLabel == 'ارز') {
      return ZarCurrencyDealPricing(
        tomanPerUnit: record.tomanRate!,
        totalToman: ZarTomanAmount(record.totalToman!),
      );
    }
    if (record.goldFineness == null) {
      throw const FormatException('Gold fineness is required.');
    }
    return ZarGoldDealPricing(
      fineness: record.goldFineness!,
      inputWeight:
          record.goldInputWeight ??
          ZarAmountParser.gold(record.amountDisplay).decimal,
      inputWeightUnit: ZarGoldUnit.values.byName(
        record.goldInputUnit ?? ZarGoldUnit.gram.name,
      ),
      priceUnit: ZarGoldUnit.values.byName(
        record.goldPriceUnit ?? ZarGoldUnit.gram.name,
      ),
      pricePerUnitToman: ZarTomanAmount(int.parse(record.tomanRate!)),
      totalToman: ZarTomanAmount(record.totalToman!),
    );
  }

  String _numericOnly(String display) {
    return display
        .replaceAll(RegExp(r'[A-Za-z$€£₺]'), '')
        .replaceAll('AED', '')
        .replaceAll('CAD', '')
        .trim();
  }

  DateTime _uiDateTime(AppRecord record) {
    final gregorian = record.date.toGregorian();
    return DateTime(
      gregorian.year,
      gregorian.month,
      gregorian.day,
      record.time?.hour ?? 12,
      record.time?.minute ?? 0,
    );
  }

  String _amountDisplay(ZarAssetAmount amount) {
    switch (amount) {
      case ZarGoldAssetAmount():
        return toPersianDigits(amount.value.decimal);
      case ZarCurrencyAssetAmount():
        return ZarAmountFormatter.currency(amount.value);
    }
  }

  String _assetLabel(ZarAssetAmount amount) =>
      amount.assetType == ZarAssetType.gold ? 'گرم طلا' : 'ارز';

  String? _currencyCode(ZarAssetAmount amount) =>
      amount is ZarCurrencyAssetAmount ? amount.value.code : null;

  SettlementStatus _settlementStatusToUi(ZarSettlementStatus status) {
    switch (status) {
      case ZarSettlementStatus.open:
        return SettlementStatus.open;
      case ZarSettlementStatus.completed:
        return SettlementStatus.completed;
      case ZarSettlementStatus.cancelled:
        return SettlementStatus.cancelled;
    }
  }

  ZarSettlementStatus _settlementStatusFromUi(SettlementStatus status) {
    switch (status) {
      case SettlementStatus.open:
        return ZarSettlementStatus.open;
      case SettlementStatus.completed:
        return ZarSettlementStatus.completed;
      case SettlementStatus.cancelled:
        return ZarSettlementStatus.cancelled;
    }
  }

  SettlementStatus _dealStatusToUi(ZarDealStatus status) {
    switch (status) {
      case ZarDealStatus.active:
        return SettlementStatus.open;
      case ZarDealStatus.completed:
        return SettlementStatus.completed;
      case ZarDealStatus.cancelled:
        return SettlementStatus.cancelled;
    }
  }

  ZarDealStatus _dealStatusFromUi(SettlementStatus status) {
    switch (status) {
      case SettlementStatus.open:
        return ZarDealStatus.active;
      case SettlementStatus.completed:
        return ZarDealStatus.completed;
      case SettlementStatus.cancelled:
        return ZarDealStatus.cancelled;
    }
  }
}
