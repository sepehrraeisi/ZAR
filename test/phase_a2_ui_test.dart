import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/notifications/notification_center.dart';
import 'package:flutter_app/features/people/archived_people_screen.dart';

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('fa', 'IR'),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void main() {
  testWidgets('notification center shows Persian sections and settings action', (tester) async {
    await tester.pumpWidget(
      _host(
        NotificationCenterScreen(
          overdue: const [
            ZarNotificationItem(
              id: 'n1',
              recordId: 's1',
              title: 'تحویل • رضا محمدی',
              subtitle: r'$10,000',
              timeLabel: '۱۱:۰۰',
              isOverdue: true,
            ),
          ],
          today: const [],
          upcoming: const [],
          onOpenRecord: (_) {},
          onOpenSettings: () {},
        ),
      ),
    );

    expect(find.text('اعلان‌ها'), findsOneWidget);
    expect(find.text('عقب‌افتاده'), findsOneWidget);
    expect(find.text('تحویل • رضا محمدی'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsNothing); // Cupertino gear is used instead.
  });

  testWidgets('notification settings expose core controls and sound profile', (tester) async {
    ZarNotificationPreferences? changed;
    await tester.pumpWidget(
      _host(
        NotificationSettingsScreen(
          initial: const ZarNotificationPreferences(),
          onChanged: (value) => changed = value,
        ),
      ),
    );

    expect(find.text('تنظیمات اعلان‌ها'), findsOneWidget);
    expect(find.text('اعلان‌ها'), findsOneWidget);
    expect(find.text('صدا'), findsOneWidget);
    expect(find.text('نوع صدا'), findsOneWidget);
    expect(find.text('صدای پیش‌فرض سیستم'), findsOneWidget);
    expect(find.text('ویبره'), findsOneWidget);
    expect(find.text('حریم خصوصی اعلان'), findsOneWidget);

    await tester.tap(find.text('نوع صدا'));
    await tester.pumpAndSettle();
    expect(find.text('ملایم'), findsOneWidget);
    expect(find.text('بی‌صدا'), findsOneWidget);

    await tester.tap(find.text('ملایم'));
    await tester.pumpAndSettle();
    expect(changed?.soundProfile, NotificationSoundProfile.subtle);
  });

  testWidgets('archived people can be restored from visible archive list', (tester) async {
    String? restored;
    await tester.pumpWidget(
      _host(
        ArchivedPeopleScreen(
          people: const [
            ArchivedPersonViewData(
              id: 'p1',
              name: 'علی رضایی',
              phone: '۰۹۱۲۱۲۳۴۵۶۷',
              openObligations: 2,
            ),
          ],
          onOpenPerson: (_) {},
          onRestore: (id) => restored = id,
        ),
      ),
    );

    expect(find.text('اشخاص بایگانی‌شده'), findsOneWidget);
    expect(find.text('علی رضایی'), findsOneWidget);
    expect(find.text('۲ تعهد باز دارد'), findsOneWidget);
    expect(find.text('بازگردانی'), findsOneWidget);

    await tester.tap(find.text('بازگردانی'));
    expect(restored, 'p1');
  });
}
