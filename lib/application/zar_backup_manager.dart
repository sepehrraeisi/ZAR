import '../data/zar_domain_backup_codec.dart';
import '../data/zar_domain_repository.dart';
import 'zar_phase_a2_store.dart';

class ZarBackupPreview {
  const ZarBackupPreview(this.bundle);

  final ZarDomainBackupBundle bundle;

  int get peopleCount => bundle.people.length;
  int get archivedPeopleCount =>
      bundle.people.where((person) => person.archived).length;
  int get dealCount => bundle.deals.length;
  int get settlementCount => bundle.settlements.length;
  int get settlementReminderCount => bundle.settlements
      .where((settlement) => !settlement.reminderPlan.isEmpty)
      .length;
  int get reminderRuleCount => bundle.settlements.fold(
    0,
    (sum, settlement) => sum + settlement.reminderPlan.rules.length,
  );
}

class ZarRestoreReminderException implements Exception {
  const ZarRestoreReminderException(this.cause);
  final Object cause;
}

class ZarBackupManager {
  ZarBackupManager({
    required ZarDomainRepository repository,
    required ZarPhaseA2Store store,
    required String businessId,
    required Future<void> Function() reconcileRemindersAfterRestore,
    ZarDomainBackupCodec codec = const ZarDomainBackupCodec(),
    DateTime Function()? clock,
  }) : _repository = repository,
       _store = store,
       _businessId = businessId,
       _reconcileRemindersAfterRestore = reconcileRemindersAfterRestore,
       _codec = codec,
       _clock = clock ?? DateTime.now;

  final ZarDomainRepository _repository;
  final ZarPhaseA2Store _store;
  final String _businessId;
  final Future<void> Function() _reconcileRemindersAfterRestore;
  final ZarDomainBackupCodec _codec;
  final DateTime Function() _clock;

  Future<String> createJson() async {
    final snapshot = await _repository.loadCompleteSnapshot();
    return _codec.encodeJson(
      ZarDomainBackupBundle(
        businessId: _businessId,
        generatedAt: _clock().toUtc(),
        people: snapshot.people,
        deals: snapshot.deals,
        settlements: snapshot.settlements,
        coinTypes: snapshot.coinTypes,
      ),
    );
  }

  ZarBackupPreview preview(String json) {
    final bundle = _codec.decodeJson(json);
    if (bundle.businessId != _businessId) {
      throw const FormatException('Backup belongs to a different business.');
    }
    return ZarBackupPreview(bundle);
  }

  Future<void> restore(ZarBackupPreview preview) async {
    final bundle = preview.bundle;
    await _repository.replaceCompleteSnapshot(
      ZarDomainSnapshot(
        people: bundle.people,
        deals: bundle.deals,
        settlements: bundle.settlements,
        coinTypes: bundle.coinTypes,
      ),
    );
    await _store.refresh();
    try {
      await _reconcileRemindersAfterRestore();
    } catch (error) {
      throw ZarRestoreReminderException(error);
    }
  }
}
