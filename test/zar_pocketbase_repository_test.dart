import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/pocketbase/zar_pocketbase_client.dart';
import 'package:flutter_app/data/pocketbase/zar_pocketbase_repository.dart';
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
      sentBody = Map<String, Object?>.from(
        jsonDecode(request.body) as Map,
      );
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

  test('replaceCompleteSnapshot validates allocations before touching server', () async {
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
  });

  test('server errors surface as ZarPocketBaseException', () async {
    final client = MockClient((request) async => _json({
      'message': 'Validation failed.',
    }, 400));
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
