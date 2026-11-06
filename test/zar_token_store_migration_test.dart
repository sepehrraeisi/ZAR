import 'dart:convert';

import 'package:flutter_app/data/pocketbase/zar_pocketbase_client.dart';
import 'package:flutter_app/features/auth/zar_pocketbase_auth_service.dart';
import 'package:flutter_app/features/auth/zar_token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryTokenStore implements ZarTokenStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  const tokenKey = 'zar_pb_token';
  const userIdKey = 'zar_pb_user_id';
  const userEmailKey = 'zar_pb_user_email';

  ZarPocketBaseAuthService serviceWith({
    required ZarTokenStore tokenStore,
    required http.Client transport,
  }) {
    return ZarPocketBaseAuthService(
      client: ZarPocketBaseClient(baseUrl: 'https://pb.invalid', client: transport),
      tokenStore: tokenStore,
    );
  }

  test('sign-in persists session material in the secure store, not prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final store = _InMemoryTokenStore();
    final transport = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'token': 'secret-token-abc',
          'record': {'id': 'u1', 'email': 'user@example.test'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final service = serviceWith(tokenStore: store, transport: transport);

    await service.signIn(email: 'user@example.test', password: 'password123');

    expect(store.values[tokenKey], 'secret-token-abc');
    expect(store.values[userIdKey], 'u1');
    expect(store.values[userEmailKey], 'user@example.test');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(tokenKey), isNull);
  });

  test('restore migrates a legacy plain-text session once and scrubs prefs', () async {
    SharedPreferences.setMockInitialValues({
      tokenKey: 'legacy-token',
      userIdKey: 'u1',
      userEmailKey: 'user@example.test',
    });
    final store = _InMemoryTokenStore();
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/api/collections/users/records/u1')) {
        return http.Response(
          jsonEncode({'id': 'u1', 'email': 'user@example.test'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });
    final service = serviceWith(tokenStore: store, transport: transport);

    await service.restoreSession();

    expect(store.values[tokenKey], 'legacy-token');
    expect(service.currentUser?.uid, 'u1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(tokenKey), isNull);
    expect(prefs.getString(userIdKey), isNull);
    expect(prefs.getString(userEmailKey), isNull);

    // a second restore reads from the secure store and does not need prefs
    final second = serviceWith(tokenStore: store, transport: transport);
    await second.restoreSession();
    expect(second.currentUser?.uid, 'u1');
  });

  test('sign-out clears the secure store', () async {
    SharedPreferences.setMockInitialValues({});
    final store = _InMemoryTokenStore();
    final transport = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'token': 'secret-token-abc',
          'record': {'id': 'u1', 'email': 'user@example.test'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final service = serviceWith(tokenStore: store, transport: transport);

    await service.signIn(email: 'user@example.test', password: 'password123');
    await service.signOut();

    expect(store.values.containsKey(tokenKey), isFalse);
    expect(service.currentUser, isNull);
  });

  test('a rejected legacy token (401) clears the migrated session', () async {
    SharedPreferences.setMockInitialValues({
      tokenKey: 'expired-token',
      userIdKey: 'u1',
    });
    final store = _InMemoryTokenStore();
    final transport = MockClient(
      (_) async => http.Response(
        jsonEncode({'message': 'expired'}),
        401,
        headers: {'content-type': 'application/json'},
      ),
    );
    final service = serviceWith(tokenStore: store, transport: transport);

    await service.restoreSession();

    expect(service.currentUser, isNull);
    expect(store.values.containsKey(tokenKey), isFalse);
  });
}
