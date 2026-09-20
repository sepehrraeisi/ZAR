import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/zar_domain_models.dart';
import '../../app_core.dart' show toPersianDigits;

class CurrencyCatalogScreen extends StatefulWidget {
  const CurrencyCatalogScreen({
    super.key,
    required this.types,
    required this.onSave,
    required this.onArchive,
    required this.onRestore,
  });

  final List<ZarCurrencyType> types;
  final Future<void> Function(ZarCurrencyType) onSave;
  final Future<void> Function(ZarCurrencyType) onArchive;
  final Future<void> Function(ZarCurrencyType) onRestore;

  @override
  State<CurrencyCatalogScreen> createState() => _CurrencyCatalogScreenState();
}

class _CurrencyCatalogScreenState extends State<CurrencyCatalogScreen> {
  late final List<ZarCurrencyType> _types = [...widget.types];

  List<ZarCurrencyType> get _active =>
      _types.where((item) => !item.archived).toList(growable: false);
  List<ZarCurrencyType> get _archived =>
      _types.where((item) => item.archived).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final archived = _archived;
    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت ارزها')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            '${toPersianDigits(active.length.toString())} ارز فعال',
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
            const _EmptyCatalog(label: 'ارز فعالی ثبت نشده است.')
          else
            ...active.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CurrencyRow(
                  item: item,
                  onTap: () => _edit(context, item),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
            label: const Text('افزودن ارز'),
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
        builder: (_) => _ArchivedCurrencyTypesScreen(
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

  Future<void> _edit(BuildContext context, [ZarCurrencyType? existing]) async {
    final result = await showModalBottomSheet<_CurrencySheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CurrencyEditorSheet(existing: existing),
    );
    if (!mounted || result == null) return;
    if (!context.mounted) return;
    if (result.archive && existing != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('بایگانی ارز'),
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
      if (_types.any(
        (item) => item.code == value.code && item.id != value.id,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('این کد ارز قبلاً ثبت شده است.')),
        );
        return;
      }
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
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_currencyError(error))));
      }
    }
  }

  String _currencyError(FormatException error) =>
      error.message.toString().contains('already exists')
      ? 'این کد ارز قبلاً ثبت شده است.'
      : 'اطلاعات ارز معتبر نیست.';
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({required this.item, required this.onTap});

  final ZarCurrencyType item;
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
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(item.code),
                      ),
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

class _CurrencySheetResult {
  const _CurrencySheetResult.value(this.value) : archive = false;
  const _CurrencySheetResult.archive() : value = null, archive = true;
  final ZarCurrencyType? value;
  final bool archive;
}

class _CurrencyEditorSheet extends StatefulWidget {
  const _CurrencyEditorSheet({this.existing});
  final ZarCurrencyType? existing;
  @override
  State<_CurrencyEditorSheet> createState() => _CurrencyEditorSheetState();
}

class _CurrencyEditorSheetState extends State<_CurrencyEditorSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final code = _code.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) {
      setState(() => _error = 'نام و کد ارز الزامی است.');
      return;
    }
    final now = DateTime.now().toUtc();
    Navigator.pop(
      context,
      _CurrencySheetResult.value(
        ZarCurrencyType(
          id:
              widget.existing?.id ??
              'currency-custom-${now.microsecondsSinceEpoch}',
          name: name,
          code: widget.existing?.code ?? code,
          archived: widget.existing?.archived ?? false,
          createdAt: widget.existing?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
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
              widget.existing == null ? 'افزودن ارز' : 'ویرایش ارز',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            const Text('نام ارز'),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'مثلاً دلار آمریکا'),
            ),
            const SizedBox(height: 14),
            const Text('کد ارز'),
            const SizedBox(height: 6),
            TextField(
              controller: _code,
              enabled: widget.existing == null,
              textDirection: TextDirection.ltr,
              inputFormatters: [const UpperCaseTextFormatter()],
              decoration: const InputDecoration(hintText: 'USD'),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 6),
              const Text(
                'کد ارز پس از ثبت قابل تغییر نیست.',
                style: TextStyle(fontSize: 12),
              ),
            ],
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
                onPressed: () => Navigator.pop(
                  context,
                  const _CurrencySheetResult.archive(),
                ),
                child: const Text('بایگانی این ارز'),
              ),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

class _ArchivedCurrencyTypesScreen extends StatefulWidget {
  const _ArchivedCurrencyTypesScreen({
    required this.types,
    required this.onRestore,
  });
  final List<ZarCurrencyType> types;
  final Future<void> Function(ZarCurrencyType) onRestore;
  @override
  State<_ArchivedCurrencyTypesScreen> createState() =>
      _ArchivedCurrencyTypesScreenState();
}

class _ArchivedCurrencyTypesScreenState
    extends State<_ArchivedCurrencyTypesScreen> {
  late final List<ZarCurrencyType> _types = [...widget.types];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ارزهای بایگانی‌شده')),
    body: _types.isEmpty
        ? const _EmptyCatalog(label: 'ارز بایگانی‌شده‌ای وجود ندارد.')
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
                  subtitle: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(item.code),
                  ),
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
}
