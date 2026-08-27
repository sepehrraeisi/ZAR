import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ArchivedPersonViewData {
  const ArchivedPersonViewData({
    required this.id,
    required this.name,
    this.phone,
    this.openObligations = 0,
  });

  final String id;
  final String name;
  final String? phone;
  final int openObligations;
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
        .where((p) => trimmed.isEmpty || p.name.contains(trimmed) || (p.phone?.contains(trimmed) ?? false))
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
                        separatorBuilder: (_, __) => Divider(color: Theme.of(context).dividerColor),
                        itemBuilder: (context, index) {
                          final person = filtered[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => widget.onOpenPerson(person.id),
                            title: Text(person.name, style: Theme.of(context).textTheme.bodyLarge),
                            subtitle: Text(
                              person.openObligations > 0
                                  ? '${_persianDigits(person.openObligations)} تعهد باز دارد'
                                  : (person.phone ?? 'بدون شماره تماس'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                              child: Text(
                                person.name.isEmpty ? '-' : person.name[0],
                                style: TextStyle(color: Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            trailing: TextButton.icon(
                              onPressed: () => widget.onRestore(person.id),
                              icon: const Icon(CupertinoIcons.arrow_uturn_right, size: 16),
                              label: const Text('بازگردانی'),
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
