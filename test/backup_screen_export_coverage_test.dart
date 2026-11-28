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
  late _RecordingBackupFileService files;
  late ZarBackupManager manager;

  setUp(() {
    final repository = InMemoryZarDomainRepository();
    manager = ZarBackupManager(
      repository: repository,
      store: ZarPhaseA2Store(
        repository: repository,
        bridge: ZarLegacyPresentationBridge(
          businessId: 'w1',
          userId: 'test',
        ),
      ),
      businessId: 'w1',
      reconcileRemindersAfterRestore: () async {},
    );
    files = _RecordingBackupFileService();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    ZarAccountSection? account,
    VoidCallback? onOpenCoinCatalog,
    VoidCallback? onOpenCurrencyCatalog,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(
          manager: manager,
          files: files,
          account: account,
          onOpenCoinCatalog: onOpenCoinCatalog,
          onOpenCurrencyCatalog: onOpenCurrencyCatalog,
        ),
      ),
    );
  }

  testWidgets('save export writes JSON and shows success snackbar', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('ساخت و ذخیره نسخه پشتیبان'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(files.savedNames, isNotEmpty);
    expect(files.savedNames.single, contains('zar-plus-backup-'));
    expect(files.savedContents.single, contains('"businessId"'));
    expect(files.savedContents.single, contains('"w1"'));
    expect(find.text('نسخه پشتیبان ذخیره شد.'), findsOneWidget);
  });

  testWidgets('share export invokes shareJson and shows share snackbar', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('ساخت و اشتراک‌گذاری'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(files.sharedNames, isNotEmpty);
    expect(find.text('نسخه پشتیبان آماده اشتراک‌گذاری است.'), findsOneWidget);
  });

  testWidgets('import cancel leaves repository untouched', (tester) async {
    files.pickContents = const ZarDomainBackupCodec().encodeJson(
      ZarDomainBackupBundle(
        businessId: 'w1',
        generatedAt: DateTime.utc(2026, 11, 1),
        people: const [],
        deals: const [],
        settlements: const [],
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('انتخاب و بررسی فایل پشتیبان'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('بررسی نسخه پشتیبان'), findsOneWidget);

    await tester.tap(find.text('انصراف'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('بررسی نسخه پشتیبان'), findsNothing);
    expect(find.textContaining('بازیابی کامل شد'), findsNothing);
  });

  testWidgets('account card confirms sign-out', (tester) async {
    var signedOut = false;
    await pumpScreen(
      tester,
      account: ZarAccountSection(
        email: 'owner@example.com',
        serverUrl: 'https://app.titangold.ir',
        onSignOut: () async {
          signedOut = true;
        },
      ),
    );

    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.textContaining('app.titangold.ir'), findsOneWidget);

    await tester.tap(find.text('خروج از حساب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('خارج می‌شوید'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'خروج'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(signedOut, isTrue);
  });

  testWidgets('catalog buttons invoke callbacks', (tester) async {
    var coins = 0;
    var currencies = 0;
    await pumpScreen(
      tester,
      onOpenCoinCatalog: () => coins++,
      onOpenCurrencyCatalog: () => currencies++,
    );

    await tester.tap(find.text('مدیریت انواع سکه'));
    await tester.tap(find.text('مدیریت ارزها'));
    await tester.pump();

    expect(coins, 1);
    expect(currencies, 1);
  });

  testWidgets('invalid picked backup shows format snackbar', (tester) async {
    files.pickContents = '{not-json';
    await pumpScreen(tester);

    await tester.tap(find.text('انتخاب و بررسی فایل پشتیبان'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('فایل نسخه پشتیبان معتبر نیست یا اطلاعات ضروری آن ناقص است.'),
      findsOneWidget,
    );
  });
}

class _RecordingBackupFileService implements BackupFileService {
  final savedNames = <String>[];
  final savedContents = <String>[];
  final sharedNames = <String>[];
  String? pickContents;

  @override
  Future<String?> pickJson() async => pickContents;

  @override
  Future<bool> saveJson({
    required String fileName,
    required String contents,
  }) async {
    savedNames.add(fileName);
    savedContents.add(contents);
    return true;
  }

  @override
  Future<void> shareJson({
    required String fileName,
    required String contents,
  }) async {
    sharedNames.add(fileName);
  }
}
