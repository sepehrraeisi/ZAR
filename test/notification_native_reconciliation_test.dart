import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app/features/reminders/flutter_local_notification_scheduler.dart';
import 'package:flutter_app/features/reminders/reminder_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<int, Map<dynamic, dynamic>> pending;
  late List<Map<String, Object?>> active;
  late List<String> calls;
  Completer<void>? scheduleGate;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    pending = {};
    active = [];
    calls = [];
    scheduleGate = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'initialize') return true;
      if (call.method == 'pendingNotificationRequests') {
        return pending.values.toList();
      }
      if (call.method == 'getActiveNotifications') return active;
      if (call.method == 'zonedSchedule') {
        await scheduleGate?.future;
        final args = Map<dynamic, dynamic>.from(call.arguments as Map);
        pending[args['id'] as int] = args;
      }
      if (call.method == 'cancel') {
        final args = call.arguments as Map;
        pending.remove(args['id']);
        active.removeWhere(
          (item) => item['id'] == args['id'] && item['tag'] == args['tag'],
        );
      }
      if (call.method == 'cancelAll' ||
          call.method == 'cancelAllPendingNotifications') {
        pending.clear();
        if (call.method == 'cancelAll') active.clear();
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  final due = DateTime.now().add(const Duration(days: 30));
  Future<void> schedule(
    FlutterLocalNotificationScheduler scheduler, {
    DateTime? at,
    String body = 'محتوای کامل',
    DateTime? snooze,
  }) => scheduler.replaceForRecord(
    recordId: 'qa',
    dueAt: due,
    plan: ReminderPlan(
      rules: [ReminderRule.custom(id: 'custom', customAt: at ?? due)],
      snoozedUntil: snooze,
    ),
    title: 'QA',
    body: body,
  );

  test(
    'replace, reschedule and cold reconstruction retain one stable schedule',
    () async {
      var scheduler = FlutterLocalNotificationScheduler();
      await schedule(scheduler);
      final firstId = pending.keys.single;
      await schedule(scheduler);
      expect(pending.keys.single, firstId);
      scheduler = FlutterLocalNotificationScheduler();
      await schedule(scheduler);
      expect(pending.keys.single, firstId);
      await schedule(scheduler, at: due.add(const Duration(hours: 1)));
      expect(pending.length, 1);
      expect(pending.keys.single, isNot(firstId));
      expect(await scheduler.pendingForRecord('qa'), hasLength(1));
    },
  );

  test(
    'completion queued during a schedule cancels it after native write',
    () async {
      final scheduler = FlutterLocalNotificationScheduler();
      scheduleGate = Completer<void>();
      final write = schedule(scheduler);
      final cancel = scheduler.cancelForRecord('qa');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      scheduleGate!.complete();
      await Future.wait([write, cancel]);
      expect(pending, isEmpty);
      expect(calls.last, 'getActiveNotifications');
    },
  );

  test(
    'startup rebuild retains an unchanged delivered persistent notification',
    () async {
      var scheduler = FlutterLocalNotificationScheduler(persistentAlarm: true);
      await schedule(scheduler);
      active.add({
        'id': pending.keys.single,
        'tag': 'zar-record:qa',
        'title': 'QA',
        'body': 'محتوای کامل',
      });
      pending.clear();
      scheduler = FlutterLocalNotificationScheduler(persistentAlarm: true);
      await scheduler.configure(
        enabled: true,
        playSound: true,
        enableVibration: true,
        persistentAlarm: true,
      );
      await schedule(scheduler);
      expect(active, hasLength(1));
      await scheduler.cancelForRecord('qa');
      expect(active, isEmpty);
      expect(pending, isEmpty);
    },
  );

  test(
    'master off clears displayed persistent notifications and pending queue',
    () async {
      final scheduler = FlutterLocalNotificationScheduler(
        persistentAlarm: true,
      );
      await schedule(scheduler);
      active.add({'id': pending.keys.single, 'tag': 'zar-record:qa'});
      await scheduler.configure(
        enabled: false,
        playSound: true,
        enableVibration: true,
      );
      expect(pending, isEmpty);
      expect(active, isEmpty);
      await schedule(scheduler);
      expect(pending, isEmpty);
      await scheduler.configure(
        enabled: true,
        playSound: true,
        enableVibration: true,
      );
      expect(pending.length, 1);
    },
  );

  test(
    'new snooze replaces previous snooze and leaves dueAt unchanged',
    () async {
      final scheduler = FlutterLocalNotificationScheduler();
      await schedule(
        scheduler,
        at: DateTime.now().subtract(const Duration(hours: 1)),
        snooze: due,
      );
      final first = pending.keys.single;
      await schedule(
        scheduler,
        at: DateTime.now().subtract(const Duration(hours: 1)),
        snooze: due.add(const Duration(minutes: 30)),
      );
      expect(pending.length, 1);
      expect(pending.keys.single, isNot(first));
      expect(
        (await scheduler.pendingForRecord('qa')).single.scheduledAt,
        due.add(const Duration(minutes: 30)),
      );
    },
  );

  test(
    'privacy replacement removes old native content without extra schedule',
    () async {
      final scheduler = FlutterLocalNotificationScheduler();
      await schedule(scheduler);
      active.add({'id': pending.keys.single, 'tag': 'zar-record:qa'});
      await schedule(scheduler, body: 'یک یادآوری کاری دارید.');
      expect(active, isEmpty);
      expect(pending.length, 1);
      expect(pending.values.single['body'], 'یک یادآوری کاری دارید.');
    },
  );

  test(
    'normal and persistent modes keep inexact one-shot delivery semantics',
    () async {
      final scheduler = FlutterLocalNotificationScheduler();
      await schedule(scheduler);
      var android = pending.values.single['platformSpecifics'] as Map;
      expect(android['ongoing'], false);
      expect(android['autoCancel'], true);
      expect(pending.values.single['matchDateTimeComponents'], isNull);
      await scheduler.configure(
        enabled: true,
        playSound: false,
        enableVibration: false,
        persistentAlarm: true,
      );
      android = pending.values.single['platformSpecifics'] as Map;
      expect(android['ongoing'], true);
      expect(android['autoCancel'], false);
      expect(android['playSound'], false);
      expect(android['enableVibration'], false);
      expect(pending.length, 1);
    },
  );
}
