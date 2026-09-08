/// Persistence-safe reminder data owned by the business domain.
///
/// This file deliberately has no Flutter imports. Native/local notification
/// scheduling is a delivery concern; the selected reminder plan belongs to the
/// settlement so it survives restart, backup/restore and device replacement.
enum ZarReminderRuleType { offset, custom }

class ZarReminderRule {
  const ZarReminderRule.offset({
    required this.id,
    required this.minutesBefore,
    this.enabled = true,
  })  : type = ZarReminderRuleType.offset,
        customAt = null;

  const ZarReminderRule.custom({
    required this.id,
    required this.customAt,
    this.enabled = true,
  })  : type = ZarReminderRuleType.custom,
        minutesBefore = null;

  final String id;
  final ZarReminderRuleType type;
  final int? minutesBefore;
  final DateTime? customAt;
  final bool enabled;

  DateTime? resolve(DateTime dueAt) {
    if (!enabled) return null;
    if (type == ZarReminderRuleType.custom) return customAt;
    return dueAt.subtract(Duration(minutes: minutesBefore!));
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'minutesBefore': minutesBefore,
        'customAt': customAt?.toUtc().toIso8601String(),
        'enabled': enabled,
      };

  factory ZarReminderRule.fromMap(Map<String, Object?> map) {
    final type = ZarReminderRuleType.values.byName(map['type']! as String);
    if (type == ZarReminderRuleType.offset) {
      return ZarReminderRule.offset(
        id: map['id']! as String,
        minutesBefore: map['minutesBefore']! as int,
        enabled: map['enabled'] as bool? ?? true,
      );
    }
    return ZarReminderRule.custom(
      id: map['id']! as String,
      customAt: DateTime.parse(map['customAt']! as String).toUtc(),
      enabled: map['enabled'] as bool? ?? true,
    );
  }
}

class ZarReminderPlan {
  const ZarReminderPlan({
    this.rules = const [],
    this.snoozedUntil,
  });

  final List<ZarReminderRule> rules;
  final DateTime? snoozedUntil;

  bool get isEmpty => rules.isEmpty && snoozedUntil == null;

  ZarReminderPlan copyWith({
    List<ZarReminderRule>? rules,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
  }) =>
      ZarReminderPlan(
        rules: rules ?? this.rules,
        snoozedUntil: clearSnooze ? null : (snoozedUntil ?? this.snoozedUntil),
      );

  /// Adds or re-enables one offset reminder without creating duplicate offsets.
  ZarReminderPlan withOffset(int minutesBefore) {
    if (minutesBefore <= 0) {
      throw const FormatException('Reminder offset must be greater than zero.');
    }
    final retained = rules
        .where(
          (rule) =>
              rule.type != ZarReminderRuleType.offset ||
              rule.minutesBefore != minutesBefore,
        )
        .toList(growable: true);
    retained.add(
      ZarReminderRule.offset(
        id: 'offset-$minutesBefore',
        minutesBefore: minutesBefore,
      ),
    );
    return copyWith(rules: retained);
  }

  ZarReminderPlan withoutOffset(int minutesBefore) => copyWith(
        rules: rules
            .where(
              (rule) =>
                  rule.type != ZarReminderRuleType.offset ||
                  rule.minutesBefore != minutesBefore,
            )
            .toList(growable: false),
      );

  /// Adds a custom reminder with a stable unique identifier.
  ZarReminderPlan withCustom(DateTime customAt, {String? id}) {
    final utc = customAt.toUtc();
    final ruleId = id ?? 'custom-${utc.microsecondsSinceEpoch}';
    return copyWith(
      rules: [
        ...rules.where((rule) => rule.id != ruleId),
        ZarReminderRule.custom(id: ruleId, customAt: utc),
      ],
    );
  }

  ZarReminderPlan withoutRule(String ruleId) => copyWith(
        rules: rules.where((rule) => rule.id != ruleId).toList(growable: false),
      );

  List<DateTime> resolveTimes(DateTime dueAt) {
    final times = <DateTime>{};
    for (final rule in rules) {
      final resolved = rule.resolve(dueAt);
      if (resolved != null) times.add(resolved.toUtc());
    }
    if (snoozedUntil != null) times.add(snoozedUntil!.toUtc());
    final sorted = times.toList()..sort();
    return sorted;
  }

  Map<String, Object?> toMap() => {
        'rules': rules.map((rule) => rule.toMap()).toList(growable: false),
        'snoozedUntil': snoozedUntil?.toUtc().toIso8601String(),
      };

  factory ZarReminderPlan.fromMap(Map<String, Object?>? map) {
    if (map == null || map.isEmpty) return const ZarReminderPlan();
    final rawRules = map['rules'] as List<Object?>? ?? const [];
    return ZarReminderPlan(
      rules: rawRules
          .map((raw) => ZarReminderRule.fromMap(
                Map<String, Object?>.from(raw! as Map),
              ))
          .toList(growable: false),
      snoozedUntil: map['snoozedUntil'] == null
          ? null
          : DateTime.parse(map['snoozedUntil']! as String).toUtc(),
    );
  }
}
