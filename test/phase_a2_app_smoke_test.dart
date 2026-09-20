import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/zar_preview_repository.dart';
import 'package:flutter_app/repository_phase_a2_app_v2.dart';

void main() {
  testWidgets('live ZAR+ shell renders operational home and navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      RepositoryZarPlusAppV2(repository: buildPhaseA2PreviewRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-header-logo')), findsOneWidget);
    expect(find.text('خانه'), findsOneWidget);
    expect(find.text('تقویم'), findsOneWidget);
    expect(find.text('اشخاص'), findsOneWidget);
    expect(find.text('سوابق'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.bell), findsOneWidget);
    expect(find.text('عقب‌افتاده'), findsWidgets);
    expect(find.text('امروز'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('فردا'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('فردا'), findsOneWidget);
  });
}
