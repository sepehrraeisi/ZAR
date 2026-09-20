import 'package:flutter/material.dart';

import '../../app_core.dart';
import '../../domain/zar_domain_models.dart';
import '../editors/persian_numeric_input_formatter.dart';

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

  List<ZarCoinType> get _active =>
      _types.where((item) => !item.archived).toList(growable: false);
  List<ZarCoinType> get _archived =>
      _types.where((item) => item.archived).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final archived = _archived;
    return Scaffold(
      appBar: AppBar(title: const Text('انواع سکه')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            '${toPersianDigits(active.length.toString())} نوع فعال',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => _openArchived(context),
                child: Text(
                  'بایگانی‌شده‌ها (${toPersianDigits(archived.length.toString())})',
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (active.isEmpty)
            const _EmptyCatalog(label: 'نوع سکه فعالی ثبت نشده است.')
          else
            ...active.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CoinRow(item: item, onTap: () => _edit(context, item)),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
            label: const Text('افزودن نوع سکه'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openArchived(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ArchivedCoinTypesScreen(
          types: _archived,
          onRestore: (item) async {
            await widget.onRestore(item);
            if (!mounted) return;
            setState(() {
              final index = _types.indexWhere((row) => row.id == item.id);
              if (index >= 0) {
                _types[index] = item.copyWith(
                  archived: false,
                  updatedAt: DateTime.now().toUtc(),
                );
              }
            });
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _edit(BuildContext context, [ZarCoinType? existing]) async {
    final result = await showModalBottomSheet<_CoinSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CoinEditorSheet(existing: existing),
    );
    if (!mounted || result == null) return;
    if (!context.mounted) return;
    if (result.archive && existing != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('بایگانی نوع سکه'),
          content: Text('آیا «${existing.name}» بایگانی شود؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('بایگانی'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await widget.onArchive(existing);
      if (!mounted) return;
      setState(() {
        final index = _types.indexWhere((row) => row.id == existing.id);
        if (index >= 0) {
          _types[index] = existing.copyWith(
            archived: true,
            updatedAt: DateTime.now().toUtc(),
          );
        }
      });
      return;
    }
    try {
      final value = result.value!;
      await widget.onSave(value);
      if (!mounted) return;
      setState(() {
        final index = _types.indexWhere((row) => row.id == value.id);
        if (index < 0) {
          _types.add(value);
        } else {
          _types[index] = value;
        }
      });
    } on FormatException catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اطلاعات نوع سکه معتبر نیست.')),
        );
      }
    }
  }
}

class _CoinRow extends StatelessWidget {
  const _CoinRow({required this.item, required this.onTap});
  final ZarCoinType item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 16, 12),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.chevron_left),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _details(item),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _details(ZarCoinType item) => [
    item.defaultPricingMethod == ZarCoinPricingMethod.perPiece
        ? 'قیمت‌گذاری قطعه‌ای'
        : 'قیمت‌گذاری وزنی',
    if (item.defaultWeightGrams != null)
      '${toPersianNumberText(item.defaultWeightGrams!)} گرم',
    if (item.defaultFineness != null)
      'عیار ${toPersianNumberText(item.defaultFineness!)}',
  ].join(' • ');
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(child: Text(label)),
  );
}

class _CoinSheetResult {
  const _CoinSheetResult.value(this.value) : archive = false;
  const _CoinSheetResult.archive() : value = null, archive = true;
  final ZarCoinType? value;
  final bool archive;
}

class _CoinEditorSheet extends StatefulWidget {
  const _CoinEditorSheet({this.existing});
  final ZarCoinType? existing;
  @override
  State<_CoinEditorSheet> createState() => _CoinEditorSheetState();
}

class _CoinEditorSheetState extends State<_CoinEditorSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _weight = TextEditingController(
    text: widget.existing?.defaultWeightGrams == null
        ? ''
        : toPersianNumberText(widget.existing!.defaultWeightGrams!),
  );
  late final TextEditingController _fineness = TextEditingController(
    text: widget.existing?.defaultFineness == null
        ? ''
        : toPersianNumberText(widget.existing!.defaultFineness!),
  );
  late ZarCoinCategory _category =
      widget.existing?.category ?? ZarCoinCategory.other;
  late ZarCoinPricingMethod _method =
      widget.existing?.defaultPricingMethod ?? ZarCoinPricingMethod.perPiece;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _fineness.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'نام نوع سکه الزامی است.');
      return;
    }
    final now = DateTime.now().toUtc();
    try {
      final value = ZarCoinType(
        id: widget.existing?.id ?? 'coin-custom-${now.microsecondsSinceEpoch}',
        name: _name.text,
        category: _category,
        defaultWeightGrams: _weight.text.trim().isEmpty ? null : _weight.text,
        defaultFineness: _fineness.text.trim().isEmpty ? null : _fineness.text,
        defaultPricingMethod: _method,
        archived: widget.existing?.archived ?? false,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );
      Navigator.pop(context, _CoinSheetResult.value(value));
    } on FormatException {
      setState(() => _error = 'وزن یا عیار واردشده معتبر نیست.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.existing == null ? 'افزودن نوع سکه' : 'ویرایش نوع سکه',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            const Text('نام نوع سکه'),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'مثلاً سکه امامی'),
            ),
            const SizedBox(height: 14),
            const Text('دسته'),
            const SizedBox(height: 6),
            DropdownButtonFormField<ZarCoinCategory>(
              initialValue: _category,
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
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 14),
            const Text('روش قیمت پیش‌فرض'),
            const SizedBox(height: 6),
            DropdownButtonFormField<ZarCoinPricingMethod>(
              initialValue: _method,
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
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            const SizedBox(height: 14),
            const Text('وزن پیش‌فرض (اختیاری، گرم)'),
            const SizedBox(height: 6),
            TextField(
              controller: _weight,
              inputFormatters: [
                const PersianNumericInputFormatter(group: false),
              ],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 14),
            const Text('عیار پیش‌فرض (اختیاری)'),
            const SizedBox(height: 6),
            TextField(
              controller: _fineness,
              inputFormatters: [
                const PersianNumericInputFormatter(group: false),
              ],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(onPressed: _save, child: const Text('ذخیره')),
            if (widget.existing != null && !widget.existing!.archived)
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, const _CoinSheetResult.archive()),
                child: const Text('بایگانی این نوع سکه'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedCoinTypesScreen extends StatefulWidget {
  const _ArchivedCoinTypesScreen({
    required this.types,
    required this.onRestore,
  });
  final List<ZarCoinType> types;
  final Future<void> Function(ZarCoinType) onRestore;
  @override
  State<_ArchivedCoinTypesScreen> createState() =>
      _ArchivedCoinTypesScreenState();
}

class _ArchivedCoinTypesScreenState extends State<_ArchivedCoinTypesScreen> {
  late final List<ZarCoinType> _types = [...widget.types];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('انواع سکه بایگانی‌شده')),
    body: _types.isEmpty
        ? const _EmptyCatalog(label: 'نوع سکه بایگانی‌شده‌ای وجود ندارد.')
        : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: _types.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _types[index];
              return Card(
                elevation: 0,
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(_details(item)),
                  trailing: TextButton(
                    onPressed: () async {
                      await widget.onRestore(item);
                      if (mounted) setState(() => _types.removeAt(index));
                    },
                    child: const Text('بازگردانی'),
                  ),
                ),
              );
            },
          ),
  );

  String _details(ZarCoinType item) => [
    item.defaultPricingMethod == ZarCoinPricingMethod.perPiece
        ? 'قیمت‌گذاری قطعه‌ای'
        : 'قیمت‌گذاری وزنی',
    if (item.defaultWeightGrams != null)
      '${toPersianNumberText(item.defaultWeightGrams!)} گرم',
    if (item.defaultFineness != null)
      'عیار ${toPersianNumberText(item.defaultFineness!)}',
  ].join(' • ');
}
