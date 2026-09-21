import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'zar_auth_service.dart';

/// Chooses between the sign-in experience and the app itself.
///
/// Pass no [auth] service in local mode (no `ZAR_USE_FIREBASE`): the app
/// renders immediately, exactly like the pre-cloud builds. In cloud mode the
/// gate listens to the auth state and shows [LoginScreen] while signed out.
class ZarAuthGate extends StatelessWidget {
  const ZarAuthGate({super.key, required this.child, this.auth});

  final Widget child;
  final ZarAuthService? auth;

  @override
  Widget build(BuildContext context) {
    final service = auth;
    if (service == null) return child;
    return StreamBuilder<ZarAuthUser?>(
      stream: service.authStateChanges,
      initialData: null,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) return child;
        return LoginScreen(
          onSignIn: (email, password) =>
              service.signIn(email: email, password: password),
          onSignUp: (email, password) =>
              service.signUp(email: email, password: password),
          onResetPassword: service.sendPasswordReset,
        );
      },
    );
  }
}
