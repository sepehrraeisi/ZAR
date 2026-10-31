import 'dart:convert';

import 'package:flutter_app/data/pocketbase/zar_pocketbase_client.dart';
import 'package:flutter_app/features/auth/zar_auth_service.dart';
import 'package:flutter_app/features/auth/zar_pocketbase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const expectedMessage =
      'تعداد درخواست‌ها بیش از حد مجاز است. کمی صبر کنید و دوباره تلاش کنید.';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ZarPocketBaseAuthService rateLimitedService() {
    final transport = MockClient(
      (_) async => http.Response(
        jsonEncode({'message': 'Too many requests.'}),
        429,
        headers: {'content-type': 'application/json'},
      ),
    );
    return ZarPocketBaseAuthService(
      client: ZarPocketBaseClient(
        baseUrl: 'https://pb.invalid',
        client: transport,
      ),
    );
  }

  Matcher isFriendlyRateLimit() => isA<ZarAuthException>().having(
    (error) => error.message,
    'message',
    expectedMessage,
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
}
