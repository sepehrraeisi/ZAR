import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_app/data/zar_domain_backup_codec.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:flutter_app/data/local/zar_local_database.dart';
import 'package:flutter_app/data/local/zar_local_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';

void main() {
  test(
    'currency catalog normalizes codes and supports archive/restore',
    () async {
      final repository = InMemoryZarDomainRepository(currencyTypes: const []);
      final custom = ZarCurrencyType(
        id: 'currency-jpy',
        name: 'ین ژاپن',
        code: ' jpy ',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      expect(custom.code, 'JPY');
      await repository.saveCurrencyType(custom);
      expect(
        (await repository.loadCurrencyTypes()).any(
          (item) => item.code == 'JPY',
        ),
        isTrue,
      );
      await repository.archiveCurrencyType(custom);
      expect(await repository.loadCurrencyTypes(), isNot(contains(custom)));
      expect(
        (await repository.loadCurrencyTypes(
          includeArchived: true,
        )).singleWhere((item) => item.id == custom.id).archived,
        isTrue,
      );
      await repository.restoreCurrencyType(custom);
      expect(
        (await repository.loadCurrencyTypes())
            .singleWhere((item) => item.id == custom.id)
            .archived,
        isFalse,
      );
    },
  );

  test(
    'currency catalog rejects duplicate codes without replacing the record',
    () async {
      final repository = InMemoryZarDomainRepository();
      final first = (await repository.loadCurrencyTypes()).first;
      expect(
        () => repository.saveCurrencyType(
          ZarCurrencyType(
            id: 'currency-duplicate',
            name: 'نسخه تکراری',
            code: first.code,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        (await repository.loadCurrencyTypes(
          includeArchived: true,
        )).where((item) => item.code == first.code),
        hasLength(1),
      );
    },
  );

  test(
    'Backup V7 round-trips currency master data and imports V6 without it',
    () {
      const codec = ZarDomainBackupCodec();
      final currencies = zarInitialCurrencyTypes(now: DateTime.utc(2026));
      final source = ZarDomainBackupBundle(
        businessId: 'business',
        generatedAt: DateTime.utc(2026),
        people: const [],
        deals: const [],
        settlements: const [],
        currencyTypes: currencies,
      );

      final restored = codec.decodeJson(codec.encodeJson(source));
      expect(restored.exportVersion, 7);
      expect(restored.currencyTypes.map((item) => item.code), contains('USD'));

      final v6 =
          Map<String, Object?>.from(jsonDecode(codec.encodeJson(source)) as Map)
            ..['exportVersion'] = 6
            ..remove('currencyTypes');
      final legacy = codec.decodeJson(jsonEncode(v6));
      expect(legacy.exportVersion, 6);
      expect(legacy.currencyTypes, isEmpty);
    },
  );

  test('local currency catalog persists and seeds idempotently', () async {
    final database = ZarLocalDatabase(NativeDatabase.memory());
    final repository = ZarLocalRepository(database);
    await repository.ensureReady();
    final seeded = await repository.loadCurrencyTypes();
    expect(seeded, hasLength(7));

    final edited = seeded.first.copyWith(name: 'نام ویرایش‌شده');
    await repository.saveCurrencyType(edited);
    await repository.ensureReady();
    expect(
      (await repository.loadCurrencyTypes())
          .singleWhere((item) => item.id == edited.id)
          .name,
      'نام ویرایش‌شده',
    );
    await repository.close();
  });
}
