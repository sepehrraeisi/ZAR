import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  /// Firebase remains opt-in until the final `com.zarplus.app` configuration
  /// files/options are provided. CI and mock previews therefore never connect
  /// to an accidental/legacy Firebase project.
  static const bool enabled = bool.fromEnvironment('ZAR_USE_FIREBASE', defaultValue: false);

  static Future<bool> initializeIfEnabled({FirebaseOptions? options}) async {
    if (!enabled) return false;
    if (Firebase.apps.isNotEmpty) return true;
    await Firebase.initializeApp(options: options);
    return true;
  }
}
