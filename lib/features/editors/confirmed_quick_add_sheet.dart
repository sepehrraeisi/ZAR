import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';

import '../../app_core.dart';
import '../../domain/zar_domain_models.dart';

class ConfirmedQuickAddSheet extends StatefulWidget {
  const ConfirmedQuickAddSheet({
    super.key,
    required this.people,
    required this.onSave,
    this.coinTypes = const [],
    this.initialReminder = '۱۵ دقیقه',
  });
  final List<AppPerson> people;
  final Future<void> Function(QuickAddDraft draft) onSave;
  final List<ZarCoinType> coinTypes;
  final String initialReminder;
  @override
  State<ConfirmedQuickAddSheet> createState() => _ConfirmedQuickAddSheetState();
}

class _ConfirmedQuickAddSheetState extends State<ConfirmedQuickAddSheet> {
  String? _operation, _asset, _currencyCode;
  AppPerson? _person;
  final _amount = TextEditingController();
  final _fineness = TextEditingController(text: '750');
  final _reference = TextEditingController(text: '750');
  final _rate = TextEditingController();
  final _note = TextEditingController();
  ZarGoldUnit _weightUnit = ZarGoldUnit.gram;
  ZarGoldUnit _priceUnit = ZarGoldUnit.gram;
  bool _more = false,
      _settlementValue = false,
      _saving = false,
      _submitted = false;
  Jalali _date = Jalali.now();
  TimeOfDay? _time;
  late String _reminder = widget.initialReminder;
  String? _error;
  final List<_CoinDraftRow> _coinRows = [];

  bool get _isSettlement => _operation == 'دریافت' || _operation == 'تحویل';
  bool get _isGold => _asset == 'طلا';
  bool get _isCash => _asset == 'وجه نقد';
  bool get _isCurrency => _asset == 'ارز' || _isCash;
  bool get _isCoin => _asset == 'سکه';
  bool get _needsPricing => !_isSettlement || _settlementValue;

  @override
  void dispose() {
    for (final controller in [_amount, _fineness, _reference, _rate, _note]) {
      controller.dispose();
    }
    for (final row in _coinRows) {
      row.dispose();
    }
    super.dispose();
  }

  String? _required(String value) =>
      _submitted && value.trim().isEmpty ? 'این فیلد الزامی است.' : null;

  ZarDealPricing? _pricing() {
    if (!_needsPricing ||
        _isCash ||
        _amount.text.trim().isEmpty ||
        _rate.text.trim().isEmpty) {
      return null;
    }
    try {
      if (_isGold) {
        return ZarGoldDealPricing.calculate(
          fineness: _fineness.text,
          priceReferenceFineness: _reference.text,
          inputWeight: _amount.text,
          inputWeightUnit: _weightUnit,
          priceUnit: _priceUnit,
          pricePerUnitToman: ZarTomanAmount(
            int.parse(normalizeDecimal(_rate.text)),
          ),
        );
      }
      return ZarCurrencyDealPricing.calculate(
        amount: _amount.text,
        tomanPerUnit: _rate.text,
      );
    } on FormatException {
      return null;
    }
  }

  bool get _ready =>
      _operation != null &&
      _asset != null &&
      _person != null &&
      (_isCoin ? _coinData() != null : _amount.text.trim().isNotEmpty) &&
      (!_isGold || _fineness.text.trim().isNotEmpty) &&
      (_asset != 'ارز' || _currencyCode != null) &&
      (!_needsPricing || _isCash || _isCoin || _pricing() != null);

  void _selectOperation(String value) => setState(() {
    _operation = value;
    if (!_isSettlement && _isCash) _asset = null;
  });
  void _selectAsset(String value) => setState(() {
    _asset = value;
    _currencyCode = value == 'ارز'
        ? (_currencyCode ?? 'USD')
        : value == 'وجه نقد'
        ? 'TOMAN'
        : null;
    if (value == 'سکه' && _coinRows.isEmpty && widget.coinTypes.isNotEmpty) {
      _coinRows.add(_CoinDraftRow(widget.coinTypes.first));
    }
  });

  ({
    List<ZarCoinLine> lines,
    ZarCoinDealPricing? dealPricing,
    ZarCoinSettlementValuation? settlementValuation,
  })?
  _coinData() {
    if (!_isCoin || _coinRows.isEmpty) return null;
    try {
      final lines = <ZarCoinLine>[];
      final prices = <ZarCoinLinePricing>[];
      for (final row in _coinRows) {
        final type = row.type;
        if (type == null) return null;
        final line = ZarCoinLine(
          id: row.id,
          coinTypeId: type.id,
          coinTypeNameSnapshot: type.name,
          quantity: int.parse(normalizeDecimal(row.quantity.text)),
          weightPerPieceGrams: row.weight.text.trim().isEmpty
              ? type.defaultWeightGrams
              : row.weight.text,
          fineness: row.fineness.text.trim().isEmpty
              ? type.defaultFineness
              : row.fineness.text,
        );
        lines.add(line);
        if (_needsPricing) {
          prices.add(
            ZarCoinLinePricing.calculate(
              line: line,
              method: row.method,
              unitPriceToman: ZarTomanAmount(
                int.parse(normalizeDecimal(row.price.text)),
              ),
              priceReferenceFineness: row.reference.text,
            ),
          );
        }
      }
      return (
        lines: lines,
        dealPricing: !_isSettlement ? ZarCoinDealPricing(lines: prices) : null,
        settlementValuation: _isSettlement && _settlementValue
            ? ZarCoinSettlementValuation(lines: prices)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  void _selectPriceUnit(ZarGoldUnit value) => setState(() {
    _priceUnit = value;
    _reference.text = value == ZarGoldUnit.gram ? '750' : '705';
  });

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_ready || _saving) return;
    final pricing = _pricing();
    final coinData = _coinData();
    final draft = QuickAddDraft(
      operation: _operation!,
      asset: _asset!,
      personId: _person!.id,
      amount: _amount.text.trim(),
      date: _date,
      time: _time,
      reminder: _isSettlement ? _reminder : '',
      note: _note.text.trim(),
      currencyCode: _isCurrency ? (_currencyCode ?? 'TOMAN') : null,
      goldFineness: _isGold ? normalizeGoldFineness(_fineness.text) : null,
      goldPriceReferenceFineness: _isGold && pricing != null
          ? normalizeGoldFineness(_reference.text)
          : null,
      goldInputUnit: _isGold ? _weightUnit.name : null,
      goldPriceUnit: _isGold && pricing != null ? _priceUnit.name : null,
      tomanRate: pricing is ZarGoldDealPricing
          ? pricing.pricePerUnitToman.wholeTomans.toString()
          : pricing is ZarCurrencyDealPricing
          ? pricing.tomanPerUnit
          : null,
      totalToman: pricing?.totalToman.wholeTomans.toString(),
      coinLines: coinData?.lines ?? const [],
      coinDealPricing: coinData?.dealPricing,
      coinSettlementValuation: coinData?.settlementValuation,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_submitLabel),
        content: Text(
          _isCoin ? _coinConfirmation(coinData!) : _confirmation(pricing),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('بازبینی'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأیید و ثبت'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(draft);
      if (mounted) Navigator.pop(context, draft);
    } on FormatException {
      if (mounted) setState(() => _error = 'مقادیر واردشده معتبر نیستند.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'اطلاعات ثبت نشد. دوباره تلاش کنید.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _submitLabel => 'ثبت ${_operation ?? ''} ${_asset ?? ''}'.trim();
  String _toman(int value) =>
      toPersianDigits(NumberFormat.decimalPattern('en_US').format(value));
  String _confirmation(ZarDealPricing? pricing) {
    final unit = _isGold
        ? (_weightUnit == ZarGoldUnit.gram ? 'گرم' : 'مثقال')
        : (_currencyCode == 'TOMAN' ? 'تومان' : _currencyCode ?? '');
    return '${_person!.name}\n${toPersianDigits(normalizeDecimal(_amount.text))} $unit'
        '${pricing == null ? '' : '\nمبلغ کل: ${_toman(pricing.totalToman.wholeTomans)} تومان'}';
  }

  String _coinConfirmation(
    ({
      List<ZarCoinLine> lines,
      ZarCoinDealPricing? dealPricing,
      ZarCoinSettlementValuation? settlementValuation,
    })
    data,
  ) {
    final lines = data.lines
        .map(
          (line) =>
              '${toPersianDigits(line.quantity.toString())} × ${line.coinTypeNameSnapshot}',
        )
        .join('\n');
    final total =
        data.dealPricing?.totalToman ?? data.settlementValuation?.totalToman;
    return '${_person!.name}\n$lines${total == null ? '' : '\nجمع کل: ${_toman(total.wholeTomans)} تومان'}';
  }

  String? _summary() {
    final pricing = _pricing();
    if (pricing == null) return null;
    if (pricing is ZarCurrencyDealPricing) {
      return 'مبلغ کل: ${_toman(pricing.totalToman.wholeTomans)} تومان';
    }
    final gold = pricing as ZarGoldDealPricing;
    final other = gold.inputWeightUnit == ZarGoldUnit.gram
        ? gold.equivalentWeightMesghal
        : gold.normalizedWeightGrams;
    return '${toPersianDigits(gold.inputWeight)} ${gold.inputWeightUnit == ZarGoldUnit.gram ? 'گرم' : 'مثقال'} = '
        '${toPersianDigits(other)} ${gold.inputWeightUnit == ZarGoldUnit.gram ? 'مثقال' : 'گرم'}\n'
        'مقدار تعدیل‌شده: ${toPersianDigits(gold.equivalentQuantityInPriceUnit)} ${gold.priceUnit == ZarGoldUnit.gram ? 'گرم' : 'مثقال'}\n'
        'مبلغ کل: ${_toman(gold.totalToman.wholeTomans)} تومان';
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('ثبت سریع', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _label('نوع عملیات'),
            _choices(
              ['خرید', 'فروش', 'دریافت', 'تحویل'],
              _operation,
              _selectOperation,
            ),
            if (_operation != null) ...[
              const SizedBox(height: 14),
              _label('موضوع'),
              _choices(
                _isSettlement
                    ? ['طلا', 'سکه', 'ارز', 'وجه نقد']
                    : ['طلا', 'سکه', 'ارز'],
                _asset,
                _selectAsset,
              ),
            ],
            if (_asset != null) ...[
              const SizedBox(height: 12),
              _card([
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('شخص'),
                  subtitle: Text(_person?.name ?? 'انتخاب شخص'),
                  trailing: const Icon(CupertinoIcons.chevron_down),
                  onTap: () async {
                    final selected = await showPersonPickerBottomSheet(
                      context,
                      widget.people,
                    );
                    if (mounted && selected != null) {
                      setState(() => _person = selected);
                    }
                  },
                ),
                if (_submitted && _person == null)
                  _fieldError('انتخاب شخص الزامی است.'),
                if (_asset == 'ارز')
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('نوع ارز'),
                    subtitle: Text(
                      currencyByCode(_currencyCode)?.displayLabel ??
                          'انتخاب نوع ارز',
                    ),
                    trailing: const Icon(CupertinoIcons.chevron_down),
                    onTap: () async {
                      final selected = await showCurrencyPickerBottomSheet(
                        context,
                        _currencyCode,
                      );
                      if (mounted && selected != null) {
                        setState(() => _currencyCode = selected.code);
                      }
                    },
                  ),
                if (_isCoin)
                  _coinEditor()
                else
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: _isGold ? 'وزن' : 'مقدار',
                      errorText: _required(_amount.text),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                if (_isGold && !_isCoin) ...[
                  const SizedBox(height: 12),
                  _label('واحد وزن'),
                  _units(
                    _weightUnit,
                    (v) => setState(() => _weightUnit = v),
                    false,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fineness,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: 'عیار واقعی',
                      errorText: _required(_fineness.text),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  _choices(
                    ['705', '740', '750', '875', '916', '999.9'],
                    _fineness.text,
                    (v) => setState(() => _fineness.text = v),
                  ),
                ],
              ]),
              if (_isSettlement && !_isCash)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('محاسبه ارزش مالی'),
                  subtitle: const Text('اختیاری؛ فقط برای محاسبه همین ثبت'),
                  value: _settlementValue,
                  onChanged: (v) => setState(() => _settlementValue = v),
                ),
              if (_needsPricing && !_isCash && !_isCoin) ...[
                const SizedBox(height: 10),
                _card([
                  if (_isGold) ...[
                    _label('واحد قیمت'),
                    _units(_priceUnit, _selectPriceUnit, true),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: _isGold
                          ? 'قیمت هر ${_priceUnit == ZarGoldUnit.gram ? 'گرم' : 'مثقال'} (تومان)'
                          : 'نرخ هر واحد ارز (تومان)',
                      errorText: _required(_rate.text),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_isGold) ...[
                    TextButton(
                      onPressed: () => setState(() => _more = !_more),
                      child: Text(
                        _more ? 'بستن گزینه‌های بیشتر' : 'گزینه‌های بیشتر',
                      ),
                    ),
                    if (_more)
                      TextField(
                        controller: _reference,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          labelText: 'عیار مرجع قیمت',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                  ],
                  if (_summary() case final summary?) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9A6700).withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        summary,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.7,
                        ),
                      ),
                    ),
                  ],
                ]),
              ],
              const SizedBox(height: 10),
              _card([
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاریخ'),
                  subtitle: Text(formatJalaliDate(_date)),
                  trailing: const Icon(CupertinoIcons.calendar),
                  onTap: () async {
                    final value = await pickJalaliDate(context, _date);
                    if (mounted && value != null) setState(() => _date = value);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ساعت'),
                  subtitle: Text(
                    _time == null
                        ? 'بدون ساعت'
                        : '${toPersianDigits(_time!.hour.toString().padLeft(2, '0'))}:${toPersianDigits(_time!.minute.toString().padLeft(2, '0'))}',
                  ),
                  trailing: const Icon(CupertinoIcons.time),
                  onTap: () async {
                    final value = await pickCupertinoTime(context, _time);
                    if (mounted && value != null) setState(() => _time = value);
                  },
                ),
                if (_isSettlement)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('یادآوری'),
                    subtitle: Text(_reminder),
                    trailing: const Icon(CupertinoIcons.bell),
                    onTap: () async {
                      final value = await showReminderTextPickerBottomSheet(
                        context,
                        _reminder,
                      );
                      if (mounted && value != null) {
                        setState(() => _reminder = value);
                      }
                    },
                  ),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'توضیحات (اختیاری)',
                  ),
                ),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 10),
                _fieldError(_error!),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CupertinoActivityIndicator()
                      : Text(_submitLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
  Widget _choices(
    List<String> values,
    String? selected,
    ValueChanged<String> changed,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: values
        .map(
          (v) => ChoiceChip(
            label: Text(toPersianDigits(v)),
            selected: selected == v,
            showCheckmark: false,
            onSelected: _saving ? null : (_) => changed(v),
          ),
        )
        .toList(),
  );
  Widget _units(
    ZarGoldUnit selected,
    ValueChanged<ZarGoldUnit> changed,
    bool price,
  ) => Wrap(
    spacing: 8,
    children: [ZarGoldUnit.gram, ZarGoldUnit.mesghal]
        .map(
          (v) => ChoiceChip(
            label: Text(
              price
                  ? (v == ZarGoldUnit.gram ? 'تومان/گرم' : 'تومان/مثقال')
                  : (v == ZarGoldUnit.gram ? 'گرم' : 'مثقال'),
            ),
            selected: selected == v,
            showCheckmark: false,
            onSelected: (_) => changed(v),
          ),
        )
        .toList(),
  );

  Widget _coinEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (index, row) in _coinRows.indexed) ...[
        if (index > 0) const Divider(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'ردیف ${toPersianDigits((index + 1).toString())}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_coinRows.length > 1)
              IconButton(
                onPressed: () => setState(() {
                  _coinRows.removeAt(index).dispose();
                }),
                icon: const Icon(CupertinoIcons.delete),
              ),
          ],
        ),
        DropdownButtonFormField<ZarCoinType>(
          initialValue: row.type,
          decoration: const InputDecoration(labelText: 'نوع سکه'),
          items: widget.coinTypes
              .where((item) => !item.archived || item.id == row.type?.id)
              .map(
                (item) => DropdownMenuItem(value: item, child: Text(item.name)),
              )
              .toList(),
          onChanged: (value) => setState(() => row.selectType(value)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: row.quantity,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: 'تعداد',
            errorText: _submitted && row.quantity.text.trim().isEmpty
                ? 'تعداد الزامی است.'
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (row.weighted) ...[
          const SizedBox(height: 10),
          TextField(
            controller: row.weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'وزن هر سکه (گرم)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: row.fineness,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'عیار'),
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (_needsPricing) ...[
          const SizedBox(height: 10),
          _choices(
            row.weighted ? ['هر قطعه', 'هر گرم'] : ['هر قطعه'],
            row.method == ZarCoinPricingMethod.perPiece ? 'هر قطعه' : 'هر گرم',
            (value) => setState(
              () => row.method = value == 'هر قطعه'
                  ? ZarCoinPricingMethod.perPiece
                  : ZarCoinPricingMethod.perGram,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: row.price,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: row.method == ZarCoinPricingMethod.perPiece
                  ? 'قیمت هر قطعه (تومان)'
                  : 'قیمت هر گرم (تومان)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (row.method == ZarCoinPricingMethod.perGram) ...[
            TextButton(
              onPressed: () => setState(() => row.more = !row.more),
              child: Text(row.more ? 'بستن جزئیات بیشتر' : 'جزئیات بیشتر'),
            ),
            if (row.more)
              TextField(
                controller: row.reference,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'عیار مرجع قیمت'),
                onChanged: (_) => setState(() {}),
              ),
          ],
          if (_coinRowTotal(row) case final total?)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'جمع ردیف: ${_toman(total)} تومان',
                style: const TextStyle(
                  color: Color(0xFF9A6700),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ],
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: widget.coinTypes.where((e) => !e.archived).isEmpty
            ? null
            : () => setState(
                () => _coinRows.add(
                  _CoinDraftRow(
                    widget.coinTypes.firstWhere((e) => !e.archived),
                  ),
                ),
              ),
        icon: const Icon(CupertinoIcons.add),
        label: const Text('افزودن سکه دیگر'),
      ),
      if (_coinTotal() case final total?)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF9A6700).withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'جمع کل معامله: ${_toman(total)} تومان',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
    ],
  );

  int? _coinRowTotal(_CoinDraftRow row) {
    try {
      final data = _coinData();
      final pricing =
          data?.dealPricing?.lines ?? data?.settlementValuation?.lines;
      if (pricing == null) return null;
      for (final item in pricing) {
        if (item.lineId == row.id) return item.rowTotalToman.wholeTomans;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  int? _coinTotal() =>
      _coinData()?.dealPricing?.totalToman.wholeTomans ??
      _coinData()?.settlementValuation?.totalToman.wholeTomans;
  Widget _card(List<Widget> children) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
  Widget _fieldError(String text) => Text(
    text,
    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
  );
}

class _CoinDraftRow {
  _CoinDraftRow(ZarCoinType type)
    : id = 'coin-line-${DateTime.now().microsecondsSinceEpoch}',
      type = type,
      method = type.defaultPricingMethod,
      weight = TextEditingController(text: type.defaultWeightGrams ?? ''),
      fineness = TextEditingController(text: type.defaultFineness ?? '750');
  final String id;
  ZarCoinType? type;
  ZarCoinPricingMethod method;
  bool more = false;
  final quantity = TextEditingController(text: '1');
  final TextEditingController weight;
  final TextEditingController fineness;
  final price = TextEditingController();
  final reference = TextEditingController(text: '750');
  bool get weighted =>
      type?.category == ZarCoinCategory.parsian ||
      method == ZarCoinPricingMethod.perGram;
  void selectType(ZarCoinType? value) {
    type = value;
    if (value == null) return;
    method = value.defaultPricingMethod;
    weight.text = value.defaultWeightGrams ?? '';
    fineness.text = value.defaultFineness ?? '750';
  }

  void dispose() {
    quantity.dispose();
    weight.dispose();
    fineness.dispose();
    price.dispose();
    reference.dispose();
  }
}
