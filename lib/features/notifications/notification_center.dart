import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Privacy level for content shown in notifications and on the lock screen.
enum NotificationPrivacy { full, limited, private }

/// User-facing sound preference. Native adapters must still respect platform
/// settings (Silent/Focus modes, system notification permissions, etc.).
enum NotificationSoundProfile { systemDefault, subtle, silent }

/// UI-level notification preferences. Native persistence/scheduling is wired later.
class ZarNotificationPreferences {
  const ZarNotificationPreferences({
    this.enabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.soundProfile = NotificationSoundProfile.systemDefault,
    this.privacy = NotificationPrivacy.limited,
    this.defaultReminderMinutes = 60,
    this.defaultSnoozeMinutes = 30,
  });

  final bool enabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final NotificationSoundProfile soundProfile;
  final NotificationPrivacy privacy;
  final int defaultReminderMinutes;
  final int defaultSnoozeMinutes;

  ZarNotificationPreferences copyWith({
    bool? enabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    NotificationSoundProfile? soundProfile,
    NotificationPrivacy? privacy,
    int? defaultReminderMinutes,
    int? defaultSnoozeMinutes,
  }) {
    return ZarNotificationPreferences(
      enabled: enabled ?? this.enabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundProfile: soundProfile ?? this.soundProfile,
      privacy: privacy ?? this.privacy,
      defaultReminderMinutes: defaultReminderMinutes ?? this.defaultReminderMinutes,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
    );
  }
}

/// Presentation model kept independent from persistence and scheduling services.
class ZarNotificationItem {
  const ZarNotificationItem({
    required this.id,
    required this.recordId,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    this.isUnread = true,
    this.isOverdue = false,
  });

  final String id;
  final String recordId;
  final String title;
  final String subtitle;
  final String timeLabel;
  final bool isUnread;
  final bool isOverdue;
}

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({
    super.key,
    required this.overdue,
    required this.today,
    required this.upcoming,
    required this.onOpenRecord,
    required this.onOpenSettings,
  });

  final List<ZarNotificationItem> overdue;
  final List<ZarNotificationItem> today;
  final List<ZarNotificationItem> upcoming;
  final ValueChanged<String> onOpenRecord;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اعلان‌ها'),
          actions: [
            IconButton(
              tooltip: 'تنظیمات اعلان‌ها',
              onPressed: onOpenSettings,
              icon: const Icon(CupertinoIcons.gear),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (overdue.isNotEmpty) _section(context, 'عقب‌افتاده', overdue, overdueTone: true),
            _section(context, 'امروز', today),
            _section(context, 'به‌زودی', upcoming),
            if (overdue.isEmpty && today.isEmpty && upcoming.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 72),
                child: Column(
                  children: [
                    Icon(CupertinoIcons.bell, size: 34, color: Theme.of(context).textTheme.bodyMedium?.color),
                    const SizedBox(height: 12),
                    const Text('اعلان جدیدی ندارید.'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<ZarNotificationItem> items, {
    bool overdueTone = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: overdueTone ? const Color(0xFF9D3636) : null,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => InkWell(
              onTap: () => onOpenRecord(item.recordId),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(top: 8, left: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.isUnread ? theme.colorScheme.primary : Colors.transparent,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(item.subtitle, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(item.timeLabel, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final ZarNotificationPreferences initial;
  final ValueChanged<ZarNotificationPreferences> onChanged;

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late ZarNotificationPreferences value = widget.initial;

  void _set(ZarNotificationPreferences next) {
    setState(() => value = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تنظیمات اعلان‌ها')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('اعلان‌ها'),
              subtitle: const Text('یادآوری‌های ZAR+ روی این دستگاه'),
              value: value.enabled,
              onChanged: (v) => _set(value.copyWith(enabled: v)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('صدا'),
              subtitle: const Text('کنترل نهایی صدا تابع تنظیمات و حالت‌های سیستم است.'),
              value: value.soundEnabled,
              onChanged: value.enabled ? (v) => _set(value.copyWith(soundEnabled: v)) : null,
            ),
            if (value.enabled && value.soundEnabled)
              _soundPicker(
                context,
                value: value.soundProfile,
                onChanged: (profile) => _set(value.copyWith(soundProfile: profile)),
              ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('ویبره'),
              subtitle: const Text('در دستگاه‌ها و حالت‌هایی که سیستم‌عامل پشتیبانی کند.'),
              value: value.vibrationEnabled,
              onChanged: value.enabled ? (v) => _set(value.copyWith(vibrationEnabled: v)) : null,
            ),
            const SizedBox(height: 18),
            Text('حریم خصوصی اعلان', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            ...NotificationPrivacy.values.map(
              (privacy) => RadioListTile<NotificationPrivacy>(
                contentPadding: EdgeInsets.zero,
                title: Text(_privacyTitle(privacy)),
                subtitle: Text(_privacyExample(privacy)),
                value: privacy,
                groupValue: value.privacy,
                onChanged: (v) {
                  if (v != null) _set(value.copyWith(privacy: v));
                },
              ),
            ),
            const SizedBox(height: 18),
            _minutesPicker(
              context,
              title: 'یادآوری پیش‌فرض',
              value: value.defaultReminderMinutes,
              values: const [15, 30, 60, 180, 1440],
              onChanged: (v) => _set(value.copyWith(defaultReminderMinutes: v)),
            ),
            const SizedBox(height: 12),
            _minutesPicker(
              context,
              title: 'اسنوز پیش‌فرض',
              value: value.defaultSnoozeMinutes,
              values: const [15, 30, 60, 180, 1440],
              onChanged: (v) => _set(value.copyWith(defaultSnoozeMinutes: v)),
            ),
            const SizedBox(height: 20),
            Text(
              'نوع صدا و ویبره در ZAR+ به‌عنوان ترجیح ذخیره می‌شود؛ حالت Silent، Focus و مجوزهای اعلان iPhone/Android همیشه اولویت نهایی را دارند.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _soundPicker(
    BuildContext context, {
    required NotificationSoundProfile value,
    required ValueChanged<NotificationSoundProfile> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('نوع صدا'),
      subtitle: Text(_soundLabel(value)),
      trailing: const Icon(CupertinoIcons.chevron_down, size: 18),
      onTap: () async {
        final selected = await showModalBottomSheet<NotificationSoundProfile>(
          context: context,
          useSafeArea: true,
          builder: (sheetContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: NotificationSoundProfile.values
                    .map(
                      (profile) => ListTile(
                        title: Text(_soundLabel(profile)),
                        subtitle: Text(_soundDescription(profile)),
                        trailing: profile == value ? const Icon(CupertinoIcons.check_mark) : null,
                        onTap: () => Navigator.pop(sheetContext, profile),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
        if (selected != null) onChanged(selected);
      },
    );
  }

  Widget _minutesPicker(
    BuildContext context, {
    required String title,
    required int value,
    required List<int> values,
    required ValueChanged<int> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(_minutesLabel(value)),
      trailing: const Icon(CupertinoIcons.chevron_down, size: 18),
      onTap: () async {
        final selected = await showModalBottomSheet<int>(
          context: context,
          useSafeArea: true,
          builder: (sheetContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: values
                    .map(
                      (minutes) => ListTile(
                        title: Text(_minutesLabel(minutes)),
                        trailing: minutes == value ? const Icon(CupertinoIcons.check_mark) : null,
                        onTap: () => Navigator.pop(sheetContext, minutes),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
        if (selected != null) onChanged(selected);
      },
    );
  }

  String _soundLabel(NotificationSoundProfile profile) {
    switch (profile) {
      case NotificationSoundProfile.systemDefault:
        return 'صدای پیش‌فرض سیستم';
      case NotificationSoundProfile.subtle:
        return 'ملایم';
      case NotificationSoundProfile.silent:
        return 'بی‌صدا';
    }
  }

  String _soundDescription(NotificationSoundProfile profile) {
    switch (profile) {
      case NotificationSoundProfile.systemDefault:
        return 'از صدای استاندارد اعلان دستگاه استفاده شود.';
      case NotificationSoundProfile.subtle:
        return 'در نسخه Native از صدای کوتاه‌تر ZAR+ استفاده شود، در صورت پشتیبانی.';
      case NotificationSoundProfile.silent:
        return 'اعلان نمایش داده شود ولی ZAR+ درخواست پخش صدا نکند.';
    }
  }

  String _privacyTitle(NotificationPrivacy privacy) {
    switch (privacy) {
      case NotificationPrivacy.full:
        return 'کامل';
      case NotificationPrivacy.limited:
        return 'محدود';
      case NotificationPrivacy.private:
        return 'خصوصی';
    }
  }

  String _privacyExample(NotificationPrivacy privacy) {
    switch (privacy) {
      case NotificationPrivacy.full:
        return 'ساعت ۱۱ باید مبلغ/مقدار مشخصی به شخص موردنظر تحویل دهید.';
      case NotificationPrivacy.limited:
        return 'ساعت ۱۱ یک تحویل برای شخص موردنظر دارید.';
      case NotificationPrivacy.private:
        return 'ساعت ۱۱ یک یادآوری کاری دارید.';
    }
  }

  String _minutesLabel(int minutes) {
    if (minutes == 1440) return '۱ روز';
    if (minutes == 180) return '۳ ساعت';
    if (minutes == 60) return '۱ ساعت';
    if (minutes == 30) return '۳۰ دقیقه';
    return '۱۵ دقیقه';
  }
}
