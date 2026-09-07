import 'package:flutter/material.dart';
import '../../application/customer_operational_balance_projector.dart';
import '../../domain/zar_domain_models.dart';
import '../../domain/zar_payment_allocation.dart';
import '../../domain/zar_amount_formatter.dart';
import '../editors/persian_numeric_input_formatter.dart';

class PaymentAllocationSheet extends StatefulWidget {
  const PaymentAllocationSheet({
    super.key,
    required this.source,
    required this.targets,
    required this.initial,
    required this.targetLabel,
    required this.onSave,
  });
  final ZarSettlement source;
  final List<ZarCustomerTomanObligation> targets;
  final List<ZarPaymentAllocation> initial;
  final String Function(ZarCustomerTomanObligation) targetLabel;
  final Future<void> Function(List<ZarPaymentAllocation>) onSave;
  @override
  State<PaymentAllocationSheet> createState() => _PaymentAllocationSheetState();
}

class _PaymentAllocationSheetState extends State<PaymentAllocationSheet> {
  final Map<String, TextEditingController> _amounts = {};
  bool _saving = false;
  String? _error;
  String _key(ZarCustomerTomanObligation target) =>
      '${target.targetType.name}:${target.targetId}';
  @override
  void initState() {
    super.initState();
    for (final target in widget.targets) {
      final rows = widget.initial.where(
        (row) =>
            row.targetType == target.targetType &&
            row.targetId == target.targetId,
      );
      _amounts[_key(target)] = TextEditingController(
        text: rows.isEmpty
            ? ''
            : ZarAmountFormatter.toman(
                BigInt.from(rows.single.amount.wholeTomans),
              ).replaceAll(' تومان', ''),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final rows = <ZarPaymentAllocation>[];
    try {
      for (final target in widget.targets) {
        final text = _amounts[_key(target)]!.text;
        if (text.trim().isEmpty) continue;
        final amount = ZarTomanAmount(int.parse(normalizeDecimal(text)));
        rows.add(
          ZarPaymentAllocation(
            settlementId: widget.source.id,
            targetType: target.targetType,
            targetId: target.targetId,
            amount: amount,
          ),
        );
      }
      if (rows.fold(
            BigInt.zero,
            (sum, row) => sum + BigInt.from(row.amount.wholeTomans),
          ) >
          zarWholeToman(widget.source.amount)!) {
        throw const FormatException('Source exceeded');
      }
      setState(() {
        _saving = true;
        _error = null;
      });
      await widget.onSave(rows);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'تخصیص ذخیره نشد. مبلغ باید مثبت و حداکثر برابر مبلغ ثبت و مانده مقصد باشد. دوباره بررسی کنید.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'تخصیص دریافت / پرداخت',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'مبلغ ثبت: ${ZarAmountFormatter.toman(zarWholeToman(widget.source.amount)!)}',
          ),
          const SizedBox(height: 8),
          const Text(
            'فقط مقصدهایی که برایشان مبلغ وارد می‌کنید تسویه می‌شوند. بدون تخصیص، این ثبت آزاد می‌ماند.',
          ),
          if (widget.source.isOpen)
            const Text(
              'کاهش مانده فقط پس از انجام دریافت/پرداخت اعمال می‌شود.',
            ),
          for (final target in widget.targets)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextField(
                enabled: !_saving,
                controller: _amounts[_key(target)],
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                inputFormatters: const [
                  PersianNumericInputFormatter(decimal: false),
                ],
                decoration: InputDecoration(
                  labelText: widget.targetLabel(target),
                  helperText:
                      'مانده: ${ZarAmountFormatter.toman(target.remainingToman)} — تومان تخصیص‌یافته',
                ),
              ),
            ),
          if (widget.targets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('تعهد تومانی قابل تخصیص وجود ندارد.'),
            ),
          TextButton(
            onPressed: _saving
                ? null
                : () => setState(() {
                    for (final controller in _amounts.values) {
                      controller.clear();
                    }
                  }),
            child: const Text('بدون تخصیص — دریافت/پرداخت آزاد'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'در حال ذخیره…' : 'تأیید و ذخیره تخصیص'),
          ),
        ],
      ),
    ),
  );
}
