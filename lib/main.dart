import 'package:flutter/widgets.dart';
import 'repository_phase_a2_app.dart';

export 'app_core.dart';

/// Production/default entrypoint for the current pre-Firebase ZAR+ build.
///
/// The original Genspark Phase A.1 implementation is preserved in
/// `app_core.dart`. The default Phase A.2 launch path is now backed by the
/// production repository boundary through `ZarPhaseA2Store`.
void main() {
  runApp(const RepositoryZarPlusApp());
}
