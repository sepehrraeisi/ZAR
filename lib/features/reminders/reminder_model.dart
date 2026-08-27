import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// A reminder rule is stored independently from UI labels so it can later be
/// persisted in Firestore and scheduled through native notification services.
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

/// Transitional adapter for the existing mock-data Quick Add UI. The UI can
/// continue displaying Persian labels while the domain layer uses structured
/// minute offsets.
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
