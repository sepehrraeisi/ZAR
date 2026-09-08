import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../domain/zar_reminder_plan.dart';

/// Runtime reminder rule used by the delivery/scheduling layer.
enum ReminderRuleType { offset, custom }

class ReminderRule {
  const ReminderRule.offset({
    required this.id,
    required this.minutesBefore,
    this.enabled = true,
  })  : type = ReminderRuleType.offset,
        customAt = null;

  const ReminderRule.custom({
    required this.id,
    required this.customAt,
    this.enabled = true,
  })  : type = ReminderRuleType.custom,
        minutesBefore = null;

  final String id;
  final ReminderRuleType type;
  final int? minutesBefore;
  final DateTime? customAt;
  final bool enabled;

  ReminderRule copyWith({bool? enabled}) {
    if (type == ReminderRuleType.offset) {
      return ReminderRule.offset(
        id: id,
        minutesBefore: minutesBefore!,
        enabled: enabled ?? this.enabled,
      );
    }
    return ReminderRule.custom(
      id: id,
      customAt: customAt!,
      enabled: enabled ?? this.enabled,
    );
  }

  DateTime? resolve(DateTime dueAt) {
    if (!enabled) return null;
    if (type == ReminderRuleType.custom) return customAt;
    return dueAt.subtract(Duration(minutes: minutesBefore!));
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'minutesBefore': minutesBefore,
        'customAt': customAt?.toUtc().toIso8601String(),
        'enabled': enabled,
      };

  factory ReminderRule.fromMap(Map<String, Object?> map) {
    final type = ReminderRuleType.values.byName(map['type']! as String);
    if (type == ReminderRuleType.offset) {
      return ReminderRule.offset(
        id: map['id']! as String,
        minutesBefore: map['minutesBefore']! as int,
        enabled: map['enabled'] as bool? ?? true,
      );
    }
    return ReminderRule.custom(
      id: map['id']! as String,
      customAt: DateTime.parse(map['customAt']! as String).toLocal(),
      enabled: map['enabled'] as bool? ?? true,
    );
  }
}

class ReminderPlan {
  const ReminderPlan({
    this.rules = const [],
    this.snoozedUntil,
  });

  final List<ReminderRule> rules;
  final DateTime? snoozedUntil;

  ReminderPlan copyWith({
    List<ReminderRule>? rules,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
  }) {
    return ReminderPlan(
      rules: rules ?? this.rules,
      snoozedUntil: clearSnooze ? null : (snoozedUntil ?? this.snoozedUntil),
    );
  }

  List<DateTime> resolveTimes(DateTime dueAt) {
    final times = <DateTime>{};
    for (final rule in rules) {
      final resolved = rule.resolve(dueAt);
      if (resolved != null) times.add(resolved);
    }
    if (snoozedUntil != null) times.add(snoozedUntil!);
    final sorted = times.toList()..sort();
    return sorted;
  }

  Map<String, Object?> toMap() => {
        'rules': rules.map((e) => e.toMap()).toList(growable: false),
        'snoozedUntil': snoozedUntil?.toUtc().toIso8601String(),
      };

  factory ReminderPlan.fromMap(Map<String, Object?> map) {
    final rawRules = map['rules'] as List<Object?>? ?? const [];
    return ReminderPlan(
      rules: rawRules
          .map((e) => ReminderRule.fromMap(Map<String, Object?>.from(e! as Map)))
          .toList(growable: false),
      snoozedUntil: map['snoozedUntil'] == null
          ? null
          : DateTime.parse(map['snoozedUntil']! as String).toLocal(),
    );
  }
}

/// Converts a persisted business reminder plan into the runtime scheduler model.
ReminderPlan reminderPlanFromDomain(ZarReminderPlan plan) => ReminderPlan(
      rules: plan.rules
          .map((rule) => rule.type == ZarReminderRuleType.offset
              ? ReminderRule.offset(
                  id: rule.id,
                  minutesBefore: rule.minutesBefore!,
                  enabled: rule.enabled,
                )
              : ReminderRule.custom(
                  id: rule.id,
                  customAt: rule.customAt!.toLocal(),
                  enabled: rule.enabled,
                ))
          .toList(growable: false),
      snoozedUntil: plan.snoozedUntil?.toLocal(),
    );

/// Converts the runtime scheduler model back into persistence-safe domain data.
ZarReminderPlan reminderPlanToDomain(ReminderPlan plan) => ZarReminderPlan(
      rules: plan.rules
          .map((rule) => rule.type == ReminderRuleType.offset
              ? ZarReminderRule.offset(
                  id: rule.id,
                  minutesBefore: rule.minutesBefore!,
                  enabled: rule.enabled,
                )
              : ZarReminderRule.custom(
                  id: rule.id,
                  customAt: rule.customAt!.toUtc(),
                  enabled: rule.enabled,
                ))
          .toList(growable: false),
      snoozedUntil: plan.snoozedUntil?.toUtc(),
    );

/// Converts a Jalali business date plus optional local time into a canonical
/// local DateTime. Firestore persistence should convert this to UTC/Timestamp.
DateTime dueDateTimeFromJalali(Jalali date, TimeOfDay? time) {
  final gregorian = date.toGregorian();
  return DateTime(
    gregorian.year,
    gregorian.month,
    gregorian.day,
    time?.hour ?? 9,
    time?.minute ?? 0,
  );
}

String reminderPresetLabel(int minutes) => switch (minutes) {
  15 => '۱۵ دقیقه',
  30 => '۳۰ دقیقه',
  60 => '۱ ساعت',
  180 => '۳ ساعت',
  1440 => '۱ روز',
  _ => '۳۰ دقیقه',
};

DateTime? snoozePresetDateTime(
  String label,
  DateTime now, {
  TimeOfDay? tomorrowTime,
}) {
  if (label.trim() == 'فردا') {
    final tomorrow = now.add(const Duration(days: 1));
    final time = tomorrowTime ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      time.hour,
      time.minute,
    );
  }
  final minutes = switch (label.trim()) {
    '۱۵ دقیقه' => 15,
    '۳۰ دقیقه' => 30,
    '۱ ساعت' => 60,
    '۳ ساعت' => 180,
    '۱ روز' => 1440,
    _ => null,
  };
  return minutes == null ? null : now.add(Duration(minutes: minutes));
}

/// Transitional adapter for the existing Quick Add UI. The UI can continue
/// displaying Persian labels while the domain layer stores structured rules.
ReminderPlan reminderPlanFromLegacyLabel(String label) {
  final normalized = label.trim();
  final minutes = switch (normalized) {
    '۱۵ دقیقه قبل' || '۱۵ دقیقه' => 15,
    '۳۰ دقیقه قبل' || '۳۰ دقیقه' => 30,
    '۱ ساعت قبل' || '۱ ساعت' => 60,
    '۳ ساعت قبل' || '۳ ساعت' => 180,
    '۱ روز قبل' || '۱ روز' => 1440,
    _ => null,
  };
  if (minutes == null) return const ReminderPlan();
  return ReminderPlan(
    rules: [ReminderRule.offset(id: 'default-$minutes', minutesBefore: minutes)],
  );
}

String reminderRulePersianLabel(ReminderRule rule) {
  if (rule.type == ReminderRuleType.custom) return 'سفارشی';
  return switch (rule.minutesBefore) {
    15 => '۱۵ دقیقه قبل',
    30 => '۳۰ دقیقه قبل',
    60 => '۱ ساعت قبل',
    180 => '۳ ساعت قبل',
    1440 => '۱ روز قبل',
    final value => '$value دقیقه قبل',
  };
}
