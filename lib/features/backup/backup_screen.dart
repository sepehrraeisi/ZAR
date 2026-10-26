import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../application/zar_backup_manager.dart';
import '../../app_core.dart' show formatJalaliDate, toPersianDigits;
import 'backup_file_service.dart';

/// Signed-in cloud account shown as a section on the settings screen.
/// Null in local mode — the section disappears entirely.
class ZarAccountSection {
  const ZarAccountSection({
    required this.email,
    required this.onSignOut,
    this.serverUrl,
  });

  final String email;
  final String? serverUrl;
  final Future<void> Function() onSignOut;
}

class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.manager,
    this.files = const PlatformBackupFileService(),
    this.onOpenCoinCatalog,
    this.onOpenCurrencyCatalog,
    this.account,
  });

  final ZarBackupManager manager;
  final BackupFileService files;
  final VoidCallback? onOpenCoinCatalog;
  final VoidCallback? onOpenCurrencyCatalog;
  final ZarAccountSection? account;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  ZarBackupPreview? _lastExport;

  String _fileName(DateTime createdAt) {
    final value = createdAt.toUtc().toIso8601String().replaceAll(':', '-');
    return 'zar-plus-backup-$value.json';
  }

  Future<void> _export({required bool share}) async {
    await _run(() async {
      final json = await widget.manager.createJson();
      final preview = widget.manager.preview(json);
      final name = _fileName(preview.bundle.generatedAt);
      if (share) {
        await widget.files.shareJson(fileName: name, contents: json);
      } else {
        final saved = await widget.files.saveJson(
          fileName: name,
          contents: json,
        );
        if (!saved) return;
      }
      if (!mounted) return;
      setState(() => _lastExport = preview);
      _message(
        share
            ? 'نسخه پشتیبان آماده اشتراک‌گذاری است.'
            : 'نسخه پشتیبان ذخیره شد.',
      );
    });
  }

  Future<void> _import() async {
    await _run(() async {
      final json = await widget.files.pickJson();
      if (json == null || !mounted) return;
      final preview = widget.manager.preview(json);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('بررسی نسخه پشتیبان'),
          content: _BackupSummary(preview: preview),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('جایگزینی و بازیابی'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await widget.manager.restore(preview);
      if (!mounted) return;
      _message('بازیابی کامل شد و یادآوری‌ها بازسازی شدند.');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on FormatException catch (error) {
      _message(_formatError(error));
    } on ZarRestoreReminderException {
      _message(
        'اطلاعات بازیابی شد، اما بازسازی اعلان‌ها کامل نشد. برنامه را دوباره باز کنید.',
      );
    } catch (_) {
      _message('عملیات انجام نشد. فایل و دسترسی دستگاه را بررسی کنید.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatError(FormatException error) {
    final text = error.message.toString();
    if (text.contains('Unsupported')) {
      return 'نسخه این فایل پشتیبانی نمی‌شود.';
    }
    if (text.contains('different business')) {
      return 'این نسخه پشتیبان مربوط به حساب دیگری است.';
    }
    return 'فایل نسخه پشتیبان معتبر نیست یا اطلاعات ضروری آن ناقص است.';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پشتیبان‌گیری و داده‌ها')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.account != null) ...[
            _AccountCard(account: widget.account!),
            const Divider(height: 40),
          ],
          Text(
            'نسخه پشتیبان کامل',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'افراد، معاملات طلا، سکه و ارز، دریافت و پرداخت، وضعیت بایگانی و برنامه‌های یادآوری در فایل JSON نسخه ۷ نگهداری می‌شوند. فایل‌های نسخه ۲، ۳، ۴، ۵ و ۶ همچنان قابل بازیابی هستند.',
          ),
          const SizedBox(height: 20),
          if (widget.onOpenCoinCatalog != null ||
              widget.onOpenCurrencyCatalog != null) ...[
            Row(
              children: [
                if (widget.onOpenCoinCatalog != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : widget.onOpenCoinCatalog,
                      icon: const Icon(CupertinoIcons.circle_grid_hex),
                      label: const Text('مدیریت انواع سکه'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                  ),
                if (widget.onOpenCoinCatalog != null &&
                    widget.onOpenCurrencyCatalog != null)
                  const SizedBox(width: 12),
                if (widget.onOpenCurrencyCatalog != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : widget.onOpenCurrencyCatalog,
                      icon: const Icon(CupertinoIcons.money_dollar_circle),
                      label: const Text('مدیریت ارزها'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 40),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : () => _export(share: false),
            icon: const Icon(CupertinoIcons.arrow_down_doc),
            label: const Text('ساخت و ذخیره نسخه پشتیبان'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _export(share: true),
            icon: const Icon(CupertinoIcons.share),
            label: const Text('ساخت و اشتراک‌گذاری'),
          ),
          if (_lastExport != null) ...[
            const SizedBox(height: 18),
            _BackupSummary(preview: _lastExport!),
          ],
          const Divider(height: 40),
          Text(
            'بازیابی اطلاعات',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'فایل ابتدا بدون تغییر اطلاعات بررسی می‌شود. پس از نمایش خلاصه و تأیید شما، داده‌های فعلی به‌طور کامل جایگزین می‌شوند.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(CupertinoIcons.arrow_up_doc),
            label: const Text('انتخاب و بررسی فایل پشتیبان'),
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(child: CupertinoActivityIndicator()),
          ],
          const SizedBox(height: 16),
          const Text(
            'CSV فقط برای گزارش است و برای بازیابی کامل استفاده نمی‌شود.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final ZarAccountSection account;

  Future<void> _confirmSignOut(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خروج از حساب'),
        content: Text(
          'از حساب ${account.email} خارج می‌شوید. برای ورود دوباره به ایمیل و رمز عبور نیاز دارید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (confirmed == true) await account.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = account.email.isEmpty
        ? '?'
        : account.email.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        account.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (account.serverUrl != null) ...[
                      const SizedBox(height: 2),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          account.serverUrl!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(CupertinoIcons.square_arrow_right),
            label: const Text('خروج از حساب'),
          ),
        ],
      ),
    );
  }
}

class _BackupSummary extends StatelessWidget {
  const _BackupSummary({required this.preview});

  final ZarBackupPreview preview;

  @override
  Widget build(BuildContext context) {
    final bundle = preview.bundle;
    final local = bundle.generatedAt.toLocal();
    final jalali = Jalali.fromDateTime(local);
    final time =
        '${toPersianDigits(local.hour.toString().padLeft(2, '0'))}:'
        '${toPersianDigits(local.minute.toString().padLeft(2, '0'))}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('نسخه قالب: ${toPersianDigits(bundle.exportVersion.toString())}'),
        Text('زمان ساخت: ${formatJalaliDate(jalali)}، $time'),
        Text('افراد: ${toPersianDigits(preview.peopleCount.toString())}'),
        Text(
          'افراد بایگانی‌شده: ${toPersianDigits(preview.archivedPeopleCount.toString())}',
        ),
        Text('خرید و فروش: ${toPersianDigits(preview.dealCount.toString())}'),
        Text(
          'دریافت و پرداخت: ${toPersianDigits(preview.settlementCount.toString())}',
        ),
        Text(
          'انواع ارز: ${toPersianDigits(preview.currencyTypeCount.toString())}',
        ),
        Text(
          'تسویه‌های دارای یادآوری: ${toPersianDigits(preview.settlementReminderCount.toString())} '
          '(${toPersianDigits(preview.reminderRuleCount.toString())} یادآوری)',
        ),
      ],
    );
  }
}
