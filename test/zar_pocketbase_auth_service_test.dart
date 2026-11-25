import 'dart:convert';

import 'package:flutter_app/data/pocketbase/zar_pocketbase_client.dart';
import 'package:flutter_app/features/auth/zar_auth_service.dart';
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
  const expectedRateLimit =
      'تعداد درخواست‌ها بیش از حد مجاز است. کمی صبر کنید و دوباره تلاش کنید.';
  const tokenKey = 'zar_pb_token';
  const userIdKey = 'zar_pb_user_id';
  const userEmailKey = 'zar_pb_user_email';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ZarPocketBaseAuthService serviceWith({
    required http.Client transport,
    ZarTokenStore? tokenStore,
  }) {
    return ZarPocketBaseAuthService(
      client: ZarPocketBaseClient(
        baseUrl: 'https://pb.invalid',
        client: transport,
        requireHttps: true,
      ),
      tokenStore: tokenStore ?? _InMemoryTokenStore(),
    );
  }

  ZarPocketBaseAuthService rateLimitedService() {
    return serviceWith(
      transport: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Too many requests.'}),
          429,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
  }

  Matcher isFriendlyRateLimit() => isA<ZarAuthException>().having(
    (error) => error.message,
    'message',
    expectedRateLimit,
  );

  test('sign in translates PocketBase 429 to a Persian auth error', () async {
    final service = rateLimitedService();

    await expectLater(
      service.signIn(email: 'user@example.test', password: 'password123'),
      throwsA(isFriendlyRateLimit()),
    );
  });

  test('sign up translates PocketBase 429 to a Persian auth error', () async {
    final service = rateLimitedService();

    await expectLater(
      service.signUp(email: 'user@example.test', password: 'password123'),
      throwsA(isFriendlyRateLimit()),
    );
  });

  test(
    'password reset translates PocketBase 429 to a Persian auth error',
    () async {
      final service = rateLimitedService();

      await expectLater(
        service.sendPasswordReset('user@example.test'),
        throwsA(isFriendlyRateLimit()),
      );
    },
  );

  test('sign in maps 400 to wrong-credentials Persian message', () async {
    final service = serviceWith(
      transport: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Failed to authenticate.'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      service.signIn(email: 'user@example.test', password: 'bad'),
      throwsA(
        isA<ZarAuthException>().having(
          (e) => e.message,
          'message',
          'ایمیل یا رمز عبور صحیح نیست.',
        ),
      ),
    );
  });

  test('sign in maps 503 to connection Persian message', () async {
    final service = serviceWith(
      transport: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'unavailable'}),
          503,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      service.signIn(email: 'user@example.test', password: 'password123'),
      throwsA(
        isA<ZarAuthException>().having(
          (e) => e.message,
          'message',
          'اتصال به سرور برقرار نشد. دوباره تلاش کنید.',
        ),
      ),
    );
  });

  test('sign up maps 400 to duplicate/short-password Persian message', () async {
    final service = serviceWith(
      transport: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'validation'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      service.signUp(email: 'user@example.test', password: 'x'),
      throwsA(
        isA<ZarAuthException>().having(
          (e) => e.message,
          'message',
          contains('ثبت‌نام انجام نشد'),
        ),
      ),
    );
  });

  test('successful sign-in emits authStateChanges', () async {
    final store = _InMemoryTokenStore();
    final service = serviceWith(
      tokenStore: store,
      transport: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'token': 'tok',
            'record': {'id': 'u1', 'email': 'user@example.test'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final events = <ZarAuthUser?>[];
    final sub = service.authStateChanges.listen(events.add);

    final user = await service.signIn(
      email: 'user@example.test',
      password: 'password123',
    );
    await Future<void>.delayed(Duration.zero);

    expect(user.uid, 'u1');
    expect(events.single?.uid, 'u1');
    expect(store.values[tokenKey], 'tok');
    await sub.cancel();
  });

  test('restoreSession no-ops when secure store is empty', () async {
    final service = serviceWith(
      transport: MockClient((_) async => http.Response('oops', 500)),
    );

    await service.restoreSession();

    expect(service.currentUser, isNull);
  });

  test('restoreSession clears store on 403', () async {
    final store = _InMemoryTokenStore()
      ..values[tokenKey] = 'stale'
      ..values[userIdKey] = 'u1'
      ..values[userEmailKey] = 'user@example.test';
    final service = serviceWith(
      tokenStore: store,
      transport: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'forbidden'}),
          403,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await service.restoreSession();

    expect(service.currentUser, isNull);
    expect(store.values.containsKey(tokenKey), isFalse);
  });

  test('restoreSession keeps store on transient 503', () async {
    final store = _InMemoryTokenStore()
      ..values[tokenKey] = 'keep-me'
      ..values[userIdKey] = 'u1'
      ..values[userEmailKey] = 'user@example.test';
    final service = serviceWith(
      tokenStore: store,
      transport: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'unavailable'}),
          503,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await service.restoreSession();

    expect(service.currentUser, isNull);
    expect(store.values[tokenKey], 'keep-me');
    expect(store.values[userIdKey], 'u1');
  });

  test('restoreSession hydrates currentUser on valid token', () async {
    final store = _InMemoryTokenStore()
      ..values[tokenKey] = 'good'
      ..values[userIdKey] = 'u1'
      ..values[userEmailKey] = 'fallback@example.test';
    final service = serviceWith(
      tokenStore: store,
      transport: MockClient((request) async {
        expect(request.headers['Authorization'], 'good');
        return http.Response(
          jsonEncode({'id': 'u1', 'email': 'user@example.test'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await service.restoreSession();

    expect(service.currentUser?.uid, 'u1');
    expect(service.currentUser?.email, 'user@example.test');
  });

  test('signOut emits null on authStateChanges', () async {
    final store = _InMemoryTokenStore();
    final service = serviceWith(
      tokenStore: store,
      transport: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'token': 'tok',
            'record': {'id': 'u1', 'email': 'user@example.test'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await service.signIn(email: 'user@example.test', password: 'password123');
    final events = <ZarAuthUser?>[];
    final sub = service.authStateChanges.listen(events.add);

    await service.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(service.currentUser, isNull);
    expect(events.single, isNull);
    expect(store.values.containsKey(tokenKey), isFalse);
    await sub.cancel();
  });
}
