import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/pocketbase/zar_pocketbase_client.dart';
import 'package:flutter_app/data/pocketbase/zar_pocketbase_repository.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_cash_entry.dart';
import 'package:flutter_app/domain/zar_payment_allocation.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object? body, [int status = 200]) => http.Response(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _personRow(String id, String name) => {
  'id': id,
  'workspace': 'w1',
  'data': {
    'id': id,
    'displayName': name,
    'archived': false,
    'createdAt': '2026-09-01T00:00:00.000Z',
    'updatedAt': '2026-09-01T00:00:00.000Z',
    'createdBy': 'test',
  },
};

ZarPerson _person(String id, String name) => ZarPerson(
  id: id,
  displayName: name,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
  createdBy: 'test',
);

ZarCashEntry _cashEntry() => ZarCashEntry(
  id: 'cash-1',
  businessId: 'w1',
  kind: ZarCashEntryKind.contribution,
  direction: ZarSettlementDirection.receive,
  amount: ZarCurrencyAssetAmount(
    ZarCurrencyAmount(code: 'TOMAN', minorUnits: 100, minorUnitScale: 0),
  ),
  occurredAt: DateTime.utc(2026, 9, 1),
  note: 'آورده آزمایشی',
);

Matcher _appendOnlyCashRestoreError() => isA<ZarCloudRestoreException>()
    .having((error) => error.code, 'code', 'append_only_cash_history')
    .having((error) => error.message, 'message', contains('فقط‌افزودنی'))
    .having(
      (error) => error.message,
      'recovery action',
      allOf(
        contains('فایل پشتیبان را نگه دارید'),
        contains('فضای کاری جدید و خالی'),
        contains('پشتیبانی'),
      ),
    );

void main() {
  test('loadCompleteSnapshot decodes payload rows', () async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.contains('/api/collections/zar_people/records')) {
        return _json({
          'items': [_personRow('p1', 'مشتری یک')],
          'totalPages': 1,
        });
      }
      return _json({'items': [], 'totalPages': 1});
    });
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );
    final snapshot = await repository.loadCompleteSnapshot();
    expect(snapshot.people, hasLength(1));
    expect(snapshot.people.first.id, 'p1');
    expect(snapshot.people.first.displayName, 'مشتری یک');
    expect(snapshot.deals, isEmpty);
  });

  test(
    'load and restore discovery are scoped to the selected workspace',
    () async {
      final listFilters = <String?>[];
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/records')) {
          listFilters.add(request.url.queryParameters['filter']);
          return _json({'items': [], 'totalPages': 1});
        }
        return _json({});
      });
      final repository = ZarPocketBaseRepository(
        client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
        workspaceId: 'w1',
        businessId: 'w1',
      );

      await repository.loadCompleteSnapshot();
      await repository.replaceCompleteSnapshot(
        const ZarDomainSnapshot(people: [], deals: [], settlements: []),
      );

      expect(listFilters, hasLength(15));
      expect(listFilters, everyElement("workspace='w1'"));
    },
  );

  test('savePerson upserts: PATCH first, falls back to POST on 404', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.method == 'PATCH') {
        return _json({'message': 'not found'}, 404);
      }
      return _json({'id': 'p9'});
    });
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );
    await repository.savePerson(_person('p9', 'جدید'));
    expect(calls, [
      'PATCH /api/collections/zar_people/records/p9',
      'POST /api/collections/zar_people/records',
    ]);
  });

  test('rows carry the workspace relation and JSON payload', () async {
    Map<String, Object?>? sentBody;
    final client = MockClient((request) async {
      sentBody = Map<String, Object?>.from(jsonDecode(request.body) as Map);
      return _json({'id': 'p1'});
    });
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );
    await repository.savePerson(_person('p1', 'مشتری'));
    expect(sentBody!['workspace'], 'w1');
    final data = sentBody!['data']! as Map<String, Object?>;
    expect(data['id'], 'p1');
    expect(data['displayName'], 'مشتری');
  });

  test(
    'replaceCompleteSnapshot validates allocations before touching server',
    () async {
      final client = MockClient((request) async => _json({'id': 'x'}));
      final repository = ZarPocketBaseRepository(
        client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
        workspaceId: 'w1',
        businessId: 'w1',
      );
      expect(
        () => repository.replaceCompleteSnapshot(
          ZarDomainSnapshot(
            people: [_person('p1', 'مشتری')],
            deals: const [],
            settlements: const [],
            paymentAllocations: [
              ZarPaymentAllocation(
                settlementId: 'missing',
                targetType: ZarPaymentAllocationTarget.deal,
                targetId: 'missing',
                amount: ZarTomanAmount(100),
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'restore with incoming cash fails closed before any cloud request',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return _json({'items': [], 'totalPages': 1});
      });
      final repository = ZarPocketBaseRepository(
        client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
        workspaceId: 'w1',
        businessId: 'w1',
      );

      await expectLater(
        repository.replaceCompleteSnapshot(
          ZarDomainSnapshot(
            people: const [],
            deals: const [],
            settlements: const [],
            cashEntries: [_cashEntry()],
          ),
        ),
        throwsA(_appendOnlyCashRestoreError()),
      );

      expect(
        requests,
        isEmpty,
        reason: 'incoming cash must fail before writes',
      );
    },
  );

  test(
    'restore into workspace with cash fails closed without a batch or write',
    () async {
      final writeRequests = <http.Request>[];
      final readPaths = <String>[];
      final client = MockClient((request) async {
        if (request.method != 'GET') {
          writeRequests.add(request);
          return _json({});
        }
        readPaths.add(request.url.path);
        if (request.url.path.contains('/zar_cash_entries/records')) {
          return _json({
            'items': [
              {'id': 'cash-existing'},
            ],
            'totalPages': 1,
          });
        }
        return _json({'items': [], 'totalPages': 1});
      });
      final repository = ZarPocketBaseRepository(
        client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
        workspaceId: 'w1',
        businessId: 'w1',
      );

      await expectLater(
        repository.replaceCompleteSnapshot(
          const ZarDomainSnapshot(people: [], deals: [], settlements: []),
        ),
        throwsA(_appendOnlyCashRestoreError()),
      );

      expect(readPaths, ['/api/collections/zar_cash_entries/records']);
      expect(
        writeRequests,
        isEmpty,
        reason: 'existing cash must be detected before /api/batch or CRUD',
      );
    },
  );

  test(
    'cash appearing during discovery is caught by the final pre-write check',
    () async {
      var cashReads = 0;
      final writeRequests = <http.Request>[];
      final client = MockClient((request) async {
        if (request.method != 'GET') {
          writeRequests.add(request);
          return _json({});
        }
        if (request.url.path.contains('/zar_cash_entries/records')) {
          cashReads++;
          return _json({
            'items': cashReads == 1
                ? []
                : [
                    {'id': 'cash-added-by-another-device'},
                  ],
            'totalPages': 1,
          });
        }
        return _json({'items': [], 'totalPages': 1});
      });
      final repository = ZarPocketBaseRepository(
        client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
        workspaceId: 'w1',
        businessId: 'w1',
      );

      await expectLater(
        repository.replaceCompleteSnapshot(
          ZarDomainSnapshot(
            people: [_person('p1', 'مشتری')],
            deals: const [],
            settlements: const [],
          ),
        ),
        throwsA(_appendOnlyCashRestoreError()),
      );

      expect(cashReads, 2);
      expect(
        writeRequests,
        isEmpty,
        reason: 'the second cash check must happen before /api/batch',
      );
    },
  );

  test(
    'final cash check prevents false success when replacement batch is empty',
    () async {
      var cashReads = 0;
      final writeRequests = <http.Request>[];
      final client = MockClient((request) async {
        if (request.method != 'GET') {
          writeRequests.add(request);
          return _json({});
        }
        if (request.url.path.contains('/zar_cash_entries/records')) {
          cashReads++;
          return _json({
            'items': cashReads == 1
                ? []
                : [
                    {'id': 'cash-added-during-empty-restore'},
                  ],
            'totalPages': 1,
          });
        }
        return _json({'items': [], 'totalPages': 1});
      });
      final repository = ZarPocketBaseRepository(
        client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
        workspaceId: 'w1',
        businessId: 'w1',
      );

      await expectLater(
        repository.replaceCompleteSnapshot(
          const ZarDomainSnapshot(people: [], deals: [], settlements: []),
        ),
        throwsA(_appendOnlyCashRestoreError()),
      );

      expect(cashReads, 2);
      expect(writeRequests, isEmpty);
    },
  );

  test('non-cash restore still sends one transactional batch', () async {
    final writeRequests = <http.Request>[];
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return _json({'items': [], 'totalPages': 1});
      }
      writeRequests.add(request);
      return _json({});
    });
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );

    await repository.replaceCompleteSnapshot(
      ZarDomainSnapshot(
        people: [_person('p1', 'مشتری')],
        deals: const [],
        settlements: const [],
      ),
    );

    expect(writeRequests, hasLength(1));
    expect(writeRequests.single.method, 'POST');
    expect(writeRequests.single.url.path, '/api/batch');
    final batch = Map<String, Object?>.from(
      jsonDecode(writeRequests.single.body) as Map,
    );
    final operations = batch['requests']! as List;
    expect(operations, hasLength(1));
    expect((operations.single as Map)['method'], 'POST');
    expect(
      (operations.single as Map)['url'],
      '/api/collections/zar_people/records',
    );
  });

  test('server errors surface as ZarPocketBaseException', () async {
    final client = MockClient(
      (request) async => _json({'message': 'Validation failed.'}, 400),
    );
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );
    expect(
      () => repository.savePerson(_person('p1', 'مشتری')),
      throwsA(
        isA<ZarPocketBaseException>().having(
          (e) => e.statusCode,
          'statusCode',
          400,
        ),
      ),
    );
  });
}
