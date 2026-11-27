import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/pocketbase/zar_pocketbase_client.dart';
import 'package:flutter_app/data/pocketbase/zar_pocketbase_repository.dart';
import 'package:flutter_app/domain/zar_cash_entry.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_payment_allocation.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object? body, [int status = 200]) => http.Response(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _emptySnapshot({List<Object?> cashEntries = const []}) => {
  'workspaceId': 'w1',
  'epoch': 1,
  'people': <Object?>[],
  'deals': <Object?>[],
  'settlements': <Object?>[],
  'coinTypes': <Object?>[],
  'currencyTypes': <Object?>[],
  'allocations': <Object?>[],
  'cashEntries': cashEntries,
};

ZarCashEntry _cash({
  String id = 'cash-1',
  int minorUnits = 100,
  String note = 'آورده',
}) => ZarCashEntry(
  id: id,
  businessId: 'w1',
  kind: ZarCashEntryKind.contribution,
  direction: ZarSettlementDirection.receive,
  amount: ZarCurrencyAssetAmount(
    ZarCurrencyAmount(code: 'TOMAN', minorUnits: minorUnits, minorUnitScale: 0),
  ),
  occurredAt: DateTime.utc(2026, 9, 1),
  note: note,
);

ZarPaymentAllocation _allocation({
  required String settlementId,
  String targetId = 'deal-1',
}) => ZarPaymentAllocation(
  settlementId: settlementId,
  targetType: ZarPaymentAllocationTarget.deal,
  targetId: targetId,
  amount: ZarTomanAmount(50),
);

ZarPocketBaseRepository _repo(http.Client transport) => ZarPocketBaseRepository(
  client: ZarPocketBaseClient(
    baseUrl: 'https://pb.invalid',
    client: transport,
    requireHttps: true,
  ),
  workspaceId: 'w1',
  businessId: 'w1',
);

void main() {
  group('appendCashEntry', () {
    test('POSTs cash append with workspace and idempotency key', () async {
      Map<String, Object?>? body;
      final client = MockClient((request) async {
        if (request.url.path == '/api/zar/read/snapshot') {
          return _json(_emptySnapshot());
        }
        if (request.url.path == '/api/zar/write/cash/append') {
          body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
          return _json({'ok': true});
        }
        return _json({'message': 'unexpected'}, 500);
      });

      await _repo(client).appendCashEntry(_cash());

      expect(body!['workspaceId'], 'w1');
      expect(body!['id'], 'cash-1');
      expect(body!['idempotencyKey'], isA<String>());
      expect((body!['idempotencyKey']! as String).length, 32);
      expect((body!['data']! as Map)['id'], 'cash-1');
    });

    test('identical existing cash id is a no-op', () async {
      var appendCalls = 0;
      final entry = _cash();
      final client = MockClient((request) async {
        if (request.url.path == '/api/zar/read/snapshot') {
          return _json(
            _emptySnapshot(
              cashEntries: [
                {
                  'id': entry.id,
                  'workspace': 'w1',
                  'data': entry.toMap(),
                },
              ],
            ),
          );
        }
        if (request.url.path == '/api/zar/write/cash/append') {
          appendCalls++;
          return _json({'ok': true});
        }
        return _json({'message': 'unexpected'}, 500);
      });

      await _repo(client).appendCashEntry(entry);
      expect(appendCalls, 0);
    });

    test('mutated payload for existing cash id throws StateError', () async {
      final existing = _cash(note: 'اولیه');
      final client = MockClient((request) async {
        if (request.url.path == '/api/zar/read/snapshot') {
          return _json(
            _emptySnapshot(
              cashEntries: [
                {
                  'id': existing.id,
                  'workspace': 'w1',
                  'data': existing.toMap(),
                },
              ],
            ),
          );
        }
        return _json({'message': 'unexpected'}, 500);
      });

      await expectLater(
        _repo(client).appendCashEntry(_cash(note: 'تغییر یافته')),
        throwsA(isA<StateError>()),
      );
    });

    test('maps 409 to ZarCloudWriteConflictException', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/zar/read/snapshot') {
          return _json(_emptySnapshot());
        }
        return _json({
          'message': jsonEncode({
            'code': 'cash_entry_immutable',
            'collection': 'zar_cash_entries',
            'recordId': 'cash-1',
          }),
        }, 409);
      });

      await expectLater(
        _repo(client).appendCashEntry(_cash()),
        throwsA(
          isA<ZarCloudWriteConflictException>().having(
            (e) => e.code,
            'code',
            'cash_entry_immutable',
          ),
        ),
      );
    });

    test('maps idempotency payload mismatch distinctly', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/zar/read/snapshot') {
          return _json(_emptySnapshot());
        }
        return _json({
          'message': jsonEncode({
            'code': 'idempotency_payload_mismatch',
            'collection': 'zar_cash_entries',
            'recordId': 'cash-1',
          }),
        }, 409);
      });

      await expectLater(
        _repo(client).appendCashEntry(_cash()),
        throwsA(
          isA<ZarCloudWriteConflictException>().having(
            (e) => e.code,
            'code',
            'idempotency_payload_mismatch',
          ),
        ),
      );
    });
  });

  group('savePaymentAllocations', () {
    test('rejects allocations with mismatched settlementId', () async {
      final client = MockClient((_) async => _json({'items': []}));
      await expectLater(
        _repo(client).savePaymentAllocations('pay-1', [
          _allocation(settlementId: 'other'),
        ]),
        throwsA(isA<FormatException>()),
      );
    });

    test('POSTs replace with expectedBefore and allocations', () async {
      Map<String, Object?>? body;
      final client = MockClient((request) async {
        if (request.url.path.contains('/zar_allocations/records')) {
          return _json({
            'items': [
              {
                'id': 'alloc-old',
                'workspace': 'w1',
                'data': {
                  'settlementId': 'pay-1',
                  'targetType': 'deal',
                  'targetId': 'deal-1',
                  'amountToman': 10,
                },
              },
            ],
            'totalPages': 1,
          });
        }
        if (request.url.path == '/api/zar/write/allocations/replace') {
          body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
          return _json({'ok': true});
        }
        return _json({'message': 'unexpected'}, 500);
      });

      await _repo(client).savePaymentAllocations('pay-1', [
        _allocation(settlementId: 'pay-1'),
      ]);

      expect(body!['workspaceId'], 'w1');
      expect(body!['settlementId'], 'pay-1');
      expect(body!['idempotencyKey'], isA<String>());
      expect(body!['expectedBefore'], isA<List>());
      expect((body!['expectedBefore']! as List), hasLength(1));
      expect((body!['allocations']! as List), hasLength(1));
    });

    test('maps stale allocation set 409 to conflict', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/zar_allocations/records')) {
          return _json({'items': <Object?>[], 'totalPages': 1});
        }
        return _json({
          'message': jsonEncode({
            'code': 'stale_allocation_set',
            'collection': 'zar_allocations',
            'recordId': 'pay-1',
          }),
        }, 409);
      });

      await expectLater(
        _repo(client).savePaymentAllocations('pay-1', [
          _allocation(settlementId: 'pay-1'),
        ]),
        throwsA(
          isA<ZarCloudWriteConflictException>().having(
            (e) => e.code,
            'code',
            'stale_allocation_set',
          ),
        ),
      );
    });
  });

  group('archivePerson', () {
    test('upserts archived=true via CAS route', () async {
      Map<String, Object?>? body;
      final client = MockClient((request) async {
        expect(request.url.path, '/api/zar/write/upsert');
        body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
        return _json({
          'replayed': false,
          'collection': 'zar_people',
          'revision': 1,
          'record': {
            'id': 'p1',
            'workspace': 'w1',
            'revision': 1,
            'data': body!['data'],
          },
        });
      });

      await _repo(client).archivePerson(
        ZarPerson(
          id: 'p1',
          displayName: 'مشتری',
          createdAt: DateTime.utc(2026, 9, 1),
          updatedAt: DateTime.utc(2026, 9, 1),
          createdBy: 'test',
        ),
      );

      expect(body!['collection'], 'zar_people');
      expect((body!['data']! as Map)['archived'], isTrue);
    });
  });

  group('saveCoinType / saveCurrencyType', () {
    test('maps catalog upsert 409 to staleRevision', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/zar/read/snapshot') {
          return _json(_emptySnapshot());
        }
        expect(request.url.path, '/api/zar/write/upsert');
        return _json({
          'message': jsonEncode({
            'code': 'stale_revision',
            'collection': 'zar_coin_types',
            'recordId': 'coin-1',
            'currentRevision': 4,
          }),
        }, 409);
      });

      await expectLater(
        _repo(client).saveCoinType(
          ZarCoinType(
            id: 'coin-1',
            name: 'سکه',
            category: ZarCoinCategory.official,
            defaultPricingMethod: ZarCoinPricingMethod.perPiece,
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        ),
        throwsA(
          isA<ZarCloudWriteConflictException>()
              .having((e) => e.code, 'code', 'stale_revision')
              .having((e) => e.needsReload, 'needsReload', isTrue),
        ),
      );
    });
  });
}
