import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_app/data/pocketbase/zar_pocketbase_client.dart';

void main() {
  group('validateZarPocketBaseBaseUrl', () {
    test('accepts https always', () {
      expect(
        () => validateZarPocketBaseBaseUrl(
          'https://app.titangold.ir',
          requireHttps: true,
        ),
        returnsNormally,
      );
    });

    test('rejects http when requireHttps', () {
      expect(
        () => validateZarPocketBaseBaseUrl(
          'http://127.0.0.1:8090',
          requireHttps: true,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('https://'),
          ),
        ),
      );
    });

    test('allows http when requireHttps is false', () {
      expect(
        () => validateZarPocketBaseBaseUrl(
          'http://pb.local',
          requireHttps: false,
        ),
        returnsNormally,
      );
    });

    test('rejects missing host', () {
      expect(
        () => validateZarPocketBaseBaseUrl('https://', requireHttps: false),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ZarPocketBaseClient', () {
    test('strips trailing slash and stores baseUrl', () {
      final client = ZarPocketBaseClient(
        baseUrl: 'https://app.titangold.ir/',
        requireHttps: true,
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(client.baseUrl, 'https://app.titangold.ir');
    });

    test('constructor refuses cleartext when requireHttps', () {
      expect(
        () => ZarPocketBaseClient(
          baseUrl: 'http://pb.local',
          requireHttps: true,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('maps TimeoutException to transport failure', () async {
      final client = ZarPocketBaseClient(
        baseUrl: 'https://app.titangold.ir',
        requireHttps: true,
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        }),
      );
      expect(
        () => client.getRecord('users', id: 'x'),
        throwsA(isA<ZarPocketBaseTransportException>()),
      );
    });

    test('successful JSON GET still works with timeout bound', () async {
      final client = ZarPocketBaseClient(
        baseUrl: 'http://pb.local',
        requireHttps: false,
        client: MockClient((request) async {
          expect(request.url.path, '/api/collections/users/records/u1');
          return http.Response(jsonEncode({'id': 'u1'}), 200);
        }),
      );
      final record = await client.getRecord('users', id: 'u1');
      expect(record['id'], 'u1');
    });
  });
}
