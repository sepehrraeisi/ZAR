import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/application/zar_backup_manager.dart';
import 'package:flutter_app/application/zar_legacy_presentation_bridge.dart';
import 'package:flutter_app/application/zar_phase_a2_store.dart';
import 'package:flutter_app/data/zar_domain_backup_codec.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/features/backup/backup_file_service.dart';
import 'package:flutter_app/features/backup/backup_screen.dart';

void main() {
  testWidgets('cash restore guard is shown as a blocking actionable dialog', (
    tester,
  ) async {
    final repository = _CashBlockedRepository();
    final manager = ZarBackupManager(
      repository: repository,
      store: ZarPhaseA2Store(
        repository: repository,
        bridge: const ZarLegacyPresentationBridge(
          businessId: 'w1',
          userId: 'test',
        ),
      ),
      businessId: 'w1',
      reconcileRemindersAfterRestore: () async {},
    );
    final backup = const ZarDomainBackupCodec().encodeJson(
      ZarDomainBackupBundle(
        businessId: 'w1',
        generatedAt: DateTime.utc(2026, 11, 1),
        people: const [],
        deals: const [],
        settlements: const [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(
          manager: manager,
          files: _PickedBackupFileService(backup),
        ),
      ),
    );

    await tester.tap(find.text('انتخاب و بررسی فایل پشتیبان'));
    await _pumpDialogTransition(tester);
    expect(find.text('بررسی نسخه پشتیبان'), findsOneWidget);

    await tester.tap(find.text('جایگزینی و بازیابی'));
    await _pumpDialogTransition(tester);

    expect(find.text('بازیابی صندوق متوقف شد'), findsOneWidget);
    expect(find.textContaining('فقط‌افزودنی'), findsOneWidget);
    expect(find.textContaining('فایل پشتیبان را نگه دارید'), findsOneWidget);
    expect(find.textContaining('فضای کاری جدید و خالی'), findsOneWidget);
    expect(find.text('متوجه شدم'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.text('بازیابی صندوق متوقف شد'), findsOneWidget);

    await tester.tap(find.text('متوجه شدم'));
    await _pumpDialogTransition(tester);
    expect(find.text('بازیابی صندوق متوقف شد'), findsNothing);
  });
}

Future<void> _pumpDialogTransition(WidgetTester tester) async {
  // The screen intentionally keeps a progress indicator active while either
  // dialog is open, so pumpAndSettle cannot become idle until acknowledgement.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _CashBlockedRepository extends InMemoryZarDomainRepository {
  @override
  Future<void> replaceCompleteSnapshot(ZarDomainSnapshot snapshot) async {
    throw const ZarCloudRestoreException.appendOnlyCashHistory();
  }
}

class _PickedBackupFileService implements BackupFileService {
  const _PickedBackupFileService(this.contents);

  final String contents;

  @override
  Future<String?> pickJson() async => contents;

  @override
  Future<bool> saveJson({
    required String fileName,
    required String contents,
  }) async => true;

  @override
  Future<void> shareJson({
    required String fileName,
    required String contents,
  }) async {}
}
