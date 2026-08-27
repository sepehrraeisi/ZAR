import 'package:flutter/widgets.dart';

import 'features/notifications/native_notification_runtime.dart';
import 'repository_phase_a2_app_v2.dart';

export 'app_core.dart';

/// Production/default entrypoint for the current pre-Firebase ZAR+ build.
///
/// Native notification infrastructure is installed at startup, but permission
/// is deliberately NOT requested here. The user must opt in from the app's
/// notification settings.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ZarNativeNotificationRuntime.instance.install();
  runApp(const RepositoryZarPlusAppV2());
}
