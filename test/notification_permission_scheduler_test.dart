import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app/features/reminders/flutter_local_notification_scheduler.dart';
import 'package:flutter_app/features/notifications/notification_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('scheduler maps native Android permission states', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const pluginChannel = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    const permissionChannel = MethodChannel('zarplus/notification_permission');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pluginChannel, (call) async {
      if (call.method == 'initialize') return true;
      return null;
    });
    messenger.setMockMethodCallHandler(permissionChannel, (call) async {
      if (call.method == 'getPermissionState') return {'status': 'disabled'};
      return null;
    });

    try {
      final state = await FlutterLocalNotificationScheduler()
          .readPermissionState();
      expect(state.status, ZarNotificationPermissionStatus.disabled);
      expect(state.isGranted, isFalse);
      expect(state.shouldOpenSettings, isTrue);
    } finally {
      messenger.setMockMethodCallHandler(pluginChannel, null);
      messenger.setMockMethodCallHandler(permissionChannel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('request re-reads Android state after the permission prompt', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const pluginChannel = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    const permissionChannel = MethodChannel('zarplus/notification_permission');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pluginChannel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'requestNotificationsPermission') return true;
      return null;
    });
    messenger.setMockMethodCallHandler(permissionChannel, (call) async {
      if (call.method == 'getPermissionState') return {'status': 'granted'};
      return null;
    });

    try {
      expect(
        await FlutterLocalNotificationScheduler().requestPermission(),
        isTrue,
      );
    } finally {
      messenger.setMockMethodCallHandler(pluginChannel, null);
      messenger.setMockMethodCallHandler(permissionChannel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
