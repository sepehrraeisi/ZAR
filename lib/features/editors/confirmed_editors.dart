import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_core.dart';

/// Person editor that owns the persistence attempt. It never dismisses the
/// sheet until the supplied async save callback succeeds.
class ConfirmedPersonEditorSheet extends StatefulWidget {
  const ConfirmedPersonEditorSheet({
    super.key,
    this.existing,
    required this.onSave,
  });

  final AppPerson? existing;
  final Future<void> Function(AppPerson person) onSave;

  @override
  State<ConfirmedPersonEditorSheet> createState() =>
      _ConfirmedPersonEditorSheetState();
}

class _ConfirmedPersonEditorSheetState
    extends State<ConfirmedPersonEditorSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?.phone ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final person = AppPerson(
      id: widget.existing?.id ?? 'p${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      archived: widget.existing?.archived ?? false,
    );

    try {
      await widget.onSave(person);
      if (mounted) Navigator.of(context).pop(person);
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
    return _ConfirmedSheetFrame(
      title: widget.existing == null ? 'افزودن شخص' : 'ویرایش شخص',
      saving: _saving,
      error: _error,
      onSave: _save,
      child: Column(
        children: [
          TextField(
            controller: _name,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'نام'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            enabled: !_saving,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration:
                const InputDecoration(labelText: 'شماره تماس (اختیاری)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'یادداشت (اختیاری)'),
          ),
        ],
      ),
    );
  }
}

/// Record editor with the same confirmed-write contract. Currency choice and
/// formatted value remain explicit while the surrounding sheet stays RTL.
class ConfirmedRecordEditorSheet extends StatefulWidget {
  const ConfirmedRecordEditorSheet({
    super.key,
    required this.record,
    required this.personName,
    required this.onSave,
  });

  final AppRecord record;
  final String personName;
  final Future<void> Function(AppRecord record) onSave;

  @override
  State<ConfirmedRecordEditorSheet> createState() =>
      _ConfirmedRecordEditorSheetState();
}

class _ConfirmedRecordEditorSheetState extends State<ConfirmedRecordEditorSheet> {
  late final TextEditingController _amount =
      TextEditingController(text: widget.record.amountDisplay);
  late final TextEditingController _note =
      TextEditingController(text: widget.record.note ?? '');
  late String? _currencyCode = widget.record.currencyCode ??
      (widget.record.assetLabel == 'ارز' ? 'USD' : null);

  bool _saving = false;
  String? _error;

  CurrencyOption? get _selectedCurrency => currencyByCode(_currencyCode);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rawAmount = _amount.text.trim();
    if (rawAmount.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final amountDisplay = widget.record.assetLabel == 'ارز' &&
            _currencyCode != null
        ? formatCurrencyAmount(rawAmount, _currencyCode!)
        : rawAmount;
    final updated = widget.record.copyWith(
      amountDisplay: amountDisplay,
      currencyCode:
          widget.record.assetLabel == 'ارز' ? _currencyCode : null,
      note: _note.text.trim(),
    );

    try {
      await widget.onSave(updated);
      if (mounted) Navigator.of(context).pop(updated);
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
    return _ConfirmedSheetFrame(
      title: 'ویرایش تعهد',
      saving: _saving,
      error: _error,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.personName, style: Theme.of(context).textTheme.bodyMedium),
          if (widget.record.assetLabel == 'ارز') ...[
            const SizedBox(height: 8),
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
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            enabled: !_saving,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'مبلغ/مقدار'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'توضیحات'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmedSheetFrame extends StatelessWidget {
  const _ConfirmedSheetFrame({
    required this.title,
    required this.child,
    required this.saving,
    required this.error,
    required this.onSave,
  });

  final String title;
  final Widget child;
  final bool saving;
  final String? error;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              child,
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CupertinoActivityIndicator(),
                        )
                      : const Text('ذخیره'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
