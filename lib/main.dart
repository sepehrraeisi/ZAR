import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'data/local/zar_local_database.dart';
import 'data/local/zar_local_repository.dart';
import 'data/pocketbase/zar_pocketbase_client.dart';
import 'features/auth/firebase_auth_service.dart';
import 'features/auth/zar_auth_gate.dart';
import 'features/auth/zar_cloud_shell.dart';
import 'features/auth/zar_pocketbase_auth_service.dart';
import 'features/notifications/native_notification_runtime.dart';
import 'repository_phase_a2_app_v2.dart';

export 'app_core.dart';

/// Production entrypoint for ZAR+ — local-first by default.
///
/// Three startup modes, picked by dart-defines:
///
/// 1. Default: Drift/SQLite persistence, no network at all.
/// 2. `--dart-define=ZAR_SERVER_URL=https://...`: self-hosted PocketBase
///    server — email/password sign-in plus the cloud-backed repository. The
///    supported multi-device path (see server/README.md).
/// 3. `--dart-define=ZAR_USE_FIREBASE=true`: Firebase Auth gate (requires the
///    Firebase project configuration; data stays local until the Firestore
///    repository lands).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ZarNativeNotificationRuntime.instance.install();

  const serverUrl = String.fromEnvironment('ZAR_SERVER_URL');
  if (serverUrl.isNotEmpty) {
    final client = ZarPocketBaseClient(baseUrl: serverUrl);
    final auth = ZarPocketBaseAuthService(client: client);
    await auth.restoreSession();
    runApp(
      ZarAuthGate(
        auth: auth,
        child: ZarCloudShell(auth: auth, client: client),
      ),
    );
    return;
  }

  const useFirebase = bool.fromEnvironment('ZAR_USE_FIREBASE');
  if (useFirebase) {
    await Firebase.initializeApp();
    runApp(
      ZarAuthGate(
        auth: FirebaseAuthService(),
        child: RepositoryZarPlusAppV2(
          repository: ZarLocalRepository(ZarLocalDatabase.defaults()),
        ),
      ),
    );
    return;
  }

  final repository = ZarLocalRepository(ZarLocalDatabase.defaults());
  await repository.ensureReady();
  runApp(RepositoryZarPlusAppV2(repository: repository));
}
