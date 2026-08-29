import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../app_core.dart';

/// Quick Add variant that keeps the sheet open until persistence succeeds.
class ConfirmedQuickAddSheet extends StatefulWidget {
  const ConfirmedQuickAddSheet({
    super.key,
    required this.people,
    required this.onSave,
    this.initialReminder = '۱۵ دقیقه',
  });

  final List<AppPerson> people;
  final Future<void> Function(QuickAddDraft draft) onSave;
  final String initialReminder;

  @override
  State<ConfirmedQuickAddSheet> createState() =>
      _ConfirmedQuickAddSheetState();
}

class _ConfirmedQuickAddSheetState extends State<ConfirmedQuickAddSheet> {
  String? _operation;
  String? _asset;
  String? _currencyCode;
  AppPerson? _person;
  Jalali _date = Jalali.now();
  TimeOfDay? _time;
  late String _reminder = widget.initialReminder;
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _isSettlement => _operation == 'دریافت' || _operation == 'تحویل';
  CurrencyOption? get _selectedCurrency => currencyByCode(_currencyCode);

  bool get _ready {
    final currencyReady = _asset != 'ارز' || _currencyCode != null;
    return _operation != null &&
        _asset != null &&
        _person != null &&
        currencyReady &&
        _amount.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_ready || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = QuickAddDraft(
      operation: _operation!,
      asset: _asset!,
      personId: _person!.id,
      amount: _amount.text.trim(),
      date: _date,
      time: _time,
      reminder: _isSettlement ? _reminder : '',
      note: _note.text.trim(),
      currencyCode: _currencyCode,
    );

    try {
      await widget.onSave(draft);
      if (mounted) Navigator.of(context).pop(draft);
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'مقدار واردشده معتبر نیست.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'اطلاعات ثبت نشد. دوباره تلاش کنید.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['خرید', 'فروش', 'دریافت', 'تحویل']
                    .map(
                      (value) => _chip(
                        context,
                        value,
                        _operation == value,
                        _saving
                            ? null
                            : () => setState(() => _operation = value),
                      ),
                    )
                    .toList(growable: false),
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
                        _operation == null || _saving
                            ? null
                            : () => setState(() {
                                  _asset = value;
                                  if (value == 'ارز') {
                                    _currencyCode ??= 'USD';
                                  } else {
                                    _currencyCode = null;
                                  }
                                }),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !_saving,
                title: const Text('شخص'),
                subtitle: Text(_person?.name ?? 'انتخاب شخص'),
                trailing: const Icon(CupertinoIcons.chevron_down),
                onTap: () async {
                  final selected =
                      await showPersonPickerBottomSheet(context, widget.people);
                  if (mounted && selected != null) {
                    setState(() => _person = selected);
                  }
                },
              ),
              if (_asset == 'ارز')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: !_saving,
                  title: const Text('نوع ارز'),
                  subtitle: Text(
                    _selectedCurrency?.displayLabel ?? 'انتخاب نوع ارز',
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
              TextField(
                controller: _amount,
                enabled: !_saving,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                decoration:
                    InputDecoration(labelText: _asset == 'طلا' ? 'مقدار' : 'مبلغ'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !_saving,
                title: const Text('تاریخ'),
                subtitle: Text(formatJalaliDate(_date)),
                trailing: const Icon(CupertinoIcons.calendar),
                onTap: () async {
                  final selected = await pickJalaliDate(context, _date);
                  if (mounted && selected != null) {
                    setState(() => _date = selected);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !_saving,
                title: const Text('ساعت'),
                subtitle: Text(
                  _time == null
                      ? 'بدون ساعت'
                      : '${toPersianDigits(_time!.hour.toString().padLeft(2, '0'))}:${toPersianDigits(_time!.minute.toString().padLeft(2, '0'))}',
                ),
                trailing: const Icon(CupertinoIcons.time),
                onTap: () async {
                  final selected = await pickCupertinoTime(context, _time);
                  if (mounted && selected != null) {
                    setState(() => _time = selected);
                  }
                },
              ),
              if (_isSettlement)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: !_saving,
                  title: const Text('یادآوری'),
                  subtitle: Text(_reminder),
                  trailing: const Icon(CupertinoIcons.bell),
                  onTap: () async {
                    final selected = await showReminderTextPickerBottomSheet(
                      context,
                      _reminder,
                    );
                    if (mounted && selected != null) {
                      setState(() => _reminder = selected);
                    }
                  },
                ),
              TextField(
                controller: _note,
                enabled: !_saving,
                decoration:
                    const InputDecoration(labelText: 'توضیحات (اختیاری)'),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _ready && !_saving ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CupertinoActivityIndicator(),
                        )
                      : const Text('ثبت'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String text,
    bool selected,
    VoidCallback? onTap,
  ) {
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      showCheckmark: false,
      selectedColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
            : Theme.of(context).dividerColor,
      ),
      onSelected: onTap == null ? null : (_) => onTap(),
    );
  }
}
