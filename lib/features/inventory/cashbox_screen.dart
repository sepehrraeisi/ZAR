import 'package:flutter/material.dart';
import '../../app_core.dart'
    show toPersianDigits, toPersianNumberText, formatJalaliDate, pickJalaliDate, pickCupertinoTime;
import 'package:shamsi_date/shamsi_date.dart';
import '../../application/zar_cash_projector.dart';
import '../../application/zar_phase_a2_store.dart';
import '../../domain/zar_cash_entry.dart';
import '../../domain/zar_domain_models.dart';
import '../../domain/zar_id_generator.dart';
import '../../domain/zar_payment_allocation.dart';
import '../editors/persian_numeric_input_formatter.dart';
import '../theme/zar_theme.dart';

class CashboxScreen extends StatefulWidget {
  const CashboxScreen({super.key, required this.store, required this.businessId,
    required this.onOpenRecord, required this.onChanged, this.onOpenDailyReport,
    this.onOpenDailyReportForDate, this.initialTab, this.tabNotifier});
  final ZarPhaseA2Store store;
  final String businessId;
  final ValueChanged<String> onOpenRecord;
  final VoidCallback onChanged;
  final VoidCallback? onOpenDailyReport;
  final ValueChanged<Jalali>? onOpenDailyReportForDate;
  final int? initialTab;
  final ValueNotifier<int>? tabNotifier;
  @override
  State<CashboxScreen> createState() => _CashboxScreenState();
}

class _CashboxScreenState extends State<CashboxScreen>
    with TickerProviderStateMixin {
  String? _assetFilter;
  bool _todayOnly = false;
  DateTime? _from, _through;
  TabController? _tabs;
  ValueNotifier<int>? _listenedTab;
  ZarPhaseA2Store get store => widget.store;
  ZarCashProjection get projection => const ZarCashProjector().project(
    entries: store.cashEntries, settlements: store.settlements,
    allocations: store.paymentAllocations);

  String number(String value) => toPersianNumberText(value);
  String assetLabel(ZarAssetAmount asset) => toPersianNumberText(cashAssetLabel(asset));
  String date(DateTime value) {
    final local = value.toLocal();
    final hour = toPersianDigits(local.hour.toString().padLeft(2, '0'));
    final minute = toPersianDigits(local.minute.toString().padLeft(2, '0'));
    return '${formatJalaliDate(Jalali.fromDateTime(local))} · $hour:$minute';
  }

  @override
  void initState() {
    super.initState();
    _listenTabNotifier();
  }

  @override
  void didUpdateWidget(covariant CashboxScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabNotifier != oldWidget.tabNotifier) _listenTabNotifier();
  }

  void _listenTabNotifier() {
    _listenedTab?.removeListener(_onTabRequest);
    _listenedTab = widget.tabNotifier;
    _listenedTab?.addListener(_onTabRequest);
  }

  void _onTabRequest() {
    final target = widget.tabNotifier!.value;
    if (_tabs != null && _tabs!.index != target) _tabs!.animateTo(target);
  }

  @override
  void dispose() {
    _listenedTab?.removeListener(_onTabRequest);
    _tabs?.dispose();
    super.dispose();
  }

  int get _pendingDeliveryCount => store.deals
    .where((d) => d.status != ZarDealStatus.cancelled)
    .where((d) => cashDeliveredForDeal(d, store.cashEntries, store.settlements)
      .entries.any((q) => cashCompare(q.value, cashQuantities(d.amount)[q.key] ?? '0') < 0))
    .length;

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs ??= TabController(length: 3, vsync: this,
      initialIndex: widget.initialTab?.clamp(0, 2) ?? 0);
    return AnimatedBuilder(
      animation: Listenable.merge([store, if (widget.tabNotifier != null) widget.tabNotifier]),
      builder: (context, _) {
        final p = projection;
        final now = DateTime.now();
        final rows = p.lines.where((row) => (_assetFilter == null || row.key == _assetFilter) &&
          (!_todayOnly || DateUtils.isSameDay(row.at.toLocal(), now)) &&
          (_from == null || !row.at.isBefore(_from!)) &&
          (_through == null || row.at.isBefore(_through!))).toList();
        return Scaffold(
        appBar: AppBar(title: const Text('صندوق'), actions: [
          IconButton(
            key: const ValueKey('cashbox-date-shortcut'),
            tooltip: 'گزارش یک روز',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () async {
              final picked = await pickJalaliDate(
                context,
                Jalali.fromDateTime(DateTime.now()),
              );
              if (picked != null) widget.onOpenDailyReportForDate?.call(picked);
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'گزینه‌های بیشتر',
            onSelected: (value) {
              if (value == 'report') widget.onOpenDailyReport?.call();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('گزارش روزانه امروز')),
            ],
          ),
          if (widget.onOpenDailyReport != null)
            IconButton(
              key: const ValueKey('cashbox-daily-report'),
              tooltip: 'گزارش روزانه',
              icon: const Icon(Icons.receipt_long),
              onPressed: widget.onOpenDailyReport,
            ),
        ], bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: TabBar(
              controller: tabs,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              dividerColor: Theme.of(context).dividerColor,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              tabs: [
                const Tab(text: 'مانده و گردش'),
                if (_pendingDeliveryCount > 0)
                  Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text('تحویل معاملات', maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Vazirmatn'))),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: context.zarSemantic.negative,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      alignment: Alignment.center,
                      child: Text(toPersianDigits(_pendingDeliveryCount.toString()),
                        style: TextStyle(fontSize: 10, height: 1, color: context.zarSemantic.onNegative)),
                    ),
                  ]))
                else
                  const Tab(text: 'تحویل معاملات'),
                const Tab(text: 'تعهدهای آینده'),
              ],
            ),
          )),
          body: TabBarView(controller: tabs, children: [
            _balancesAndJournal(p, rows, now),
            _deliveries(),
            ListView(padding: const EdgeInsets.all(16), children: [
              const Text('این تعهدها تا زمان انجام، مانده واقعی صندوق را تغییر نمی‌دهند.'),
              for (final s in store.settlements.where((s) => s.isOpen)) Card(child: ListTile(
                title: Text('${s.direction == ZarSettlementDirection.receive ? 'دریافت از' : 'پرداخت به'} ${store.personName(s.personId)}'),
                subtitle: Text('${cashSplitAssets(s.amount).map((a) => '${assetLabel(a)}: ${number(cashQuantities(a).values.single)}').join(' / ')} · ${date(s.scheduledAt)}'),
                onTap: () => widget.onOpenRecord(s.id),
              )),
            ]),
          ]),
        );
      },
    );
  }

  Widget _balancesAndJournal(ZarCashProjection p, List<ZarCashLine> rows, DateTime now) {
    final semantic = context.zarSemantic;
    final startOfToday = DateTime(now.year, now.month, now.day).toUtc();
    final visibleKeys = rows.map((r) => r.key).toSet();
    final filteredAll = p.lines.where((l) => visibleKeys.contains(l.key)).toList();
    final opening = filteredAll
      .where((l) => l.at.isBefore(startOfToday))
      .map((l) => l.running)
      .firstOrNull ?? '0';
    final inflow = filteredAll
      .where((l) => !l.at.isBefore(startOfToday) && l.direction == ZarSettlementDirection.receive)
      .fold('0', (sum, l) => cashAdd(sum, l.quantity));
    final outflow = filteredAll
      .where((l) => !l.at.isBefore(startOfToday) && l.direction == ZarSettlementDirection.deliver)
      .fold('0', (sum, l) => cashAdd(sum, l.quantity));

    final dayGroups = <String, List<ZarCashLine>>{};
    for (final row in rows) {
      final key = Jalali.fromDateTime(row.at.toLocal());
      (dayGroups['${key.year}-${key.month}-${key.day}'] ??= []).add(row);
    }

    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 150), children: [
        if (p.balances.isEmpty) const Text('صندوق هنوز گردشی ندارد. موجودی واقعی فعلی را از «موجودی آغازین» وارد کنید. خریدهای قبلی، تحویل قطعی محسوب نشده‌اند.'),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: p.balances.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _assetCard(p.balances[index]),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final (label, kind) in const [('وجه نقد', 'currency:TOMAN'), ('طلا', 'gold:'), ('ارز', 'currency:'), ('سکه', 'coin:')])
            FilterChip(
              label: Text(label),
              selected: _assetFilter == kind || (_assetFilter?.startsWith(kind) ?? false),
              onSelected: (v) => setState(() => _assetFilter = v ? kind : null),
            ),
          FilterChip(label: const Text('امروز'), selected: _todayOnly, onSelected: (v) => setState(() => _todayOnly = v)),
          ActionChip(label: const Text('بازه تاریخ'), onPressed: _pickRange),
          if (_from != null) ActionChip(label: Text('${formatJalaliDate(Jalali.fromDateTime(_from!))} تا ${formatJalaliDate(Jalali.fromDateTime(_through!.subtract(const Duration(days: 1))))} ×'), onPressed: () => setState(() { _from = null; _through = null; })),
        ]),
        if (p.balances.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              _dayStat('مانده اول روز', number(opening), null),
              _dayDivider(context),
              _dayStat('ورودی', number(inflow), semantic.positive),
              _dayDivider(context),
              _dayStat('خروجی', number(outflow), semantic.negative),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        for (final entry in dayGroups.entries) ...[
          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${entry.key == _todayKey(now) ? 'امروز · ' : ''}${formatJalaliDate(Jalali.fromDateTime(entry.value.first.at.toLocal()))}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('مانده ${number(entry.value.first.running)}',
                style: Theme.of(context).textTheme.labelSmall),
            ],
          )),
          Card(clipBehavior: Clip.antiAlias, child: Column(children: [
            for (final (index, row) in entry.value.indexed) ...[
              if (index > 0) Divider(height: 1, color: Theme.of(context).dividerColor),
              ListTile(
                isThreeLine: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                title: Text('${row.direction == ZarSettlementDirection.receive ? '+' : '−'}${number(row.quantity)} · ${assetLabel(row.asset)}'),
                subtitle: Text('${row.label}${row.personId == null ? '' : ' · ${store.personName(row.personId!)}'}\n${date(row.at)} · مانده ${number(row.running)}'),
                onTap: () => _lineDetail(row),
              ),
            ],
          ])),
        ],
        if (!store.supportsCash) const Text('ثبت دفتر صندوق در این روش ذخیره‌سازی پشتیبانی نمی‌شود.'),
      ]),
      PositionedDirectional(
        bottom: 12, start: 12, end: 12,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Row(children: [
            Expanded(flex: 100, child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: semantic.positive,
                foregroundColor: semantic.onPositive,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => _entry('receive'),
              icon: const Icon(Icons.south_west),
              label: const Text('دریافت'),
            )),
            const SizedBox(width: 8),
            Expanded(
              flex: 100,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: semantic.negative,
                  foregroundColor: semantic.onNegative,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => _entry('pay'),
                icon: const Icon(Icons.north_east),
                label: const Text('پرداخت'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 115,
              child: SizedBox(
                height: 48,
                child: PopupMenuButton<String>(
                  tooltip: 'سایر عملیات',
                  onSelected: (v) => _entry(v),
                  itemBuilder: (_) => [
                    if (store.cashEntries.isEmpty) const PopupMenuItem(value: 'opening', child: Text('موجودی آغازین')),
                    const PopupMenuItem(value: 'contribution', child: Text('آورده به صندوق')),
                    const PopupMenuItem(value: 'withdrawal', child: Text('برداشت شخصی')),
                    const PopupMenuItem(value: 'expense', child: Text('هزینه')),
                  ],
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.more_horiz, size: 20),
                      const SizedBox(width: 6),
                      Flexible(child: Text('سایر عملیات', style: Theme.of(context).textTheme.labelLarge,
                        overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  String _todayKey(DateTime now) => '${now.year}-${now.month}-${now.day}';

  Widget _assetCard(ZarCashBalance balance) {
    final selected = _assetFilter == balance.key ||
      (_assetFilter?.startsWith(balance.key.split('|').first) ?? false);
    final semantic = context.zarSemantic;
    final scaffold = Theme.of(context).scaffoldBackgroundColor;
    final negative = balance.quantity.startsWith('-');
    return GestureDetector(
      onTap: () => setState(() => _assetFilter = _assetFilter == balance.key ? null : balance.key),
      child: Container(
        width: 208,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(assetLabel(balance.asset), style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? scaffold : Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('${number(balance.quantity)}${balance.key.startsWith('gold:') ? ' گرم' : ''}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: negative ? semantic.negative : (selected ? scaffold : Theme.of(context).colorScheme.onSurface))),
        ]),
      ),
    );
  }

  Widget _dayStat(String label, String value, Color? color) => Expanded(child: Column(children: [
    Text(label, style: Theme.of(context).textTheme.labelSmall),
    const SizedBox(height: 2),
    Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
  ]));

  Widget _dayDivider(BuildContext context) => Container(
    width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: .3),
  );

  Future<void> _pickRange() async {
    final start = await pickJalaliDate(context, Jalali.fromDateTime(_from ?? DateTime.now()));
    if (start == null || !mounted) return;
    final end = await pickJalaliDate(context, start);
    if (end == null || !mounted) return;
    final a = start.toDateTime(), b = end.toDateTime();
    if (b.isBefore(a)) return;
    setState(() { _from = a; _through = b.add(const Duration(days: 1)); _todayOnly = false; });
  }

  Widget _deliveries() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('ثبت خرید یا فروش به‌تنهایی ورود یا خروج از صندوق نیست. تحویل را به مقدار واقعی ثبت کنید؛ پرداخت وجه مستقل است.'),
    for (final deal in store.deals.where((d) => d.status != ZarDealStatus.cancelled)) ...[
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${deal.type == ZarDealType.buy ? 'خرید از' : 'فروش به'} ${store.personName(deal.personId)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(date(deal.dealAt)),
          for (final asset in cashSplitAssets(deal.amount).fold<Map<String, ZarAssetAmount>>({}, (map, a) => map..putIfAbsent(cashQuantities(a).keys.single, () => a)).values) _deliveryRow(deal, asset),
          if (deal.pricing != null) TextButton(onPressed: () => _entry(
            deal.type == ZarDealType.buy ? 'pay' : 'receive',
            asset: ZarCurrencyAssetAmount(ZarCurrencyAmount(code: 'TOMAN', minorUnits: 1, minorUnitScale: 0)),
            financialDeal: deal), child: const Text('ثبت وجه بابت این معامله')),
          TextButton(onPressed: () => widget.onOpenRecord(deal.id), child: const Text('جزئیات معامله')),
        ],
      ))),
    ],
  ]);

  Widget _deliveryRow(ZarDeal deal, ZarAssetAmount asset) {
    final q = cashQuantities(asset).entries.single;
    final delivered = cashDeliveredForDeal(deal, store.cashEntries, store.settlements)[q.key] ?? '0';
    final total = cashQuantities(deal.amount)[q.key]!;
    final remaining = cashAdd(total, delivered, sign: -1);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(assetLabel(asset)),
        Text('کل ${number(total)} · تحویل‌شده ${number(delivered)} · باقی‌مانده ${number(remaining)}'),
        if (cashCompare(remaining, '0') > 0) OutlinedButton(
          onPressed: () => _entry('delivery', asset: asset, deliveryDeal: deal, maximum: remaining),
          child: const Text('ثبت تحویل کامل یا جزئی'),
        ),
      ],
    ));
  }

  Future<void> _lineDetail(ZarCashLine row) async {
    final e = row.entry;
    final canReverse = e != null && e.kind != ZarCashEntryKind.opening && e.kind != ZarCashEntryKind.reversal &&
      !store.cashEntries.any((r) => r.reversesId == e.id);
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (context) => SafeArea(
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(row.label, style: const TextStyle(fontSize: 20)),
        Text('${assetLabel(row.asset)}: ${number(row.quantity)}'),
        Text('مانده پس از سند: ${number(row.running)}'), Text(date(row.at)),
        if (e?.countedQuantity != null) Text('شمارش: ${number(e!.countedQuantity!)} · انتظار: ${number(e.expectedQuantity!)}'),
        if (row.settlement != null) TextButton(onPressed: () { Navigator.pop(context); widget.onOpenRecord(row.id); }, child: const Text('باز کردن سند')),
        if (canReverse) OutlinedButton(onPressed: () { Navigator.pop(context); _entry('reversal', asset: row.asset, reversal: e); }, child: const Text('ثبت برگشت با دلیل')),
      ])),
    ));
  }

  Future<void> _entry(String operation, {ZarAssetAmount? asset, String? expected,
    ZarDeal? deliveryDeal, ZarDeal? financialDeal, String? maximum, ZarCashEntry? reversal}) async {
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true,
      builder: (_) => _CashEntrySheet(store: store, businessId: widget.businessId, operation: operation,
        initialAsset: asset, expected: expected, deliveryDeal: deliveryDeal, financialDeal: financialDeal,
        maximum: maximum, reversal: reversal));
    if (saved == true) widget.onChanged();
  }
}

class _CashEntrySheet extends StatefulWidget {
  const _CashEntrySheet({required this.store, required this.businessId, required this.operation,
    this.initialAsset, this.expected, this.deliveryDeal, this.financialDeal, this.maximum, this.reversal});
  final ZarPhaseA2Store store;
  final String businessId, operation;
  final ZarAssetAmount? initialAsset;
  final String? expected, maximum;
  final ZarDeal? deliveryDeal, financialDeal;
  final ZarCashEntry? reversal;
  @override
  State<_CashEntrySheet> createState() => _CashEntrySheetState();
}

class _CashEntrySheetState extends State<_CashEntrySheet> {
  final _quantity = TextEditingController(), _reason = TextEditingController();
  final _purity = TextEditingController(text: '750'), _weight = TextEditingController(text: '0.5');
  final _id = zarNewId('cash');
  ZarCashEntry? _pendingEntry;
  ZarSettlement? _pendingSettlement;
  String _type = 'cash', _currency = 'USD';
  ZarCoinType? _coin;
  String? _person, _error;
  bool _saving = false, _future = false;
  DateTime _at = DateTime.now();
  bool get customer => widget.operation == 'receive' || widget.operation == 'pay';
  String number(String value) => toPersianNumberText(value);
  String assetLabel(ZarAssetAmount asset) => toPersianNumberText(cashAssetLabel(asset));
  String get title => switch (widget.operation) {
    'receive' => 'دریافت به صندوق', 'pay' => 'پرداخت از صندوق', 'opening' => 'موجودی آغازین',
    'count' => 'شمارش و تطبیق', 'delivery' => 'تحویل بابت معامله', 'reversal' => 'برگشت سند',
    'withdrawal' => 'برداشت شخصی', 'expense' => 'هزینه', _ => 'آورده به صندوق',
  };
  @override
  void initState() {
    super.initState();
    _person = widget.financialDeal?.personId;
    _quantity.text = toPersianNumberText(widget.maximum ?? (widget.reversal == null ? '' : cashQuantities(widget.reversal!.amount).values.single));
    _coin = widget.store.coinTypes.where((c) => !c.archived).firstOrNull;
    if (widget.operation == 'delivery') _reason.text = 'تحویل واقعی بابت معامله';
    if (widget.operation == 'opening') _reason.text = 'موجودی واقعی در شروع صندوق';
    if (widget.financialDeal != null) _reason.text = 'وجه بابت معامله';
  }
  @override
  void dispose() { _quantity.dispose(); _reason.dispose(); _purity.dispose(); _weight.dispose(); super.dispose(); }

  ZarAssetAmount template() {
    if (widget.initialAsset != null) return widget.initialAsset!;
    switch (_type) {
      case 'gold': return ZarGoldAssetAmount(ZarGoldQuantity(decimal: '1', purity: normalizeGoldFineness(_purity.text)));
      case 'coin':
        final coin = _coin;
        if (coin == null) throw const FormatException('نوع سکه را انتخاب کنید.');
        return ZarCoinBundleAmount([ZarCoinLine(id: _id, coinTypeId: coin.id,
          coinTypeNameSnapshot: coin.name, quantity: 1,
          weightPerPieceGrams: coin.category == ZarCoinCategory.parsian ? normalizeDecimal(_weight.text) : coin.defaultWeightGrams,
          fineness: coin.category == ZarCoinCategory.parsian ? normalizeGoldFineness(_purity.text) : coin.defaultFineness)]);
      default: return ZarCurrencyAssetAmount(ZarCurrencyAmount(code: _type == 'cash' ? 'TOMAN' : _currency, minorUnits: 1, minorUnitScale: _type == 'cash' ? 0 : 2));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(top: false, child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85 - MediaQuery.viewInsetsOf(context).bottom * .15),
      child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
          if (widget.initialAsset != null) Text(assetLabel(widget.initialAsset!))
          else ...[
            DropdownButtonFormField<String>(initialValue: _type, decoration: const InputDecoration(labelText: 'نوع دارایی'),
              items: const [DropdownMenuItem(value: 'cash', child: Text('وجه نقد')), DropdownMenuItem(value: 'gold', child: Text('طلا')),
                DropdownMenuItem(value: 'coin', child: Text('سکه')), DropdownMenuItem(value: 'currency', child: Text('ارز'))],
              onChanged: _saving ? null : (v) => setState(() => _type = v!)),
            if (_type == 'currency') DropdownButtonFormField<String>(initialValue: _currency,
              items: {...widget.store.currencyTypes.where((c) => !c.archived).map((c) => c.code), 'USD'}.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: _saving ? null : (v) => setState(() => _currency = v!)),
            if (_type == 'coin') DropdownButtonFormField<ZarCoinType>(initialValue: _coin,
              items: widget.store.coinTypes.where((c) => !c.archived).map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
              onChanged: _saving ? null : (v) => setState(() => _coin = v)),
            if (_type == 'gold' || (_type == 'coin' && _coin?.category == ZarCoinCategory.parsian))
              TextField(controller: _purity, enabled: !_saving, decoration: const InputDecoration(labelText: 'عیار'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: const [PersianNumericInputFormatter(group: false)]),
            if (_type == 'coin' && _coin?.category == ZarCoinCategory.parsian)
              TextField(controller: _weight, enabled: !_saving, decoration: const InputDecoration(labelText: 'وزن هر سکه (گرم)'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: const [PersianNumericInputFormatter(group: false)]),
          ],
          const SizedBox(height: 12),
          if (customer) DropdownButtonFormField<String>(initialValue: _person,
            decoration: const InputDecoration(labelText: 'طرف حساب'),
            items: widget.store.domainPeople.where((p) => !p.archived || p.id == _person).map((p) => DropdownMenuItem(value: p.id, child: Text(p.displayName))).toList(),
            onChanged: _saving || widget.financialDeal != null ? null : (v) => setState(() => _person = v)),
          if (widget.maximum != null) Text('حداکثر باقی‌مانده: ${number(widget.maximum!)}'),
          if (widget.expected != null) Text('مانده محاسباتی: ${number(widget.expected!)}'),
          TextField(key: const ValueKey('cash-quantity'), controller: _quantity, enabled: !_saving && widget.reversal == null,
            decoration: InputDecoration(labelText: widget.operation == 'count' ? 'مقدار شمارش‌شده' : 'مقدار / مبلغ'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [PersianNumericInputFormatter()], textInputAction: TextInputAction.next),
          const SizedBox(height: 12),
          TextField(key: const ValueKey('cash-reason'), controller: _reason, enabled: !_saving,
            decoration: const InputDecoration(labelText: 'شرح / دلیل'), maxLines: 2),
          if (customer && widget.financialDeal == null) SwitchListTile(contentPadding: EdgeInsets.zero,
            title: const Text('برای آینده (هنوز انجام نشده)'), value: _future,
            onChanged: _saving ? null : (v) => setState(() { _future = v; _at = DateTime.now(); })),
          if (_future) TextButton(onPressed: _saving ? null : _pickDate,
            child: Text('سررسید: ${formatJalaliDate(Jalali.fromDateTime(_at))} ${toPersianDigits(_at.hour.toString().padLeft(2, '0'))}:${toPersianDigits(_at.minute.toString().padLeft(2, '0'))}')),
          if (widget.operation == 'opening') const Text('از زمان این ثبت، گردش‌های قبل از آن در مانده این دارایی منظور نمی‌شوند؛ سوابق حفظ می‌شوند. برای مانده صفر نیازی به ثبت آغازین نیست.'),
          if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          FilledButton(key: const ValueKey('cash-save'), onPressed: _saving ? null : _save,
            child: Text(_saving ? 'در حال ثبت…' : 'ثبت و تأیید')),
        ],
      )),
    )),
  );

  Future<void> _pickDate() async {
    final day = await pickJalaliDate(context, Jalali.fromDateTime(_at));
    if (day == null || !mounted) return;
    final time = await pickCupertinoTime(context, TimeOfDay.fromDateTime(_at));
    final g = day.toGregorian();
    if (time != null && mounted) setState(() => _at = DateTime(g.year, g.month, g.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      if (_pendingEntry != null || _pendingSettlement != null) {
        await _persistPending();
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final raw = normalizeDecimal(_quantity.text);
      final base = template();
      if (customer && _person == null) throw const FormatException('طرف حساب را انتخاب کنید.');
      if (_reason.text.trim().isEmpty) throw const FormatException('شرح یا دلیل را وارد کنید.');
      if (_future && !_at.isAfter(DateTime.now())) throw const FormatException('سررسید باید در آینده باشد.');
      var quantity = raw;
      var direction = widget.operation == 'pay' || widget.operation == 'withdrawal' || widget.operation == 'expense'
        ? ZarSettlementDirection.deliver : ZarSettlementDirection.receive;
      String? expected;
      if (widget.operation == 'count') {
        final current = const ZarCashProjector().project(entries: widget.store.cashEntries,
          settlements: widget.store.settlements, allocations: widget.store.paymentAllocations);
        final key = cashQuantities(base).keys.single;
        expected = current.balances.where((b) => b.key == key).firstOrNull?.quantity ?? '0';
        final delta = cashAdd(raw, expected, sign: -1);
        if (delta == '0') {
          if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شمارش با مانده صندوق برابر است؛ اختلافی وجود ندارد.'))); Navigator.pop(context, true); }
          return;
        }
        direction = delta.startsWith('-') ? ZarSettlementDirection.deliver : ZarSettlementDirection.receive;
        quantity = delta.replaceFirst('-', '');
      }
      if (widget.deliveryDeal != null) {
        final deal = widget.deliveryDeal!;
        final key = cashQuantities(base).keys.single;
        final delivered = cashDeliveredForDeal(deal, widget.store.cashEntries, widget.store.settlements)[key] ?? '0';
        final remaining = cashAdd(cashQuantities(deal.amount)[key]!, delivered, sign: -1);
        if (cashCompare(quantity, remaining) > 0) throw const FormatException('مقدار از باقی‌مانده معامله بیشتر است.');
        direction = deal.type == ZarDealType.buy ? ZarSettlementDirection.receive : ZarSettlementDirection.deliver;
      }
      if (widget.reversal != null) direction = widget.reversal!.direction == ZarSettlementDirection.receive ? ZarSettlementDirection.deliver : ZarSettlementDirection.receive;
      final amount = cashWithQuantity(base, quantity);
      final now = DateTime.now().toUtc();
      if (customer) {
        if (widget.financialDeal != null) {
          final d = widget.financialDeal!;
          final linked = widget.store.settlements.where((s) => s.dealId == d.id && s.status == ZarSettlementStatus.completed && s.direction == direction);
          var paid = BigInt.zero;
          final assignedSources = widget.store.paymentAllocations.map((r) => r.settlementId).toSet();
          for (final s in linked) { if (!assignedSources.contains(s.id)) paid += zarWholeToman(s.amount) ?? BigInt.zero; }
          for (final r in widget.store.paymentAllocations.where((r) => r.targetType == ZarPaymentAllocationTarget.deal && r.targetId == d.id)) {
            if (widget.store.settlementById(r.settlementId)?.status == ZarSettlementStatus.completed) paid += BigInt.from(r.amount.wholeTomans);
          }
          final remaining = BigInt.from(d.pricing!.totalToman.wholeTomans) - paid;
          if (zarWholeToman(amount)! > remaining) throw const FormatException('مبلغ از باقی‌مانده تسویه معامله بیشتر است؛ پیش‌پرداخت را به صورت دریافت/پرداخت آزاد ثبت کنید.');
        }
        _pendingSettlement = ZarSettlement(id: _id, businessId: widget.financialDeal?.businessId ?? widget.businessId,
          personId: _person!, dealId: widget.financialDeal?.id, direction: direction, amount: amount,
          scheduledAt: _future ? _at.toUtc() : now, hasTime: true,
          status: _future ? ZarSettlementStatus.open : ZarSettlementStatus.completed,
          completedAt: _future ? null : now, completedBy: _future ? null : 'local-user',
          note: _reason.text.trim(), createdBy: 'local-user', createdAt: now, updatedAt: now);
      } else {
        final kind = switch (widget.operation) {
          'opening' => ZarCashEntryKind.opening, 'count' => ZarCashEntryKind.adjustment,
          'delivery' => ZarCashEntryKind.delivery, 'reversal' => ZarCashEntryKind.reversal,
          'withdrawal' => ZarCashEntryKind.withdrawal, 'expense' => ZarCashEntryKind.expense,
          _ => ZarCashEntryKind.contribution,
        };
        _pendingEntry = ZarCashEntry(id: _id,
          businessId: widget.deliveryDeal?.businessId ?? widget.reversal?.businessId ?? widget.businessId,
          kind: kind, direction: direction, amount: amount, occurredAt: now, note: _reason.text.trim(),
          dealId: widget.deliveryDeal?.id, reversesId: widget.reversal?.id,
          countedQuantity: expected == null ? null : raw, expectedQuantity: expected);
      }
      await _persistPending();
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (e) {
      _pendingEntry = null; _pendingSettlement = null;
      if (mounted) setState(() => _error = 'ثبت انجام نشد: ${e.message}');
    } catch (_) {
      if (mounted) setState(() => _error = 'تأیید ثبت دریافت نشد؛ تلاش دوباره همان سند را ارسال می‌کند.');
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _persistPending() async {
    if (_pendingEntry != null) await widget.store.appendCashEntry(_pendingEntry!);
    if (_pendingSettlement != null) await widget.store.saveCashSettlement(_pendingSettlement!);
  }
}
