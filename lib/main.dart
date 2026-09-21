import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'data/local/zar_local_database.dart';
import 'data/local/zar_local_repository.dart';
import 'features/auth/firebase_auth_service.dart';
import 'features/auth/zar_auth_gate.dart';
import 'features/notifications/native_notification_runtime.dart';
import 'repository_phase_a2_app_v2.dart';

export 'app_core.dart';

/// Production entrypoint for ZAR+ — local-first by default.
///
/// Default (no defines): Drift/SQLite persistence, no Firebase touched at all.
///
/// Cloud mode (`--dart-define=ZAR_USE_FIREBASE=true`): wraps the shell in the
/// auth gate (email/password sign-in). Requires the Firebase project
/// configuration for `com.zarplus.app`; until `google-services.json` is in
/// place, cloud mode fails at startup by design and local mode stays the
/// supported path. Data still persists through the local repository in cloud
/// mode until the Firestore-backed repository lands behind the same shell.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ZarNativeNotificationRuntime.instance.install();
  const useFirebase = bool.fromEnvironment('ZAR_USE_FIREBASE');
  if (useFirebase) {
    await Firebase.initializeApp();
    runApp(
      ZarAuthGate(
        auth: FirebaseAuthService(),
        child: RepositoryZarPlusAppV2(repository: ZarLocalRepository(ZarLocalDatabase.defaults())),
      ),
    );
    return;
  }
  final repository = ZarLocalRepository(ZarLocalDatabase.defaults());
  await repository.ensureReady();
  runApp(RepositoryZarPlusAppV2(repository: repository));
}
