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
}
