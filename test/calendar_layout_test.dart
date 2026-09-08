import 'package:flutter/material.dart';
import 'package:flutter_app/app_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  testWidgets('calendar lays out the complete Jalali month on a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: CalendarScreen(
              records: const [],
              personName: (_) => '',
              onTapRecord: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gridRect = tester.getRect(
      find.byKey(const ValueKey('calendar-month-grid')),
    );
    final lastDay = Jalali.now().monthLength;
    final lastDayRect = tester.getRect(
      find.byKey(ValueKey('calendar-day-$lastDay')),
    );

    expect(find.byKey(const ValueKey('calendar-day-1')), findsOneWidget);
    expect(lastDayRect.bottom, lessThanOrEqualTo(gridRect.bottom));
    expect(tester.takeException(), isNull);
  });
}
