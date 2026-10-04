
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'app_core.dart';
import 'widgets/zar_amount_display.dart';
import 'application/operational_dashboard_projector.dart';
import 'application/operational_inventory_projector.dart';
import 'application/zar_cash_projector.dart';
import 'domain/zar_cash_entry.dart';
import 'features/reminders/reminder_model.dart';
import 'domain/zar_domain_models.dart';


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
  final suffix = time == null ? '' : ' · $time';
  if (isSameJalali(record.date, current)) return 'امروز$suffix';
  if (isSameJalali(record.date, current.addDays(-1))) return 'دیروز$suffix';
  if (isSameJalali(record.date, current.addDays(1))) return 'فردا$suffix';
  return '${formatJalaliDate(record.date)}$suffix';
}

const _homeSecondaryColor = Color(0xFF6F6A62);
const _homeOverdueColor = Color(0xFF9D3636);
const _homeAmountColor = Color(0xFF9A6700);
const _homeNeutralAmountColor = Color(0xFF2A2927);

IconData _homeActivityIcon(AppRecord record) {
  if (record.type == RecordType.deal) {
    return CupertinoIcons.arrow_2_squarepath;
  }
  return record.operationLabel == 'دریافت' ? CupertinoIcons.arrow_down_circle : CupertinoIcons.arrow_up_circle;
}

class PhaseA2HomeScreen extends StatelessWidget {
  const PhaseA2HomeScreen({super.key, required this.records, required this.personName, required this.onTapRecord, required this.onOpenNotifications, required this.unreadCount, this.onOpenSettings, this.onOpenOverdue, this.onOpenHistory, this.dashboard, this.recentRecords = const [], this.onOpenPendingReceive, this.onOpenPendingDeliver, this.now, this.cash, this.onOpenCommitments, this.onOpenSearch});

  final List<AppRecord> records;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTapRecord;
  final VoidCallback onOpenNotifications;
  final int unreadCount;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenOverdue;
  final VoidCallback? onOpenHistory;
  final ZarOperationalDashboardProjection? dashboard;
  final List<AppRecord> recentRecords;
  final VoidCallback? onOpenPendingReceive;
  final VoidCallback? onOpenPendingDeliver;
  final DateTime? now;
  final ZarCashProjection? cash;
  final VoidCallback? onOpenCommitments;
  final VoidCallback? onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final currentTime = now ?? DateTime.now();
    final currentDate = Jalali.fromDateTime(currentTime);
    final overdue = records.where((r) => isRecordOverdueAt(r, currentTime)).toList(growable: false);
    final today = records.where((r) => isSameJalali(r.date, currentDate) && !isRecordOverdueAt(r, currentTime)).toList(growable: false);
    final tomorrow = records.where((r) => isSameJalali(r.date, currentDate.addDays(1))).toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _HomeHeader(
            currentDate: currentDate,
            unreadCount: unreadCount,
            onOpenNotifications: onOpenNotifications,
            onOpenSettings: onOpenSettings,
            onOpenSearch: onOpenSearch,
          ),
        ),
        if (cash != null) SliverToBoxAdapter(child: _HomeCashHero(cash: cash!, onTap: onOpenHistory)),
        if (dashboard != null) _dashboardSections(context, dashboard!, currentTime),
        if (onOpenCommitments != null && today.isNotEmpty)
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _HomeCommitmentsStrip(
              count: today.length,
              summary: today.map((r) => r.operationDisplayLabel).take(3).join(' · '),
              onTap: onOpenCommitments!,
            ),
          )),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeSectionHeading(
              title: title,
              titleColor: overdue ? _homeOverdueColor : null,
              onTap: maxItems != null && items.length > maxItems ? onViewAll : null,
              actionLabel: maxItems != null && items.length > maxItems ? 'مشاهده همه ${toPersianDigits(items.length.toString())} مورد' : null,
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

  Widget _dashboardSections(BuildContext context, ZarOperationalDashboardProjection value, DateTime currentTime) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget card({required String title, required int count, required List<ZarOperationalInventoryItem> items, required VoidCallback? onTap}) => _HomeObligationCard(title: title, count: count, items: items, records: records, personName: personName, onTapRecord: onTapRecord, onTap: onTap, accent: _homeNeutralAmountColor, now: currentTime);
            final receive = card(title: 'دریافتنی‌ها', count: value.pendingReceiveCount, items: value.inventory.pendingReceive, onTap: onOpenPendingReceive);
            final deliver = card(title: 'پرداختنی‌ها', count: value.pendingDeliverCount, items: value.inventory.pendingDeliver, onTap: onOpenPendingDeliver);
            if (constraints.maxWidth < 560) {
              return Column(children: [
                SizedBox(height: 168, child: receive),
                const SizedBox(height: 8),
                SizedBox(height: 168, child: deliver),
              ]);
            }
            return SizedBox(
              height: 168,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: receive),
                const SizedBox(width: 8),
                Expanded(child: deliver),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _recentSection(BuildContext context, DateTime currentTime) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.currentDate,
    required this.unreadCount,
    required this.onOpenNotifications,
    required this.onOpenSettings,
    this.onOpenSearch,
  });

  final Jalali currentDate;
  final int unreadCount;
  final VoidCallback onOpenNotifications;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenSearch;

  static const _weekdayNames = {
    DateTime.saturday: 'شنبه',
    DateTime.sunday: 'یکشنبه',
    DateTime.monday: 'دوشنبه',
    DateTime.tuesday: 'سه‌شنبه',
    DateTime.wednesday: 'چهارشنبه',
    DateTime.thursday: 'پنجشنبه',
    DateTime.friday: 'جمعه',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gregorian = currentDate.toDateTime();
    final weekday = _weekdayNames[gregorian.weekday] ?? '';
    final subtitle =
        'گالری طلای مهر · $weekday ${toPersianDigits(currentDate.day.toString())} ${monthName(currentDate.month)}';
    return Container(
      key: const ValueKey('home-header'),
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
        child: Row(
          key: const ValueKey('home-header-row'),
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              key: const ValueKey('home-header-logo'),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: const LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [Color(0xFFA9762E), Color(0xFFD9A75C)],
                ),
              ),
              child: const Text(
                'Z+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'ZAR',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      children: [
                        TextSpan(
                          text: '+',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onOpenSettings != null)
              _HomeHeaderIconButton(
                buttonKey: const ValueKey('home-settings-button'),
                tooltip: 'تنظیمات و داده‌ها',
                onPressed: onOpenSettings!,
                icon: CupertinoIcons.gear,
                size: 48,
              ),
            if (onOpenSearch != null)
              _HomeHeaderIconButton(
                buttonKey: const ValueKey('home-search-button'),
                tooltip: 'جستجو در فعالیت‌ها',
                onPressed: onOpenSearch!,
                icon: CupertinoIcons.search,
                size: 48,
              ),
            _NotificationBell(count: unreadCount, onTap: onOpenNotifications),
          ],
        ),
      ),
    );
  }
}

class _HomeHeaderIconButton extends StatelessWidget {
  const _HomeHeaderIconButton({
    required this.buttonKey,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.size = 48,
  });

  final Key buttonKey;
  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: tooltip,
    onPressed: onPressed,
    constraints: BoxConstraints.tightFor(width: size, height: size),
    padding: EdgeInsets.zero,
    iconSize: 22,
    style: IconButton.styleFrom(
      fixedSize: Size(size, size),
      minimumSize: Size(size, size),
      maximumSize: Size(size, size),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    icon: Icon(icon),
  );
}

class _HomeCashHero extends StatelessWidget {
  const _HomeCashHero({required this.cash, this.onTap});

  final ZarCashProjection cash;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toman = cash.balances
        .where((b) => b.key == 'currency:TOMAN')
        .map((b) => b.quantity)
        .firstOrNull ?? '0';
    final goldGrams = cash.balances
        .where((b) => b.key.startsWith('gold:'))
        .fold('0', (sum, b) => cashAdd(sum, b.quantity));
    final coinCount = cash.balances
        .where((b) => b.key.startsWith('coin:'))
        .fold('0', (sum, b) => cashAdd(sum, b.quantity));
    final currencyKinds = cash.balances
        .where((b) => b.key.startsWith('currency:') && b.key != 'currency:TOMAN')
        .length;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).toUtc();
    final yesterdayClose = cash.lines
        .where((l) => l.key == 'currency:TOMAN' && l.at.isBefore(startOfToday))
        .map((l) => l.running)
        .firstOrNull;
    String? trendLabel;
    if (yesterdayClose != null && yesterdayClose != '0') {
      final change = cashAdd(toman, yesterdayClose, sign: -1);
      if (change != '0') {
        final percent = cashDecimal(
          cashSigned(change).units * BigInt.from(100) ~/
              (cashSigned(yesterdayClose).units == BigInt.zero
                  ? BigInt.one
                  : cashSigned(yesterdayClose).units),
          1,
        );
        trendLabel = '${toPersianNumberText(percent)}٪ نسبت به دیروز';
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.dividerColor),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomLeft,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.primaryContainer.withValues(alpha: .55),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('موجودی صندوق امروز', style: theme.textTheme.labelMedium),
                  if (trendLabel != null)
                    Container(
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(trendLabel, style: theme.textTheme.labelSmall),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(child: Text(
                    toPersianNumberText(toman),
                    style: theme.textTheme.displaySmall,
                    overflow: TextOverflow.ellipsis,
                  )),
                  const SizedBox(width: 6),
                  Text('تومان', style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'طلا ${toPersianNumberText(goldGrams)} گرم · سکه ${toPersianNumberText(coinCount)} عدد · ارز ${toPersianDigits(currencyKinds.toString())} نوع',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCommitmentsStrip extends StatelessWidget {
  const _HomeCommitmentsStrip({
    required this.count,
    required this.summary,
    required this.onTap,
  });

  final int count;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              height: 22,
              alignment: Alignment.center,
              child: Text(toPersianDigits(count.toString()),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${toPersianDigits(count.toString())} تعهد برای امروز · $summary',
                style: theme.textTheme.labelLarge,
                overflow: TextOverflow.ellipsis),
            ),
            const Icon(CupertinoIcons.chevron_left, size: 18),
          ],
        ),
      ),
    );
  }
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
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: _homeAmountColor,
            textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            visualDensity: VisualDensity.compact,
          ),
          child: Text(actionLabel!),
        ),
    ],
  );
}

class _HomeObligationCard extends StatelessWidget {
  const _HomeObligationCard({required this.title, required this.count, required this.items, required this.records, required this.personName, required this.onTapRecord, required this.onTap, required this.accent, required this.now});
  final String title;
  final int count;
  final List<ZarOperationalInventoryItem> items;
  final List<AppRecord> records;
  final String Function(String) personName;
  final ValueChanged<AppRecord> onTapRecord;
  final VoidCallback? onTap;
  final Color accent;
  final DateTime now;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey('home-obligation-$title'),
    child: _HomeContainer(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text('${toPersianDigits(count.toString())} مورد', style: const TextStyle(color: _homeSecondaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (items.isEmpty)
                const _PhaseA2EmptyRow(label: 'موردی ثبت نشده است.')
              else
                ...items.take(2).map((item) {
                  final people = <String>{};
                  AppRecord? matchedRecord;
                  for (final movement in item.movements) {
                    people.add(personName(movement.personId));
                    for (final candidate in records) {
                      if (candidate.id == movement.recordId) {
                        matchedRecord ??= candidate;
                        break;
                      }
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (people.isNotEmpty)
                                ...people.take(1).map(
                                  (name) => GestureDetector(
                                    onTap: matchedRecord == null
                                        ? null
                                        : () => onTapRecord(matchedRecord!),
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                    ),
                                  ),
                                ),
                              if (matchedRecord != null)
                                Text(
                                  _homeDueLabel(matchedRecord, now),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        color: _homeSecondaryColor,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 132,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _HomeInventoryLine(
                              item: item,
                              accent: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const Spacer(),
            ]),
          ),
          if (onTap != null && items.isNotEmpty)
            Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(onPressed: onTap, style: TextButton.styleFrom(foregroundColor: _homeAmountColor, textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600), minimumSize: Size.zero, padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact), child: const Text('مشاهده همه'))),
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
      ZarGoldInventoryItem(:final fineness, :final grams) => _HomeAmountParts(toPersianNumberText(grams), 'گرم طلا', fineness == null ? 'عیار نامشخص' : 'عیار ${toPersianDigits(fineness)}'),
      ZarCoinInventoryItem(:final displayName, :final quantity) => _HomeAmountParts(toPersianDigits(quantity.toString()), 'عدد ${toPersianDigits(displayName)}', null),
      ZarCurrencyInventoryItem(:final code, :final decimalAmount) => _HomeAmountParts(toPersianNumberText(decimalAmount), code == 'TOMAN' ? 'تومان' : code, null),
    };
    return _HomeAmountText(amount: display.amount, unit: display.unit, color: accent, purity: display.detail);
  }
}

class _HomeAmountParts {
  const _HomeAmountParts(this.amount, this.unit, this.detail);
  final String amount;
  final String unit;
  final String? detail;
}

class _HomeAmountText extends StatelessWidget {
  const _HomeAmountText({required this.amount, required this.unit, required this.color, this.purity});
  final String amount;
  final String unit;
  final Color color;
  final String? purity;

  @override
  Widget build(BuildContext context) => ZarAmountDisplay(
    amount: amount,
    unit: unit,
    purity: purity,
    amountStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
    unitStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
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
    if (records.isEmpty) {
      return const _HomeContainer(child: Padding(padding: EdgeInsets.all(16), child: Text('هنوز فعالیتی ثبت نشده است.')));
    }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(_homeActivityIcon(record), size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${record.operationDisplayLabel} ${record.assetLabel} $relation ${personName(record.personId)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HomeRecordAmountText(record: record, color: _homeNeutralAmountColor),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _homeActivityTimestamp(record, now),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const SizedBox(width: 22, child: Align(alignment: Alignment.centerLeft, child: Icon(CupertinoIcons.chevron_left, size: 17))),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeContainer extends StatelessWidget {
  const _HomeContainer({required this.child, this.onTap, this.backgroundColor, this.borderColor});
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decorated = Container(
      decoration: BoxDecoration(color: backgroundColor ?? theme.colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor ?? theme.dividerColor)),
      child: child,
    );
    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: decorated),
    );
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
    backgroundColor: overdue ? const Color(0xFFFFF8F8) : null,
    borderColor: overdue ? const Color(0xFFE9CACA) : null,
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
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(record.operationDisplayLabel, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 1),
            Text(person, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _HomeRecordAmountText(record: record, color: overdue ? _homeOverdueColor : _homeNeutralAmountColor, fontSize: 14),
            const SizedBox(height: 1),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (!overdue) ...[
                Text(record.statusLabel(), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                const SizedBox(width: 4),
              ],
              Text(_homeDueLabel(record, now), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: overdue ? _homeOverdueColor : null, fontSize: 11)),
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
    return ZarAmountDisplay(
      amount: display.amount,
      unit: display.unit,
      purity: display.detail,
      amountStyle: baseStyle?.copyWith(color: color, fontWeight: FontWeight.w700),
      unitStyle: baseStyle?.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = toPersianDigits(count > 99 ? '99+' : count.toString());
    final singleDigit = count < 10;
    return SizedBox(
      key: const ValueKey('home-notification-bell'),
      width: 48,
      height: 48,
      child: Stack(
      children: [
        Positioned.fill(
          child: IconButton(
            tooltip: 'اعلان‌ها',
            onPressed: onTap,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            padding: EdgeInsets.zero,
            iconSize: 22,
            style: IconButton.styleFrom(
              fixedSize: const Size(48, 48),
              minimumSize: const Size(48, 48),
              maximumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(CupertinoIcons.bell),
          ),
        ),
        if (count > 0)
          Positioned(
            top: 4,
            left: 3,
            child: Container(
              key: const ValueKey('home-notification-badge'),
              width: singleDigit ? 16 : null,
              height: 16,
              constraints: const BoxConstraints(minWidth: 16),
              padding: singleDigit ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF9D3636),
                shape: singleDigit ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: singleDigit ? null : BorderRadius.circular(20),
              ),
              child: Text(
                badgeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
      ),
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
