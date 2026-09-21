import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/application/zar_auto_backup.dart';
import 'package:flutter_app/application/zar_backup_manager.dart';
import 'package:flutter_app/application/zar_legacy_presentation_bridge.dart';
import 'package:flutter_app/application/zar_phase_a2_store.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';

void main() {
  late Directory directory;
  late DateTime now;

  ZarBackupManager manager(ZarDomainRepository repository) => ZarBackupManager(
    repository: repository,
    store: ZarPhaseA2Store(
      repository: repository,
      bridge: const ZarLegacyPresentationBridge(
        businessId: 'test-business',
        userId: 'test-user',
      ),
    ),
    businessId: 'test-business',
    reconcileRemindersAfterRestore: () async {},
  );

  ZarAutoBackupCoordinator coordinator(ZarDomainRepository repository) =>
      ZarAutoBackupCoordinator(
        backupManager: manager(repository),
        directory: directory,
        keep: 2,
        minInterval: const Duration(hours: 12),
        clock: () => now,
      );

  Future<ZarDomainRepository> seededRepository() async {
    final repository = InMemoryZarDomainRepository();
    await repository.savePerson(
      ZarPerson(
        id: 'p1',
        displayName: 'مشتری',
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
        createdBy: 'test',
      ),
    );
    return repository;
  }

  setUp(() {
    directory = Directory.systemTemp.createTempSync('zar-auto-backup-test');
    now = DateTime.utc(2026, 9, 21, 10);
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  test('writes the first backup immediately', () async {
    final file = await coordinator(await seededRepository()).runIfNeeded();
    expect(file, isNotNull);
    expect(file!.existsSync(), isTrue);
    expect(file.path, contains('zar-auto-backup-'));
    expect(file.readAsStringSync(), contains('"businessId"'));
  });

  test('skips while the newest backup is fresh enough', () async {
    final repository = await seededRepository();
    final coordinatorRef = coordinator(repository);
    await coordinatorRef.runIfNeeded();

    now = now.add(const Duration(hours: 1));
    final second = await coordinatorRef.runIfNeeded();
    expect(second, isNull);
    expect(directory.listSync().length, 1);
  });

  test('writes again after the interval passes', () async {
    final repository = await seededRepository();
    final coordinatorRef = coordinator(repository);
    await coordinatorRef.runIfNeeded();

    now = now.add(const Duration(hours: 13));
    final second = await coordinatorRef.runIfNeeded();
    expect(second, isNotNull);
    expect(directory.listSync().length, 2);
  });

  test('prunes beyond the rolling keep window', () async {
    final repository = await seededRepository();
    final coordinatorRef = coordinator(repository);
    await coordinatorRef.runIfNeeded();
    for (var i = 0; i < 4; i++) {
      now = now.add(const Duration(hours: 13));
      await coordinatorRef.runIfNeeded();
    }
    final remaining = directory.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(remaining, hasLength(2));
    expect(remaining.first.path, contains('20260923T'));
  });

  test('failures are reported through onError, never thrown', () async {
    final repository = await seededRepository();
    final failingManager = ZarBackupManager(
      repository: _FailingRepository(),
      store: ZarPhaseA2Store(
        repository: repository,
        bridge: const ZarLegacyPresentationBridge(
        businessId: 'test-business',
        userId: 'test-user',
      ),
      ),
      businessId: 'test-business',
      reconcileRemindersAfterRestore: () async {},
    );
    Object? reported;
    final coordinatorRef = ZarAutoBackupCoordinator(
      backupManager: failingManager,
      directory: directory,
      clock: () => now,
      onError: (error) => reported = error,
    );
    final file = await coordinatorRef.runIfNeeded();
    expect(file, isNull);
    expect(reported, isNotNull);
  });
}

class _FailingRepository extends InMemoryZarDomainRepository {
  @override
  Future<ZarDomainSnapshot> loadCompleteSnapshot() async {
    throw StateError('load failed');
  }
}
