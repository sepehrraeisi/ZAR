import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main_phase_a2.dart';

void main() {
  testWidgets('promoted Phase A2 app renders operational home and navigation', (tester) async {
    await tester.pumpWidget(const ZarPlusPhaseA2App());
    await tester.pumpAndSettle();

    expect(find.text('ZAR+'), findsOneWidget);
    expect(find.text('خانه'), findsOneWidget);
    expect(find.text('تقویم'), findsOneWidget);
    expect(find.text('اشخاص'), findsOneWidget);
    expect(find.text('سوابق'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.bell), findsOneWidget);
    expect(find.text('عقب‌افتاده'), findsOneWidget);
    expect(find.text('امروز'), findsWidgets);
    expect(find.text('فردا'), findsOneWidget);
  });
}
