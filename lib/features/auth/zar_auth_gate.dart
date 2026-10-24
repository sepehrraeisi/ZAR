import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../features/theme/zar_theme.dart';
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
        // `service.currentUser` covers the restore-session path: the service
        // emits before the gate subscribes (runApp happens after
        // restoreSession), and a broadcast stream drops that event.
        final user = snapshot.data ?? service.currentUser;
        if (user != null) return child;
        // The login screen renders before any MaterialApp exists (the shell's
        // MaterialApp mounts only after sign-in), so provide one here —
        // TextField/Theme need MaterialLocalizations. It carries the ZAR+
        // design tokens (gold seed, Vazirmatn) and Persian localizations so
        // the sign-in experience matches the rest of the app.
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: zarBuildTheme(Brightness.light),
          darkTheme: zarBuildTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: LoginScreen(
            onSignIn: (email, password) =>
                service.signIn(email: email, password: password),
            onSignUp: (email, password) =>
                service.signUp(email: email, password: password),
            onResetPassword: service.sendPasswordReset,
          ),
        );
      },
    );
  }
}
