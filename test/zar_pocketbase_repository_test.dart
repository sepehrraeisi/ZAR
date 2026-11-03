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

const _stateHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _snapshotHash =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Map<String, Object?> _restoreState() => {
  'protocolVersion': 1,
  'workspaceId': 'w1',
  'stateHash': _stateHash,
  'counts': {'total': 0},
};

Map<String, Object?> _restoreReceipt(
  String requestId, {
  Map<String, int>? counts,
  bool replayed = false,
}) => {
  'protocolVersion': 1,
  'requestId': requestId,
  'workspaceId': 'w1',
  'snapshotHash': _snapshotHash,
  'beforeHash': _stateHash,
  'afterHash': _snapshotHash,
  'counts': counts ?? _restoreCounts(),
  'committedAt': '2026-11-03T12:00:00.000Z',
  'replayed': replayed,
};

Map<String, int> _restoreCounts({
  int people = 0,
  int deals = 0,
  int settlements = 0,
  int coinTypes = 0,
  int currencyTypes = 0,
  int paymentAllocations = 0,
  int cashEntries = 0,
}) => {
  'people': people,
  'deals': deals,
  'settlements': settlements,
  'coinTypes': coinTypes,
  'currencyTypes': currencyTypes,
  'paymentAllocations': paymentAllocations,
  'cashEntries': cashEntries,
  'total':
      people +
      deals +
      settlements +
      coinTypes +
      currencyTypes +
      paymentAllocations +
      cashEntries,
};

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
      final routeCalls = <String>[];
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/records')) {
          listFilters.add(request.url.queryParameters['filter']);
          return _json({'items': [], 'totalPages': 1});
        }
        routeCalls.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/zar/restore/state') {
          return _json(_restoreState());
        }
        if (request.url.path == '/api/zar/restore/commit') {
          final body = Map<String, Object?>.from(
            jsonDecode(request.body) as Map,
          );
          return _json(_restoreReceipt(body['requestId']! as String));
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
        confirmationSecret: 'correct horse battery staple',
      );

      expect(listFilters, hasLength(7));
      expect(listFilters, everyElement("workspace='w1'"));
      expect(routeCalls, [
        'GET /api/zar/restore/state',
        'POST /api/zar/restore/commit',
      ]);
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
    'transactional restore sends cash through the dedicated route',
    () async {
      final requests = <http.Request>[];
      Map<String, Object?>? commitBody;
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/zar/restore/state') {
          return _json(_restoreState());
        }
        if (request.url.path == '/api/zar/restore/commit') {
          commitBody = Map<String, Object?>.from(
            jsonDecode(request.body) as Map,
          );
          return _json(
            _restoreReceipt(
              commitBody!['requestId']! as String,
              counts: _restoreCounts(people: 1, cashEntries: 1),
            ),
          );
        }
        return _json({'message': 'unexpected route'}, 500);
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
          cashEntries: [_cashEntry()],
        ),
        confirmationSecret: 'correct horse battery staple',
      );

      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        ['GET /api/zar/restore/state', 'POST /api/zar/restore/commit'],
      );
      expect(commitBody!['protocolVersion'], 1);
      expect(commitBody!['businessId'], 'w1');
      expect(commitBody!['expectedStateHash'], _stateHash);
      expect(
        commitBody!['confirmationPassword'],
        'correct horse battery staple',
      );
      expect(commitBody!['requestId'], matches(RegExp(r'^[a-f0-9]{32}$')));
      final snapshot = Map<String, Object?>.from(
        commitBody!['snapshot']! as Map,
      );
      expect(snapshot['people'], hasLength(1));
      final cash = snapshot['cashEntries']! as List;
      expect(cash, hasLength(1));
      expect((cash.single as Map)['id'], 'cash-1');
    },
  );

  test(
    'transactional restore requires a fresh password before network I/O',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return _json({});
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
        throwsA(
          isA<ZarCloudRestoreException>().having(
            (error) => error.code,
            'code',
            'cloud_restore_reauthentication_required',
          ),
        ),
      );
      expect(requests, 0);
    },
  );

  test('stale cloud state becomes a typed no-write conflict', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/zar/restore/state') {
        return _json(_restoreState());
      }
      return _json({'message': 'Cloud data changed.'}, 409);
    });
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );

    await expectLater(
      repository.replaceCompleteSnapshot(
        const ZarDomainSnapshot(people: [], deals: [], settlements: []),
        confirmationSecret: 'correct horse battery staple',
      ),
      throwsA(
        isA<ZarCloudRestoreException>().having(
          (error) => error.code,
          'code',
          'concurrent_cloud_change',
        ),
      ),
    );
  });

  test('missing restore route fails closed with upgrade guidance', () async {
    final client = MockClient(
      (request) async => _json({'message': 'Not found.'}, 404),
    );
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );

    await expectLater(
      repository.replaceCompleteSnapshot(
        const ZarDomainSnapshot(people: [], deals: [], settlements: []),
        confirmationSecret: 'correct horse battery staple',
      ),
      throwsA(
        isA<ZarCloudRestoreException>().having(
          (error) => error.code,
          'code',
          'server_restore_unavailable',
        ),
      ),
    );
  });

  test('lost commit response retries once with the same request id', () async {
    final commitBodies = <Map<String, Object?>>[];
    var commits = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/zar/restore/state') {
        return _json(_restoreState());
      }
      final body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
      commitBodies.add(body);
      commits++;
      if (commits == 1) {
        throw http.ClientException('response lost');
      }
      return _json(_restoreReceipt(body['requestId']! as String));
    });
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );

    await repository.replaceCompleteSnapshot(
      const ZarDomainSnapshot(people: [], deals: [], settlements: []),
      confirmationSecret: 'correct horse battery staple',
    );

    expect(commitBodies, hasLength(2));
    expect(commitBodies[1]['requestId'], commitBodies[0]['requestId']);
    expect(commitBodies[1], commitBodies[0]);
  });

  test('invalid success response retries with the same request id', () async {
    final requestIds = <String>[];
    var commits = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/zar/restore/state') {
        return _json(_restoreState());
      }
      final body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
      requestIds.add(body['requestId']! as String);
      commits++;
      if (commits == 1) return http.Response('{', 200);
      return _json(_restoreReceipt(body['requestId']! as String));
    });
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );

    await repository.replaceCompleteSnapshot(
      const ZarDomainSnapshot(people: [], deals: [], settlements: []),
      confirmationSecret: 'correct horse battery staple',
    );

    expect(requestIds, hasLength(2));
    expect(requestIds[1], requestIds[0]);
  });

  test('server 503 after commit retries with the same request id', () async {
    final requestIds = <String>[];
    var commits = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/zar/restore/state') {
        return _json(_restoreState());
      }
      final body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
      requestIds.add(body['requestId']! as String);
      commits++;
      if (commits == 1) return _json({'message': 'upstream reset'}, 503);
      return _json(_restoreReceipt(body['requestId']! as String));
    });
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );

    await repository.replaceCompleteSnapshot(
      const ZarDomainSnapshot(people: [], deals: [], settlements: []),
      confirmationSecret: 'correct horse battery staple',
    );

    expect(requestIds, hasLength(2));
    expect(requestIds[1], requestIds[0]);
  });

  test('two ambiguous commit results report an unknown outcome', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/zar/restore/state') {
        return _json(_restoreState());
      }
      throw http.ClientException('response lost');
    });
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );

    await expectLater(
      repository.replaceCompleteSnapshot(
        const ZarDomainSnapshot(people: [], deals: [], settlements: []),
        confirmationSecret: 'correct horse battery staple',
      ),
      throwsA(
        isA<ZarCloudRestoreException>().having(
          (error) => error.code,
          'code',
          'cloud_restore_outcome_unknown',
        ),
      ),
    );
  });

  test(
    'a 4xx replay after an ambiguous commit remains outcome unknown',
    () async {
      for (final retryStatus in [400, 401, 403, 404, 409, 413, 422, 428, 429]) {
        var commits = 0;
        final client = MockClient((request) async {
          if (request.url.path == '/api/zar/restore/state') {
            return _json(_restoreState());
          }
          commits++;
          if (commits == 1) {
            throw http.ClientException('first commit response lost');
          }
          return _json({'message': 'retry rejected'}, retryStatus);
        });
        final repository = ZarPocketBaseRepository(
          client: ZarPocketBaseClient(
            baseUrl: 'http://pb.local',
            client: client,
          ),
          workspaceId: 'w1',
          businessId: 'w1',
        );

        await expectLater(
          repository.replaceCompleteSnapshot(
            const ZarDomainSnapshot(people: [], deals: [], settlements: []),
            confirmationSecret: 'correct horse battery staple',
          ),
          throwsA(
            isA<ZarCloudRestoreException>().having(
              (error) => error.code,
              'code',
              'cloud_restore_outcome_unknown',
            ),
          ),
          reason: 'retry HTTP $retryStatus cannot disprove the first commit',
        );
        expect(commits, 2);
      }
    },
  );

  test(
    'an invalid replay receipt after an ambiguous commit stays unknown',
    () async {
      var commits = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/zar/restore/state') {
          return _json(_restoreState());
        }
        commits++;
        if (commits == 1) {
          throw http.ClientException('first commit response lost');
        }
        final body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
        final receipt = _restoreReceipt(body['requestId']! as String);
        receipt['afterHash'] = _stateHash;
        return _json(receipt);
      });
      final repository = ZarPocketBaseRepository(
        client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
        workspaceId: 'w1',
        businessId: 'w1',
      );

      await expectLater(
        repository.replaceCompleteSnapshot(
          const ZarDomainSnapshot(people: [], deals: [], settlements: []),
          confirmationSecret: 'correct horse battery staple',
        ),
        throwsA(
          isA<ZarCloudRestoreException>().having(
            (error) => error.code,
            'code',
            'cloud_restore_outcome_unknown',
          ),
        ),
      );
    },
  );

  test('unverifiable server receipt never reports success', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/zar/restore/state') {
        return _json(_restoreState());
      }
      final body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
      final receipt = _restoreReceipt(body['requestId']! as String);
      receipt['afterHash'] = _stateHash;
      return _json(receipt);
    });
    final repository = ZarPocketBaseRepository(
      client: ZarPocketBaseClient(baseUrl: 'http://pb.local', client: client),
      workspaceId: 'w1',
      businessId: 'w1',
    );

    await expectLater(
      repository.replaceCompleteSnapshot(
        const ZarDomainSnapshot(people: [], deals: [], settlements: []),
        confirmationSecret: 'correct horse battery staple',
      ),
      throwsA(
        isA<ZarCloudRestoreException>().having(
          (error) => error.code,
          'code',
          'invalid_cloud_restore_receipt',
        ),
      ),
    );
  });

  test(
    'receipt with correct total but wrong collection counts is rejected',
    () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/zar/restore/state') {
          return _json(_restoreState());
        }
        final body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
        return _json(
          _restoreReceipt(
            body['requestId']! as String,
            counts: _restoreCounts(deals: 1),
          ),
        );
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
          confirmationSecret: 'correct horse battery staple',
        ),
        throwsA(
          isA<ZarCloudRestoreException>().having(
            (error) => error.code,
            'code',
            'invalid_cloud_restore_receipt',
          ),
        ),
      );
    },
  );

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
