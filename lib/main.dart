import 'package:flutter/widgets.dart';
import 'main_phase_a2.dart' as phase_a2;

export 'app_core.dart';

/// Production/default entrypoint for the current pre-Firebase ZAR+ build.
///
/// The original Genspark Phase A.1 implementation is preserved in
/// `app_core.dart`; Phase A.2 now owns the default launch path.
void main() {
  runApp(const phase_a2.ZarPlusPhaseA2App());
}
