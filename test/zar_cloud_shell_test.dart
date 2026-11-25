import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_app/data/pocketbase/zar_pocketbase_client.dart';
import 'package:flutter_app/features/auth/zar_auth_service.dart';
import 'package:flutter_app/features/auth/zar_cloud_shell.dart';

class _FakeAuthService implements ZarAuthService {
  final controller = ZarAuthStateController();

  @override
  ZarAuthUser? get currentUser => controller.current;

  @override
  Stream<ZarAuthUser?> get authStateChanges => controller.stream;

  @override
  Future<ZarAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ZarAuthUser> signUp({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {
    controller.current = null;
  }
}

ZarPocketBaseClient _client(http.Client transport) => ZarPocketBaseClient(
  baseUrl: 'https://pb.invalid',
  client: transport,
  requireHttps: true,
);

void main() {
  group('ZarPocketBaseWorkspaceBootstrapper', () {
    final bootstrapper = ZarPocketBaseWorkspaceBootstrapper();

    test('returns existing workspace from the user record', () async {
      final client = _client(
        MockClient((request) async {
          expect(
            request.url.path,
            '/api/collections/users/records/u1',
          );
          return http.Response(
            jsonEncode({'id': 'u1', 'workspace': 'ws-existing'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final id = await bootstrapper.resolveFor(
        const ZarAuthUser(uid: 'u1', email: 'a@b.test'),
        client,
      );

      expect(id, 'ws-existing');
    });

    test('bootstraps when workspace is missing', () async {
      final paths = <String>[];
      final client = _client(
        MockClient((request) async {
          paths.add('${request.method} ${request.url.path}');
          if (request.url.path == '/api/collections/users/records/u1') {
            return http.Response(
              jsonEncode({'id': 'u1', 'workspace': ''}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/zar/bootstrap/workspace') {
            expect(request.method, 'POST');
            return http.Response(
              jsonEncode({'workspaceId': 'wsu1'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected', 500);
        }),
      );

      final id = await bootstrapper.resolveFor(
        const ZarAuthUser(uid: 'u1', email: 'a@b.test'),
        client,
      );

      expect(id, 'wsu1');
      expect(paths, [
        'GET /api/collections/users/records/u1',
        'POST /api/zar/bootstrap/workspace',
      ]);
    });

    test('bootstraps when workspace field is absent', () async {
      final client = _client(
        MockClient((request) async {
          if (request.url.path.endsWith('/users/records/u2')) {
            return http.Response(
              jsonEncode({'id': 'u2'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'workspaceId': 'wsu2'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final id = await bootstrapper.resolveFor(
        const ZarAuthUser(uid: 'u2', email: 'b@b.test'),
        client,
      );
      expect(id, 'wsu2');
    });

    test('throws when bootstrap response omits workspaceId', () async {
      final client = _client(
        MockClient((request) async {
          if (request.url.path.endsWith('/users/records/u3')) {
            return http.Response(
              jsonEncode({'id': 'u3'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'ok': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        () => bootstrapper.resolveFor(
          const ZarAuthUser(uid: 'u3', email: 'c@b.test'),
          client,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ZarCloudShell widget', () {
    testWidgets('signed-out renders nothing', (tester) async {
      final auth = _FakeAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: ZarCloudShell(
            auth: auth,
            client: _client(MockClient((_) async => http.Response('{}', 200))),
          ),
        ),
      );
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.textContaining('اتصال به سرور'), findsNothing);
    });

    testWidgets('bootstrap failure shows Persian connection message', (
      tester,
    ) async {
      final auth = _FakeAuthService()
        ..controller.current = const ZarAuthUser(
          uid: 'u1',
          email: 'user@example.test',
        );
      final client = _client(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'down'}),
            503,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: ZarCloudShell(auth: auth, client: client)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text('اتصال به سرور برقرار نشد. اتصال اینترنت را بررسی کنید.'),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator while bootstrap is pending', (
      tester,
    ) async {
      final auth = _FakeAuthService()
        ..controller.current = const ZarAuthUser(
          uid: 'u1',
          email: 'user@example.test',
        );
      final gate = Completer<http.Response>();
      final client = _client(MockClient((_) => gate.future));

      await tester.pumpWidget(
        MaterialApp(home: ZarCloudShell(auth: auth, client: client)),
      );
      await tester.pump();

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      gate.complete(
        http.Response(
          jsonEncode({'id': 'u1', 'workspace': 'ws1'}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      // Avoid pumping into full RepositoryZarPlusAppV2 (heavy); dispose after
      // asserting the loading state already appeared.
    });
  });
}
