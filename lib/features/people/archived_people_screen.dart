import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ArchivedPersonViewData {
  const ArchivedPersonViewData({
    required this.id,
    required this.name,
    this.phone,
    this.openObligations = 0,
    this.dealCount = 0,
  });

  final String id;
  final String name;
  final String? phone;
  final int openObligations;
  final int dealCount;
}

class ArchivedPeopleScreen extends StatefulWidget {
  const ArchivedPeopleScreen({
    super.key,
    required this.people,
    required this.onOpenPerson,
    required this.onRestore,
  });

  final List<ArchivedPersonViewData> people;
  final ValueChanged<String> onOpenPerson;
  final ValueChanged<String> onRestore;

  @override
  State<ArchivedPeopleScreen> createState() => _ArchivedPeopleScreenState();
}

class _ArchivedPeopleScreenState extends State<ArchivedPeopleScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final trimmed = query.trim();
    final filtered = widget.people
        .where(
          (p) =>
              trimmed.isEmpty ||
              p.name.contains(trimmed) ||
              (p.phone?.contains(trimmed) ?? false),
        )
        .toList(growable: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('اشخاص بایگانی‌شده')),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'جستجو در بایگانی',
                  prefixIcon: Icon(CupertinoIcons.search),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('شخص بایگانی‌شده‌ای پیدا نشد.'))
                    : ListView.separated(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.only(top: 2),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final person = filtered[index];
                          final theme = Theme.of(context);
                          return Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: theme.dividerColor),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => widget.onOpenPerson(person.id),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  13,
                                  10,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 21,
                                      backgroundColor: theme.colorScheme.primary
                                          .withValues(alpha: 0.12),
                                      child: Text(
                                        person.name.isEmpty
                                            ? '-'
                                            : person.name[0],
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            person.name,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          if ((person.phone ?? '')
                                              .trim()
                                              .isNotEmpty)
                                            Directionality(
                                              textDirection: TextDirection.ltr,
                                              child: Text(
                                                person.phone!,
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              _ArchivePill(
                                                '${_persianDigits(person.dealCount)} معامله',
                                              ),
                                              _ArchivePill(
                                                person.openObligations > 0
                                                    ? '${_persianDigits(person.openObligations)} تعهد باز دارد'
                                                    : 'تعهد باز ندارد',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 94,
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            widget.onRestore(person.id),
                                        icon: const Icon(
                                          CupertinoIcons.arrow_uturn_right,
                                          size: 17,
                                        ),
                                        label: const Text('بازگردانی'),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          minimumSize: const Size(44, 44),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _persianDigits(int input) {
    const latin = '0123456789';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var output = input.toString();
    for (var i = 0; i < latin.length; i++) {
      output = output.replaceAll(latin[i], persian[i]);
    }
    return output;
  }
}

class _ArchivePill extends StatelessWidget {
  const _ArchivePill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(label, style: Theme.of(context).textTheme.bodySmall),
  );
}

Future<bool> confirmArchiveWithOpenObligations(
  BuildContext context, {
  required int openObligations,
}) async {
  if (openObligations <= 0) return true;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('بایگانی شخص'),
        content: Text(
          'این شخص ${_digits(openObligations)} تعهد باز دارد. با بایگانی کردن، تعهدها حذف یا لغو نمی‌شوند. ادامه می‌دهید؟',
        ),
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
    ),
  );
  return result ?? false;
}

String _digits(int input) {
  const latin = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var output = input.toString();
  for (var i = 0; i < latin.length; i++) {
    output = output.replaceAll(latin[i], persian[i]);
  }
  return output;
}
