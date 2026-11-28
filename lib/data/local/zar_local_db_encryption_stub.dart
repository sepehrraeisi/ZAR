import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'zar_local_db_key_store.dart';

/// Escape a SQLite string literal (single-quote doubling).
String zarEscapeSqlString(String source) => source.replaceAll("'", "''");

/// Web/stub: encryption libraries are unavailable.
bool zarHasCipher(Object database) => false;

/// Web/stub: no-op (encryption is native-only).
Future<void> zarMigratePlaintextToEncrypted({
  required String plaintextPath,
  required String encryptedPath,
  required String passphrase,
}) async {}

/// Web/stub: always plaintext Drift opener for CI web preview.
Future<QueryExecutor> openZarLocalQueryExecutor({
  ZarLocalDbKeyStore? keyStore,
  bool forcePlaintext = false,
}) async {
  return driftDatabase(name: 'zar_plus_local');
}
