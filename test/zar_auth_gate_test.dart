import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/auth/zar_auth_gate.dart';
import 'package:flutter_app/features/auth/zar_auth_service.dart';

class _FakeAuthService implements ZarAuthService {
  final controller = ZarAuthStateController();
  int signInCalls = 0;
  int signUpCalls = 0;
  Object? nextError;

  @override
  ZarAuthUser? get currentUser => controller.current;

  @override
  Stream<ZarAuthUser?> get authStateChanges => controller.stream;

  @override
  Future<ZarAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    final error = nextError;
    if (error != null) throw error;
    final user = ZarAuthUser(uid: 'u1', email: email);
    controller.current = user;
    return user;
  }

  @override
  Future<ZarAuthUser> signUp({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    final error = nextError;
    if (error != null) throw error;
    final user = ZarAuthUser(uid: 'u2', email: email);
    controller.current = user;
    return user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {
    controller.current = null;
  }
}

Widget _app(_FakeAuthService? auth) => MaterialApp(
  home: ZarAuthGate(
    auth: auth,
    child: const Scaffold(body: Text('shell-reached')),
  ),
);

void main() {
  testWidgets('local mode (no auth service) renders the shell directly', (
    tester,
  ) async {
    await tester.pumpWidget(_app(null));
    expect(find.text('shell-reached'), findsOneWidget);
    expect(find.text('ورود'), findsNothing);
  });

  testWidgets('cloud mode starts signed out on the login screen', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(_app(auth));
    await tester.pump();
    expect(find.text('ورود'), findsOneWidget);
    expect(find.text('shell-reached'), findsNothing);
  });

  testWidgets('sign-in flows through the gate into the shell', (tester) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(_app(auth));
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'owner@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret1');
    await tester.tap(find.text('ورود'));
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 1);
    expect(find.text('shell-reached'), findsOneWidget);
  });

  testWidgets('sign-up toggle creates an account and enters the shell', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(_app(auth));
    await tester.pump();

    await tester.tap(find.text('حساب ندارید؟ ساخت حساب'));
    await tester.pumpAndSettle();
    expect(find.text('ساخت حساب'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'owner@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret1');
    await tester.tap(find.text('ساخت حساب').first);
    await tester.pumpAndSettle();

    expect(auth.signUpCalls, 1);
    expect(find.text('shell-reached'), findsOneWidget);
  });

  testWidgets('auth failures show the Persian message and stay on login', (
    tester,
  ) async {
    final auth = _FakeAuthService()
      ..nextError = const ZarAuthException('ایمیل یا رمز عبور صحیح نیست.');
    await tester.pumpWidget(_app(auth));
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'owner@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('ورود'));
    await tester.pumpAndSettle();

    expect(find.text('ایمیل یا رمز عبور صحیح نیست.'), findsOneWidget);
    expect(find.text('shell-reached'), findsNothing);
  });
}
