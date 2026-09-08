import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app/features/reminders/flutter_local_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'completing a record cancels its displayed tagged alarm, not another record',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final cancelled = <Map<dynamic, dynamic>>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'pendingNotificationRequests') return <Object>[];
        if (call.method == 'getActiveNotifications') {
          return [
            {'id': 7, 'tag': 'zar-record:r'},
            {'id': 8, 'tag': 'zar-record:other'},
          ];
        }
        if (call.method == 'cancel') {
          cancelled.add(call.arguments as Map<dynamic, dynamic>);
        }
        return null;
      });
      try {
        await FlutterLocalNotificationScheduler().cancelForRecord('r');
        expect(cancelled, hasLength(1));
        expect(cancelled.single['id'], 7);
        expect(cancelled.single['tag'], 'zar-record:r');
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  test(
    'each immutable Android sound vibration and mode profile is distinct',
    () {
      final profiles = <String>{};
      for (final alarm in [false, true]) {
        for (final sound in [false, true]) {
          for (final vibration in [false, true]) {
            final id = FlutterLocalNotificationScheduler.androidChannelId(
              alarm: alarm,
              sound: sound,
              vibration: vibration,
            );
            expect(profiles.add(id), isTrue);
            expect(id, contains('_v2_'));
            expect(
              FlutterLocalNotificationScheduler.androidChannelId(
                alarm: alarm,
                sound: sound,
                vibration: vibration,
              ),
              id,
            );
          }
        }
      }
      expect(profiles.length, 8);
    },
  );
}
