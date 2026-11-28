import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

import 'zar_local_db_key_store.dart';

/// Escape a SQLite string literal (single-quote doubling).
String zarEscapeSqlString(String source) => source.replaceAll("'", "''");

bool zarHasCipher(CommonDatabase database) {
  try {
    return database.select('PRAGMA cipher;').isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// One-time plaintext → encrypted migration (Drift docs / SQLite3MultipleCiphers).
///
/// Copies [plaintextPath] via `VACUUM INTO`, applies `PRAGMA rekey`, then
/// replaces [encryptedPath] and deletes the plaintext file.
Future<void> zarMigratePlaintextToEncrypted({
  required String plaintextPath,
  required String encryptedPath,
  required String passphrase,
}) async {
  final existing = File(plaintextPath);
  final encrypted = File(encryptedPath);
  if (!await existing.exists() || await encrypted.exists()) {
    return;
  }

  final tmp = File('${encrypted.path}.tmp');
  if (await tmp.exists()) {
    await tmp.delete();
  }

  final escapedTmp = zarEscapeSqlString(tmp.path);
  final escapedKey = zarEscapeSqlString(passphrase);

  final plaintextDb = sqlite3.open(plaintextPath)
    ..execute("VACUUM INTO '$escapedTmp'");
  plaintextDb.close();

  final encryptedDb = sqlite3.open(tmp.path);
  if (!zarHasCipher(encryptedDb)) {
    encryptedDb.close();
    if (await tmp.exists()) {
      await tmp.delete();
    }
    throw StateError(
      'SQLite3MultipleCiphers is not available; cannot encrypt local DB.',
    );
  }
  encryptedDb.execute("PRAGMA rekey = '$escapedKey'");
  encryptedDb.close();

  await tmp.rename(encryptedPath);
  await existing.delete();
}

/// Opens the production local DB executor.
///
/// On Android release/device builds: encrypted file `zar_plus_local_enc.sqlite`
/// with Keystore-derived passphrase, migrating `zar_plus_local.sqlite` once.
/// Elsewhere (tests / desktop): plaintext `zar_plus_local` via [driftDatabase].
Future<QueryExecutor> openZarLocalQueryExecutor({
  ZarLocalDbKeyStore? keyStore,
  bool forcePlaintext = false,
}) async {
  final useEncryption =
      !forcePlaintext &&
      !kIsWeb &&
      !kDebugMode && // keep debug plaintext for hot-reload ergonomics
      Platform.isAndroid;

  if (!useEncryption) {
    return driftDatabase(name: 'zar_plus_local');
  }

  final passphrase = await (keyStore ?? ZarLocalDbKeyStore()).ensurePassphrase();
  final docs = await getApplicationDocumentsDirectory();
  final sep = Platform.pathSeparator;
  final plaintextPath = '${docs.path}${sep}zar_plus_local.sqlite';
  final encryptedPath = '${docs.path}${sep}zar_plus_local_enc.sqlite';

  await zarMigratePlaintextToEncrypted(
    plaintextPath: plaintextPath,
    encryptedPath: encryptedPath,
    passphrase: passphrase,
  );

  final escapedKey = zarEscapeSqlString(passphrase);
  return driftDatabase(
    name: 'zar_plus_local_enc',
    native: DriftNativeOptions(
      databasePath: () async => encryptedPath,
      setup: (db) {
        if (!zarHasCipher(db)) {
          throw StateError(
            'SQLite3MultipleCiphers is not available; cannot open encrypted DB.',
          );
        }
        db.execute("PRAGMA key = '$escapedKey'");
      },
    ),
  );
}
