import 'package:flutter/material.dart';

import '../../app_core.dart';
import '../../domain/zar_domain_models.dart';

class CoinCatalogScreen extends StatefulWidget {
  const CoinCatalogScreen({
    super.key,
    required this.types,
    required this.onSave,
    required this.onArchive,
    required this.onRestore,
  });
  final List<ZarCoinType> types;
  final Future<void> Function(ZarCoinType) onSave;
  final Future<void> Function(ZarCoinType) onArchive;
  final Future<void> Function(ZarCoinType) onRestore;

  @override
  State<CoinCatalogScreen> createState() => _CoinCatalogScreenState();
}

class _CoinCatalogScreenState extends State<CoinCatalogScreen> {
  late final List<ZarCoinType> _types = [...widget.types];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('انواع سکه')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(context),
      icon: const Icon(Icons.add),
      label: const Text('افزودن نوع سکه'),
    ),
    body: ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: _types.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _types[index];
        return Card(
          child: ListTile(
            title: Text(item.name),
            subtitle: Text(
              [
                item.defaultPricingMethod == ZarCoinPricingMethod.perPiece
                    ? 'قیمت‌گذاری قطعه‌ای'
                    : 'قیمت‌گذاری وزنی',
                if (item.defaultWeightGrams != null)
                  '${toPersianDigits(item.defaultWeightGrams!)} گرم',
                if (item.defaultFineness != null)
                  'عیار ${toPersianDigits(item.defaultFineness!)}',
                if (item.archived) 'بایگانی‌شده',
              ].join(' • '),
            ),
            onTap: () => _edit(context, item),
            trailing: TextButton(
              onPressed: () async {
                if (item.archived) {
                  await widget.onRestore(item);
                  setState(
                    () => _types[index] = item.copyWith(
                      archived: false,
                      updatedAt: DateTime.now().toUtc(),
                    ),
                  );
                } else {
                  await widget.onArchive(item);
                  setState(
                    () => _types[index] = item.copyWith(
                      archived: true,
                      updatedAt: DateTime.now().toUtc(),
                    ),
                  );
                }
              },
              child: Text(item.archived ? 'بازگردانی' : 'بایگانی'),
            ),
          ),
        );
      },
    ),
  );

  Future<void> _edit(BuildContext context, [ZarCoinType? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final weight = TextEditingController(
      text: existing?.defaultWeightGrams ?? '',
    );
    final fineness = TextEditingController(
      text: existing?.defaultFineness ?? '',
    );
    var category = existing?.category ?? ZarCoinCategory.other;
    var method =
        existing?.defaultPricingMethod ?? ZarCoinPricingMethod.perPiece;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'نوع سکه جدید' : 'ویرایش نوع سکه'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'نام'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ZarCoinCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'دسته'),
                  items: const [
                    DropdownMenuItem(
                      value: ZarCoinCategory.official,
                      child: Text('رسمی/بانکی'),
                    ),
                    DropdownMenuItem(
                      value: ZarCoinCategory.parsian,
                      child: Text('پارسیان/وزنی'),
                    ),
                    DropdownMenuItem(
                      value: ZarCoinCategory.other,
                      child: Text('سایر'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => category = value!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ZarCoinPricingMethod>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'روش قیمت پیش‌فرض',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ZarCoinPricingMethod.perPiece,
                      child: Text('هر قطعه'),
                    ),
                    DropdownMenuItem(
                      value: ZarCoinPricingMethod.perGram,
                      child: Text('هر گرم'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => method = value!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'وزن پیش‌فرض (اختیاری)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fineness,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'عیار پیش‌فرض (اختیاری)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) {
      name.dispose();
      weight.dispose();
      fineness.dispose();
      return;
    }
    final now = DateTime.now().toUtc();
    final value = ZarCoinType(
      id: existing?.id ?? 'coin-custom-${now.microsecondsSinceEpoch}',
      name: name.text,
      category: category,
      defaultWeightGrams: weight.text.trim().isEmpty ? null : weight.text,
      defaultFineness: fineness.text.trim().isEmpty ? null : fineness.text,
      defaultPricingMethod: method,
      archived: existing?.archived ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await widget.onSave(value);
    setState(() {
      final index = _types.indexWhere((item) => item.id == value.id);
      if (index < 0) {
        _types.add(value);
      } else {
        _types[index] = value;
      }
    });
    name.dispose();
    weight.dispose();
    fineness.dispose();
  }
}
