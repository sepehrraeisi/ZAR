import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/notifications/notification_center.dart';
import 'package:flutter_app/features/notifications/notification_permission.dart';

void main() {
  test('permission state keeps OS status separate from app preference', () {
    const state = ZarNotificationPermissionState.granted();
    expect(state.isGranted, isTrue);
    expect(state.isRequestable, isFalse);
    expect(state.shouldOpenSettings, isFalse);
    expect(const ZarNotificationPermissionState.disabled().isGranted, isFalse);
    expect(
      const ZarNotificationPermissionState.disabled().shouldOpenSettings,
      isTrue,
    );
  });

  testWidgets('permission grant refreshes status without restarting screen', (
    tester,
  ) async {
    var state = const ZarNotificationPermissionState.notDetermined();
    var requests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsScreen(
          initial: const ZarNotificationPreferences(),
          onChanged: (_) {},
          onRequestPermission: () async {
            requests++;
            state = const ZarNotificationPermissionState.granted();
            return true;
          },
          onReadPermissionState: () async => state,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('فعال‌کردن'), findsOneWidget);
    await tester.tap(find.text('فعال‌کردن'));
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(find.text('فعال'), findsOneWidget);
    expect(find.text('فعال‌کردن'), findsNothing);
  });

  testWidgets('denied or system-disabled state opens app settings', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsScreen(
          initial: const ZarNotificationPreferences(),
          onChanged: (_) {},
          onRequestPermission: () async => false,
          onOpenSystemSettings: () async {
            opens++;
            return true;
          },
          onReadPermissionState: () async =>
              const ZarNotificationPermissionState.disabled(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('اعلان‌های این برنامه در تنظیمات سیستم غیرفعال است.'),
      findsOneWidget,
    );
    expect(find.text('باز کردن تنظیمات'), findsOneWidget);
    await tester.tap(find.text('باز کردن تنظیمات'));
    await tester.pump();
    expect(opens, 1);
  });

  testWidgets('permission state is refreshed when app resumes', (tester) async {
    var state = const ZarNotificationPermissionState.notDetermined();
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsScreen(
          initial: const ZarNotificationPreferences(),
          onChanged: (_) {},
          onRequestPermission: () async => false,
          onReadPermissionState: () async => state,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('فعال‌کردن'), findsOneWidget);

    state = const ZarNotificationPermissionState.granted();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('فعال'), findsOneWidget);
    expect(find.text('فعال‌کردن'), findsNothing);
  });

  testWidgets(
    'master off preserves values while dependent controls are inert',
    (tester) async {
      ZarNotificationPreferences? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            initial: const ZarNotificationPreferences(enabled: false),
            onChanged: (value) => changed = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('رفتار یادآوری'), findsOneWidget);
      await tester.tap(find.text('اعلان معمولی'), warnIfMissed: false);
      await tester.pump();
      expect(changed, isNull);
    },
  );

  testWidgets('a stale OS read cannot overwrite a newer resume result', (
    tester,
  ) async {
    final oldRead = Completer<ZarNotificationPermissionState>();
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsScreen(
          initial: const ZarNotificationPreferences(),
          onChanged: (_) {},
          onRequestPermission: () async => false,
          onReadPermissionState: () => ++reads == 1
              ? oldRead.future
              : Future.value(const ZarNotificationPermissionState.granted()),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    oldRead.complete(const ZarNotificationPermissionState.denied());
    await tester.pumpAndSettle();
    expect(find.text('فعال'), findsOneWidget);
    expect(find.text('باز کردن تنظیمات'), findsNothing);
  });

  testWidgets('sound and master dependencies preserve saved selections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsScreen(
          initial: const ZarNotificationPreferences(
            soundEnabled: false,
            soundProfile: NotificationSoundProfile.subtle,
          ),
          onChanged: (_) {},
        ),
      ),
    );
    final soundType = find.widgetWithText(ListTile, 'نوع صدا');
    await tester.scrollUntilVisible(soundType, 200);
    expect(tester.widget<ListTile>(soundType).onTap, isNull);
    final sound = find.widgetWithText(SwitchListTile, 'صدا');
    tester.widget<SwitchListTile>(sound).onChanged!(true);
    await tester.pump();
    expect(tester.widget<ListTile>(soundType).onTap, isNotNull);
    expect(find.text('ملایم'), findsOneWidget);
    final master = find.widgetWithText(SwitchListTile, 'اعلان‌ها');
    await tester.scrollUntilVisible(master, -300);
    tester.widget<SwitchListTile>(master).onChanged!(false);
    await tester.pump();
    await tester.scrollUntilVisible(soundType, 200);
    expect(tester.widget<ListTile>(soundType).onTap, isNull);
    expect(tester.widget<SwitchListTile>(sound).value, isTrue);
    expect(tester.widget<SwitchListTile>(sound).onChanged, isNull);
  });
}
