import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/zar_domain_backup_codec.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/features/auth/zar_device_attribution_store.dart';
import 'package:flutter_app/features/auth/zar_token_store.dart';

class _MemoryTokens implements ZarTokenStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  test('device store emits stable opaque installation hash and label', () async {
    final tokens = _MemoryTokens();
    final store = ZarDeviceAttributionStore(tokenStore: tokens);
    final first = await store.current();
    final second = await store.current();
    expect(first.installationId, second.installationId);
    expect(first.installationId.length, 16);
    expect(first.label, isNotEmpty);
    await store.writeLabel('ویترین');
    expect((await store.current()).label, 'ویترین');
  });

  test('backup codec round-trips optional device refs on V8', () {
    const device = ZarDeviceRef(installationId: 'abcd1234efgh5678', label: 'moto e13');
    final at = DateTime.utc(2026, 11, 28);
    final person = ZarPerson(
      id: 'p1',
      displayName: 'علی',
      createdAt: at,
      updatedAt: at,
      createdBy: 'u1',
      createdFromDevice: device,
      updatedFromDevice: device,
    );
    const codec = ZarDomainBackupCodec();
    final map = codec.personRecord(person);
    expect(map['createdFromDevice'], device.toMap());
    final decoded = codec.decodeJson(
      codec.encodeJson(
        ZarDomainBackupBundle(
          businessId: 'b',
          generatedAt: at,
          people: [person],
          deals: const [],
          settlements: const [],
          coinTypes: zarInitialCoinTypes(now: at),
          currencyTypes: zarInitialCurrencyTypes(now: at),
          cashEntries: const [],
        ),
      ),
    );
    expect(decoded.people.single.createdFromDevice, device);
    expect(decoded.people.single.updatedFromDevice, device);
  });
}
