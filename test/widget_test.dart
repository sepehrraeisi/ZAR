import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/data/zar_preview_repository.dart';
import 'package:flutter_app/repository_phase_a2_app_v2.dart';

void main() {
  testWidgets('repository-backed ZAR+ renders operational shell', (
    WidgetTester tester,
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
    expect(find.text('عقب‌افتاده'), findsWidgets);
    expect(find.text('رضا محمدی'), findsWidgets);
  });
}
