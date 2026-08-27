import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/auth/login_screen.dart';

void main() {
  testWidgets('login validates required fields and submits credentials', (tester) async {
    String? submittedEmail;
    String? submittedPassword;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onSignIn: (email, password) async {
            submittedEmail = email;
            submittedPassword = password;
          },
          onResetPassword: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('ورود'));
    await tester.pump();
    expect(find.text('ایمیل و رمز عبور را وارد کنید.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'ایمیل'), 'user@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'رمز عبور'), 'secret123');
    await tester.tap(find.text('ورود'));
    await tester.pumpAndSettle();

    expect(submittedEmail, 'user@example.com');
    expect(submittedPassword, 'secret123');
  });

  testWidgets('password reset requires email', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onSignIn: (_, __) async {},
          onResetPassword: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('فراموشی رمز عبور'));
    await tester.pump();
    expect(find.text('ابتدا ایمیل خود را وارد کنید.'), findsOneWidget);
  });
}
