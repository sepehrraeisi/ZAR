import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_app/application/customer_position_projector.dart';
import 'package:flutter_app/data/local/zar_local_database.dart';
import 'package:flutter_app/data/local/zar_local_repository.dart';
import 'package:flutter_app/data/zar_domain_backup_codec.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projector = ZarCustomerPositionProjector();

  test(
    'groups open gold obligations by exact fineness in normalized grams',
    () {
      final result = projector.project(
        personId: 'p1',
        deals: const [],
        settlements: [
          _goldSettlement('s1', '100', ZarGoldUnit.gram, '750'),
          _goldSettlement('s2', '2', ZarGoldUnit.mesghal, '750'),
          _goldSettlement('s3', '5', ZarGoldUnit.gram, '999.9'),
          _goldSettlement('s4', '3', ZarGoldUnit.gram, null),
          _goldSettlement('s5', '2', ZarGoldUnit.gram, '18K'),
        ],
      );

      final gold = result.receive.whereType<ZarCustomerGoldPosition>().toList();
      expect(gold, hasLength(4));
      expect(
        gold.singleWhere((item) => item.fineness == '750').grams,
        '109.2166',
      );
      expect(gold.singleWhere((item) => item.fineness == '999.9').grams, '5');
      expect(gold.singleWhere((item) => item.fineness == null).grams, '3');
      expect(gold.singleWhere((item) => item.fineness == '18K').grams, '2');
    },
  );

  test('keeps USD AED and Toman obligations separate', () {
    final result = projector.project(
      personId: 'p1',
      deals: const [],
      settlements: [
        _currencySettlement('usd', 'USD', 1000050, 2),
        _currencySettlement('aed', 'AED', 5000000, 2),
        _currencySettlement('toman', 'TOMAN', 92000000, 0),
      ],
    );

    final currency = result.receive
        .whereType<ZarCustomerCurrencyPosition>()
        .toList();
    expect(
      currency.singleWhere((item) => item.code == 'USD').decimalAmount,
      '10000.5',
    );
    expect(
      currency.singleWhere((item) => item.code == 'AED').decimalAmount,
      '50000',
    );
    expect(
      currency.singleWhere((item) => item.code == 'TOMAN').decimalAmount,
      '92000000',
    );
  });

  test('completed and cancelled settlements are not active obligations', () {
    final completed = _goldSettlement(
      'completed',
      '100',
      ZarGoldUnit.gram,
      '750',
      status: ZarSettlementStatus.completed,
    );
    final cancelled = _currencySettlement(
      'cancelled',
      'USD',
      10000,
      2,
      status: ZarSettlementStatus.cancelled,
    );
    final result = projector.project(
      personId: 'p1',
      deals: [_deal('buy', ZarDealType.buy), _deal('sell', ZarDealType.sell)],
      settlements: [completed, cancelled],
    );

    expect(result.receive, isEmpty);
    expect(result.deliver, isEmpty);
    expect(result.buyCount, 1);
    expect(result.sellCount, 1);
    expect(result.receiveCount, 1);
    expect(result.deliverCount, 0);
  });

  test('position remains derived correctly after repository restart', () async {
    final directory = await Directory.systemTemp.createTemp('zar-position-');
    final file = File('${directory.path}${Platform.pathSeparator}zar.sqlite');
    try {
      var database = ZarLocalDatabase(NativeDatabase(file));
      var repository = ZarLocalRepository(database);
      await repository.ensureReady();
      await repository.savePerson(_person());
      await repository.saveSettlement(
        _goldSettlement('persisted', '10', ZarGoldUnit.mesghal, '740'),
      );
      await repository.close();

      database = ZarLocalDatabase(NativeDatabase(file));
      repository = ZarLocalRepository(database);
      await repository.ensureReady();
      final snapshot = await repository.loadCompleteSnapshot();
      final result = projector.project(
        personId: 'p1',
        deals: snapshot.deals,
        settlements: snapshot.settlements,
      );
      final gold = result.receive.single as ZarCustomerGoldPosition;
      expect(gold.fineness, '740');
      expect(gold.grams, '46.083');
      await repository.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('existing backup format roundtrip preserves projected position', () {
    const codec = ZarDomainBackupCodec();
    final bundle = ZarDomainBackupBundle(
      businessId: 'b1',
      generatedAt: _time,
      people: [_person()],
      deals: const [],
      settlements: [_goldSettlement('s1', '25', ZarGoldUnit.gram, '875')],
    );
    final restored = codec.decodeJson(codec.encodeJson(bundle));
    final result = projector.project(
      personId: 'p1',
      deals: restored.deals,
      settlements: restored.settlements,
    );
    final gold = result.receive.single as ZarCustomerGoldPosition;
    expect(gold.fineness, '875');
    expect(gold.grams, '25');
    expect(restored.exportVersion, ZarDomainBackupCodec.supportedVersion);
  });
}

final _time = DateTime.utc(2026, 8, 30, 12);

ZarPerson _person() => ZarPerson(
  id: 'p1',
  displayName: 'مهیار',
  createdAt: _time,
  updatedAt: _time,
  createdBy: 'u1',
);

ZarSettlement _goldSettlement(
  String id,
  String value,
  ZarGoldUnit unit,
  String? fineness, {
  ZarSettlementStatus status = ZarSettlementStatus.open,
}) => ZarSettlement(
  id: id,
  businessId: 'b1',
  personId: 'p1',
  direction: ZarSettlementDirection.receive,
  amount: ZarGoldAssetAmount(
    ZarGoldQuantity(decimal: value, unit: unit, purity: fineness),
  ),
  scheduledAt: _time,
  hasTime: true,
  status: status,
  completedAt: status == ZarSettlementStatus.completed ? _time : null,
  createdBy: 'u1',
  createdAt: _time,
  updatedAt: _time,
);

ZarSettlement _currencySettlement(
  String id,
  String code,
  int minorUnits,
  int scale, {
  ZarSettlementStatus status = ZarSettlementStatus.open,
}) => ZarSettlement(
  id: id,
  businessId: 'b1',
  personId: 'p1',
  direction: ZarSettlementDirection.receive,
  amount: ZarCurrencyAssetAmount(
    ZarCurrencyAmount(
      code: code,
      minorUnits: minorUnits,
      minorUnitScale: scale,
    ),
  ),
  scheduledAt: _time,
  hasTime: true,
  status: status,
  createdBy: 'u1',
  createdAt: _time,
  updatedAt: _time,
);

ZarDeal _deal(String id, ZarDealType type) => ZarDeal(
  id: id,
  businessId: 'b1',
  type: type,
  personId: 'p1',
  amount: ZarCurrencyAssetAmount(
    ZarCurrencyAmount(code: 'USD', minorUnits: 10000),
  ),
  dealAt: _time,
  createdBy: 'u1',
  createdAt: _time,
  updatedAt: _time,
);
