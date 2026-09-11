import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';

import '../../app_core.dart';
import 'persian_numeric_input_formatter.dart';
import '../../domain/zar_domain_models.dart';
import 'quick_entry_preferences.dart';

class ConfirmedQuickAddSheet extends StatefulWidget {
  const ConfirmedQuickAddSheet({
    super.key,
    required this.people,
    required this.onSave,
    this.coinTypes = const [],
    this.initialReminder = '۱۵ دقیقه',
    this.recentPeople = const [],
    this.preferenceStore,
    this.initialOperation,
    this.initialAsset,
    this.initialCurrencyCode,
    this.initialGoldFineness,
    this.initialCoinTypeId,
    this.initialPersonId,
  });
  final List<AppPerson> people;
  final Future<void> Function(QuickAddDraft draft) onSave;
  final List<ZarCoinType> coinTypes;
  final String initialReminder;
  final List<AppPerson> recentPeople;
  final QuickEntryPreferenceStore? preferenceStore;
  final String? initialOperation;
  final String? initialAsset;
  final String? initialCurrencyCode;
  final String? initialGoldFineness;
  final String? initialCoinTypeId;
  final String? initialPersonId;
  @override
  State<ConfirmedQuickAddSheet> createState() => _ConfirmedQuickAddSheetState();
}

class _ConfirmedQuickAddSheetState extends State<ConfirmedQuickAddSheet> {
  String? _operation, _asset, _currencyCode;
  AppPerson? _person;
  final _amount = TextEditingController();
  final _fineness = TextEditingController(text: '۷۵۰');
  final _reference = TextEditingController(text: '۷۵۰');
  final _rate = TextEditingController();
  final _note = TextEditingController();
  ZarGoldUnit _weightUnit = ZarGoldUnit.gram;
  ZarGoldUnit _priceUnit = ZarGoldUnit.gram;
  bool _more = false,
      _settlementValue = false,
      _saving = false,
      _submitted = false,
      _selectionExpanded = true,
      _metadataExpanded = false,
      _notesExpanded = false,
      _customPurity = false,
      _startedInput = false;
  late Jalali _date;
  TimeOfDay? _time;
  DateTime? _customReminderAt;
  late String _reminder = widget.initialReminder;
  String? _error;
  final List<_CoinDraftRow> _coinRows = [];
  late final QuickEntryPreferenceStore _preferenceStore;
  String? _preferredCoinTypeId;
  final _amountFocus = FocusNode();
  final _rateFocus = FocusNode();

  bool get _isSettlement => _operation == 'دریافت' || _operation == 'تحویل';
  bool get _isGold => _asset == 'طلا';
  bool get _isCash => _asset == 'وجه نقد';
  bool get _isCurrency => _asset == 'ارز' || _isCash;
  bool get _isCoin => _asset == 'سکه';
  bool get _needsPricing => !_isSettlement || _settlementValue;

  String get _operationDisplay =>
      _operation == 'تحویل' ? 'پرداخت' : _operation ?? '';
  String get _effectiveReminder {
    if (_reminder == 'بدون یادآوری') return '';
    if (_customReminderAt != null) return 'سفارشی';
    return _time == null ? '' : _reminder;
  }

  @override
  void initState() {
    super.initState();
    // A transaction always starts with the local registration timestamp.
    // Reminder scheduling remains independent and may still be disabled.
    final now = DateTime.now();
    _date = Jalali.fromDateTime(now);
    _time = TimeOfDay.fromDateTime(now);
    _operation = widget.initialOperation;
    _asset = widget.initialAsset;
    _selectionExpanded = widget.initialAsset == null;
    _currencyCode = widget.initialCurrencyCode;
    if (widget.initialPersonId != null) {
      final selected = widget.people.where(
        (item) => item.id == widget.initialPersonId,
      );
      if (selected.isNotEmpty) _person = selected.first;
    }
    if (widget.initialAsset == 'طلا') {
      _fineness.text = widget.initialGoldFineness ?? '';
    }
    _preferenceStore =
        widget.preferenceStore ?? SharedPreferencesQuickEntryPreferenceStore();
    if (widget.initialAsset == 'سکه' && widget.coinTypes.isNotEmpty) {
      final selected = widget.coinTypes.where(
        (item) => item.id == widget.initialCoinTypeId,
      );
      _coinRows.add(
        _CoinDraftRow(
          selected.isEmpty ? widget.coinTypes.first : selected.first,
        ),
      );
    }
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await _preferenceStore.load();
      if (!mounted || _startedInput) return;
      setState(() {
        if (widget.initialAsset == null) {
          _weightUnit = preferences.weightUnit;
          _priceUnit = preferences.priceUnit;
        }
        if (widget.initialAsset != 'طلا') {
          _fineness.text = toPersianNumberText(preferences.goldPurity);
        }
        _reference.text = preferences.priceUnit == ZarGoldUnit.gram
            ? '۷۵۰'
            : '۷۰۵';
        if (widget.initialCurrencyCode == null) {
          _currencyCode = preferences.currencyCode;
        }
        _preferredCoinTypeId = preferences.coinTypeId;
        if (widget.initialAsset == 'سکه' &&
            widget.initialCoinTypeId == null &&
            _coinRows.isEmpty &&
            widget.coinTypes.isNotEmpty) {
          final preferred = widget.coinTypes.where(
            (item) => item.id == preferences.coinTypeId,
          );
          _coinRows.add(
            _CoinDraftRow(
              preferred.isEmpty ? widget.coinTypes.first : preferred.first,
            ),
          );
        }
      });
    } catch (_) {
      // Preferences are a convenience only; Quick Entry must remain usable.
    }
  }

  @override
  void dispose() {
    for (final controller in [_amount, _fineness, _reference, _rate, _note]) {
      controller.dispose();
    }
    for (final row in _coinRows) {
      row.dispose();
    }
    _amountFocus.dispose();
    _rateFocus.dispose();
    super.dispose();
  }

  bool _positiveInteger(String value) {
    final normalized = normalizeDecimal(value);
    final parsed = int.tryParse(normalized);
    return parsed != null && parsed > 0;
  }

  String? _amountError() {
    if (!_submitted) return null;
    if (_amount.text.trim().isEmpty) {
      return _isCash ? 'مبلغ (تومان) الزامی است.' : 'مقدار الزامی است.';
    }
    if (_isCoin) {
      return null;
    }
    try {
      final value = ZarExactDecimal.parse(_amount.text);
      if (value.unscaled <= BigInt.zero) return 'مقدار باید بیشتر از صفر باشد.';
    } catch (_) {
      return 'مقدار واردشده معتبر نیست.';
    }
    return null;
  }

  String? _rateError() {
    if (!_submitted || !_needsPricing || _isCash || _isCoin) return null;
    if (_rate.text.trim().isEmpty) return 'قیمت الزامی است.';
    try {
      if (ZarExactDecimal.parse(_rate.text).unscaled <= BigInt.zero) {
        return 'قیمت باید بیشتر از صفر باشد.';
      }
    } catch (_) {
      return 'قیمت واردشده معتبر نیست.';
    }
    return null;
  }

  String? _finenessError(String value, {String label = 'عیار'}) {
    if (!_submitted) return null;
    if (value.trim().isEmpty) return '$label الزامی است.';
    try {
      normalizeGoldFineness(value);
    } catch (_) {
      return '$label باید بین ۱ تا ۱۰۰۰ باشد.';
    }
    return null;
  }

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

  bool _validate() {
    if (_operation == null || _asset == null || _person == null) return false;
    if (_isCoin) {
      if (_coinRows.isEmpty) return false;
      for (final row in _coinRows) {
        if (row.type == null || !_positiveInteger(row.quantity.text)) {
          return false;
        }
        if (_needsPricing &&
            (row.price.text.trim().isEmpty ||
                !_positiveInteger(row.price.text))) {
          return false;
        }
        if (row.method == ZarCoinPricingMethod.perGram &&
            row.weight.text.trim().isEmpty) {
          return false;
        }
      }
      return true;
    }
    if (_amountError() != null ||
        (_isGold && _finenessError(_fineness.text) != null) ||
        (_asset == 'ارز' && _currencyCode == null) ||
        _rateError() != null) {
      return false;
    }
    return !_needsPricing || _isCash || _pricing() != null;
  }

  bool get _ready => _validate();

  void _selectOperation(String value) => setState(() {
    _startedInput = true;
    _operation = value;
    if (!_isSettlement) {
      _settlementValue = false;
      _reminder = '';
    }
    if (!_isSettlement && _asset == 'وجه نقد') _asset = null;
  });

  void _selectAsset(String value) => setState(() {
    _startedInput = true;
    final assetChanged = _asset != value;
    _asset = value;
    _selectionExpanded = false;
    if (assetChanged) {
      _amount.clear();
      _rate.clear();
      _more = false;
      _customPurity = false;
      if (value != 'طلا') {
        _fineness.text = '۷۵۰';
        _reference.text = '۷۵۰';
        _weightUnit = ZarGoldUnit.gram;
        _priceUnit = ZarGoldUnit.gram;
      }
    }
    _currencyCode = value == 'ارز'
        ? (_currencyCode ?? 'USD')
        : value == 'وجه نقد'
        ? 'TOMAN'
        : null;
    if (value == 'سکه' && _coinRows.isEmpty && widget.coinTypes.isNotEmpty) {
      final preferredMatches = _preferredCoinTypeId == null
          ? const <ZarCoinType>[]
          : widget.coinTypes
                .where((item) => item.id == _preferredCoinTypeId)
                .toList(growable: false);
      final preferred = preferredMatches.isEmpty
          ? null
          : preferredMatches.first;
      _coinRows.add(_CoinDraftRow(preferred ?? widget.coinTypes.first));
    }
    if (value == 'وجه نقد') _settlementValue = false;
  });

  void _markStarted() {
    if (!_startedInput) setState(() => _startedInput = true);
  }

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
        if (type == null || !_positiveInteger(row.quantity.text)) return null;
        if (_needsPricing &&
            (row.price.text.trim().isEmpty ||
                !_positiveInteger(row.price.text))) {
          return null;
        }
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
    _startedInput = true;
    _priceUnit = value;
    _reference.text = value == ZarGoldUnit.gram ? '۷۵۰' : '۷۰۵';
  });

  bool get _hasMeaningfulInput =>
      _operation != null ||
      _asset != null ||
      _person != null ||
      _amount.text.trim().isNotEmpty ||
      _rate.text.trim().isNotEmpty ||
      _note.text.trim().isNotEmpty ||
      _coinRows.any(
        (row) => row.price.text.trim().isNotEmpty || row.quantity.text != '۱',
      ) ||
      (_operation != null && _effectiveReminder.isNotEmpty);

  Future<bool> _confirmDismiss() async {
    if (!_hasMeaningfulInput) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اطلاعات واردشده حذف شود؟'),
        content: const Text('اطلاعات ثبت‌نشده از بین می‌رود.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ادامه ویرایش'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف اطلاعات'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _savePreferences() async {
    try {
      await _preferenceStore.save(
        QuickEntryPreferences(
          weightUnit: _weightUnit,
          priceUnit: _priceUnit,
          goldPurity: normalizeGoldFineness(_fineness.text),
          currencyCode: _currencyCode ?? 'USD',
          coinTypeId: _coinRows.isEmpty
              ? _preferredCoinTypeId
              : _coinRows.first.type?.id,
        ),
      );
    } catch (_) {
      // A preference write must never turn a successful transaction into an error.
    }
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_ready || _saving) {
      _focusFirstInvalid();
      return;
    }
    final pricing = _pricing();
    final coinData = _coinData();
    final draft = QuickAddDraft(
      operation: _operation!,
      asset: _asset!,
      personId: _person!.id,
      amount: _amount.text.trim(),
      date: _date,
      time: _time,
      reminder: _isSettlement ? _effectiveReminder : '',
      customReminderAt: _isSettlement ? _customReminderAt : null,
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
      await _savePreferences();
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('$_submitLabel ثبت شد.')));
        Navigator.pop(context, draft);
      }
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

  void _focusFirstInvalid() {
    if (_person == null) return;
    if (!_isCoin && _amountError() != null) {
      _amountFocus.requestFocus();
      return;
    }
    if (!_isCoin && _rateError() != null) _rateFocus.requestFocus();
  }

  String get _submitLabel =>
      'ثبت ${_operation == 'تحویل' ? 'پرداخت' : _operation ?? ''} ${_asset ?? ''}'
          .trim();
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
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * .92;
    // WillPopScope also intercepts barrier/drag dismissal so a dirty draft is never lost.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _confirmDismiss,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHeader(),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _formContent(),
                  ),
                ),
                _stickySubmit(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetHeader() => Column(
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
      Row(
        children: [
          Expanded(
            child: Text(
              'ثبت سریع',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'بستن',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: _saving
                ? null
                : () async {
                    if (await _confirmDismiss() && mounted) {
                      Navigator.pop(context);
                    }
                  },
            icon: const Icon(CupertinoIcons.xmark),
          ),
        ],
      ),
    ],
  );

  Widget _formContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 4),
      _selectionBlock(),
      if (_asset != null) ...[
        const SizedBox(height: 10),
        _transactionFields(),
        if (_isSettlement && !_isCash)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('محاسبه ارزش مالی'),
            subtitle: const Text('اختیاری؛ فقط برای محاسبه همین ثبت'),
            value: _settlementValue,
            onChanged: (v) => setState(() {
              _startedInput = true;
              _settlementValue = v;
            }),
          ),
        if (_needsPricing && !_isCash && !_isCoin) ...[
          const SizedBox(height: 8),
          _pricingFields(),
        ],
        const SizedBox(height: 8),
        _metadataSection(),
        if (_error != null) ...[
          const SizedBox(height: 8),
          _fieldError(_error!),
        ],
      ],
    ],
  );

  Widget _selectionBlock() {
    if (_operation != null && _asset != null && !_selectionExpanded) {
      return Row(
        children: [
          Expanded(
            child: Text(
              '$_operationDisplay · $_asset',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectionExpanded = true),
            child: const Text('تغییر'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('نوع عملیات'),
        _choices(
          ['خرید', 'فروش', 'دریافت', 'تحویل'],
          _operation,
          _selectOperation,
        ),
        if (_operation != null) ...[
          const SizedBox(height: 10),
          _label('نوع دارایی'),
          _choices(
            _isSettlement
                ? ['طلا', 'سکه', 'ارز', 'وجه نقد']
                : ['طلا', 'سکه', 'ارز'],
            _asset,
            _selectAsset,
          ),
        ],
      ],
    );
  }

  Widget _transactionFields() => _card([
    ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('طرف حساب'),
      subtitle: Text(_person?.name ?? 'انتخاب طرف حساب'),
      trailing: const Icon(CupertinoIcons.chevron_down),
      onTap: () async {
        final selected = await showPersonPickerBottomSheet(
          context,
          widget.people,
          recentPeople: widget.recentPeople,
        );
        if (mounted && selected != null) {
          setState(() {
            _startedInput = true;
            _person = selected;
          });
        }
      },
    ),
    if (_submitted && _person == null)
      _fieldError('انتخاب طرف حساب الزامی است.'),
    if (_asset == 'ارز')
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('نوع ارز'),
        subtitle: Text(
          currencyByCode(_currencyCode)?.displayLabel ?? 'انتخاب نوع ارز',
        ),
        trailing: const Icon(CupertinoIcons.chevron_down),
        onTap: () async {
          final selected = await showCurrencyPickerBottomSheet(
            context,
            _currencyCode,
          );
          if (mounted && selected != null) {
            setState(() {
              _startedInput = true;
              _currencyCode = selected.code;
            });
          }
        },
      ),
    if (_isCoin)
      _coinEditor()
    else if (_isGold)
      _goldInputRow()
    else
      _amountField(),
    if (_isGold) _goldPurityPicker(),
  ]);

  Widget _amountField() => TextField(
    controller: _amount,
    focusNode: _amountFocus,
    inputFormatters: [
      PersianNumericInputFormatter(decimal: !_isCash, group: true),
    ],
    keyboardType: TextInputType.numberWithOptions(decimal: !_isCash),
    textInputAction: _needsPricing
        ? TextInputAction.next
        : TextInputAction.done,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.right,
    decoration: InputDecoration(
      labelText: _isCash ? 'مبلغ (تومان)' : 'مقدار',
      errorText: _amountError(),
    ),
    onChanged: (_) {
      _markStarted();
      setState(() {});
    },
    onSubmitted: (_) {
      if (_needsPricing) _rateFocus.requestFocus();
    },
  );

  Widget _goldInputRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextField(
          controller: _amount,
          focusNode: _amountFocus,
          inputFormatters: const [PersianNumericInputFormatter(group: false)],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: 'وزن',
            errorText: _amountError(),
          ),
          onChanged: (_) {
            _markStarted();
            setState(() {});
          },
          onSubmitted: (_) => _rateFocus.requestFocus(),
        ),
      ),
      const SizedBox(width: 8),
      _unitDropdown(
        _weightUnit,
        (v) => setState(() {
          _startedInput = true;
          _weightUnit = v;
        }),
        price: false,
      ),
    ],
  );

  Widget _unitDropdown(
    ZarGoldUnit selected,
    ValueChanged<ZarGoldUnit> changed, {
    required bool price,
  }) => SizedBox(
    width: 112,
    child: DropdownButtonFormField<ZarGoldUnit>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: price ? 'واحد قیمت' : 'واحد وزن'),
      items: [ZarGoldUnit.gram, ZarGoldUnit.mesghal]
          .map(
            (unit) => DropdownMenuItem(
              value: unit,
              child: Text(
                price
                    ? (unit == ZarGoldUnit.gram ? 'تومان/گرم' : 'تومان/مثقال')
                    : (unit == ZarGoldUnit.gram ? 'گرم' : 'مثقال'),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) changed(value);
      },
    ),
  );

  Widget _goldPurityPicker() => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('عیار واقعی'),
        _choices(
          ['705', '740', '750', '875', '916', '999.9'],
          _customPurity ? null : _fineness.text,
          (value) => setState(() {
            _startedInput = true;
            _customPurity = false;
            _fineness.text = toPersianNumberText(value);
          }),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => setState(() {
            _startedInput = true;
            _customPurity = true;
          }),
          child: Text(_customPurity ? 'عیار سفارشی' : 'عیار دیگر'),
        ),
        if (_customPurity)
          TextField(
            controller: _fineness,
            inputFormatters: const [PersianNumericInputFormatter(group: false)],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: 'عیار واقعی',
              errorText: _finenessError(_fineness.text),
            ),
            onChanged: (_) {
              _markStarted();
              setState(() {});
            },
          ),
      ],
    ),
  );

  Widget _pricingFields() => _card([
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _rate,
            focusNode: _rateFocus,
            inputFormatters: [
              PersianNumericInputFormatter(decimal: !_isGold, group: true),
            ],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: _isGold
                  ? 'قیمت هر ${_priceUnit == ZarGoldUnit.gram ? 'گرم' : 'مثقال'} (تومان)'
                  : 'نرخ هر واحد ارز (تومان)',
              errorText: _rateError(),
            ),
            onChanged: (_) {
              _markStarted();
              setState(() {});
            },
          ),
        ),
        if (_isGold) ...[
          const SizedBox(width: 8),
          _unitDropdown(_priceUnit, _selectPriceUnit, price: true),
        ],
      ],
    ),
    if (_isGold) ...[
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: () => setState(() => _more = !_more),
          child: Text(_more ? 'بستن گزینه‌های بیشتر' : 'گزینه‌های بیشتر'),
        ),
      ),
      if (_more)
        TextField(
          controller: _reference,
          inputFormatters: const [PersianNumericInputFormatter(group: false)],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: 'عیار مرجع قیمت',
            errorText: _finenessError(_reference.text, label: 'عیار مرجع'),
          ),
          onChanged: (_) {
            _markStarted();
            setState(() {});
          },
        ),
    ],
    if (_summary() case final summary?) ...[
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF9A6700).withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          summary,
          style: const TextStyle(fontWeight: FontWeight.w600, height: 1.65),
        ),
      ),
    ],
  ]);

  Widget _metadataSection() => _metadataExpanded
      ? _card([
          _metadataDateRow(),
          _metadataTimeRow(),
          if (_isSettlement) _metadataReminderRow(),
          if (_notesExpanded)
            _noteField()
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _notesExpanded = true),
                icon: const Icon(CupertinoIcons.add, size: 16),
                label: const Text('افزودن توضیحات'),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _metadataExpanded = false),
              child: const Text('بستن جزئیات'),
            ),
          ),
        ])
      : _card([
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_metadataDateLabel · $_timeLabel · ${_effectiveReminder.isEmpty ? 'بدون یادآوری' : _effectiveReminder}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _metadataExpanded = true),
                child: const Text('ویرایش'),
              ),
            ],
          ),
          if (!_notesExpanded && _note.text.trim().isEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _metadataExpanded = true;
                  _notesExpanded = true;
                }),
                icon: const Icon(CupertinoIcons.add, size: 16),
                label: const Text('افزودن توضیحات'),
              ),
            ),
        ]);

  String get _timeLabel {
    final time = _time;
    if (time == null) return '—';
    return '${toPersianDigits(time.hour.toString().padLeft(2, '0'))}:${toPersianDigits(time.minute.toString().padLeft(2, '0'))}';
  }

  String get _metadataDateLabel =>
      isSameJalali(_date, Jalali.now()) ? 'امروز' : formatJalaliDate(_date);
  Widget _metadataDateRow() => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: const Text('تاریخ ثبت'),
    subtitle: Text(formatJalaliDate(_date)),
    trailing: const Icon(CupertinoIcons.calendar, size: 20),
    onTap: () async {
      final value = await pickJalaliDate(context, _date);
      if (mounted && value != null) setState(() => _date = value);
    },
  );
  Widget _metadataTimeRow() => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: const Text('ساعت ثبت'),
    subtitle: Text(_timeLabel),
    trailing: const Icon(CupertinoIcons.time, size: 20),
    onTap: () async {
      final value = await pickCupertinoTime(context, _time);
      if (mounted && value != null) {
        setState(() {
          _startedInput = true;
          _time = value;
          if (_reminder.isEmpty) _reminder = widget.initialReminder;
        });
      }
    },
  );
  Widget _metadataReminderRow() => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: const Text('یادآوری'),
    subtitle: Text(
      _effectiveReminder.isEmpty ? 'بدون یادآوری' : _effectiveReminder,
    ),
    trailing: const Icon(CupertinoIcons.bell, size: 20),
    onTap: _time == null
        ? () => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('برای یادآوری دقیقه‌ای ابتدا ساعت را انتخاب کنید.'),
            ),
          )
        : () async {
            final value = await showReminderTextPickerBottomSheet(
              context,
              _reminder,
            );
            if (mounted && value != null) {
              if (value == 'سفارشی') {
                final date = await pickJalaliDate(context, _date);
                if (!mounted || date == null) return;
                final time = await pickCupertinoTime(context, null);
                if (!mounted || time == null) return;
                final gregorian = date.toGregorian();
                setState(() {
                  _startedInput = true;
                  _reminder = value;
                  _customReminderAt = DateTime(
                    gregorian.year,
                    gregorian.month,
                    gregorian.day,
                    time.hour,
                    time.minute,
                  ).toUtc();
                });
              } else {
                setState(() {
                  _startedInput = true;
                  _reminder = value;
                  _customReminderAt = null;
                });
              }
            }
          },
  );
  Widget _noteField() => TextField(
    controller: _note,
    maxLines: 2,
    decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)'),
    onChanged: (_) => _markStarted(),
  );

  Widget _stickySubmit() => Container(
    width: double.infinity,
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const CupertinoActivityIndicator()
            : Text(_submitLabel),
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
            label: Text(toPersianDigits(v == 'تحویل' ? 'پرداخت' : v)),
            selected:
                toPersianNumberText(selected ?? '') == toPersianNumberText(v),
            showCheckmark: false,
            onSelected: _saving ? null : (_) => changed(v),
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
                'سکه ${toPersianDigits((index + 1).toString())}',
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
          onChanged: (value) => setState(() {
            _startedInput = true;
            row.selectType(value);
          }),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: row.quantity,
          inputFormatters: [PersianNumericInputFormatter(decimal: false)],
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: 'تعداد',
            errorText: _submitted && !_positiveInteger(row.quantity.text)
                ? 'تعداد باید بیشتر از صفر باشد.'
                : null,
          ),
          onChanged: (_) {
            _markStarted();
            setState(() {});
          },
        ),
        if (row.weighted) ...[
          const SizedBox(height: 10),
          TextField(
            controller: row.weight,
            inputFormatters: [PersianNumericInputFormatter(group: false)],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'وزن هر سکه (گرم)'),
            onChanged: (_) {
              _markStarted();
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: row.fineness,
            inputFormatters: [PersianNumericInputFormatter(group: false)],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'عیار'),
            onChanged: (_) {
              _markStarted();
              setState(() {});
            },
          ),
        ],
        if (_needsPricing) ...[
          const SizedBox(height: 10),
          if (row.weighted)
            _choices(
              const ['هر قطعه', 'هر گرم'],
              row.method == ZarCoinPricingMethod.perPiece
                  ? 'هر قطعه'
                  : 'هر گرم',
              (value) => setState(() {
                _startedInput = true;
                row.method = value == 'هر قطعه'
                    ? ZarCoinPricingMethod.perPiece
                    : ZarCoinPricingMethod.perGram;
              }),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: row.price,
            inputFormatters: [PersianNumericInputFormatter(decimal: false)],
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: row.method == ZarCoinPricingMethod.perPiece
                  ? 'قیمت هر قطعه (تومان)'
                  : 'قیمت هر گرم (تومان)',
              errorText:
                  _submitted &&
                      _needsPricing &&
                      !_positiveInteger(row.price.text)
                  ? 'قیمت باید بیشتر از صفر باشد.'
                  : null,
            ),
            onChanged: (_) {
              _markStarted();
              setState(() {});
            },
          ),
          if (row.method == ZarCoinPricingMethod.perGram) ...[
            TextButton(
              onPressed: () => setState(() {
                _startedInput = true;
                row.more = !row.more;
              }),
              child: Text(row.more ? 'بستن جزئیات بیشتر' : 'جزئیات بیشتر'),
            ),
            if (row.more)
              TextField(
                controller: row.reference,
                inputFormatters: [PersianNumericInputFormatter(group: false)],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'عیار مرجع قیمت'),
                onChanged: (_) {
                  _markStarted();
                  setState(() {});
                },
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
      weight = TextEditingController(
        text: toPersianNumberText(type.defaultWeightGrams ?? ''),
      ),
      fineness = TextEditingController(
        text: toPersianNumberText(type.defaultFineness ?? '750'),
      );
  final String id;
  ZarCoinType? type;
  ZarCoinPricingMethod method;
  bool more = false;
  final quantity = TextEditingController(text: '۱');
  final TextEditingController weight;
  final TextEditingController fineness;
  final price = TextEditingController();
  final reference = TextEditingController(text: '۷۵۰');
  bool get weighted =>
      type?.category == ZarCoinCategory.parsian ||
      method == ZarCoinPricingMethod.perGram;
  void selectType(ZarCoinType? value) {
    type = value;
    if (value == null) return;
    method = value.defaultPricingMethod;
    weight.text = toPersianNumberText(value.defaultWeightGrams ?? '');
    fineness.text = toPersianNumberText(value.defaultFineness ?? '750');
  }

  void dispose() {
    quantity.dispose();
    weight.dispose();
    fineness.dispose();
    price.dispose();
    reference.dispose();
  }
}
