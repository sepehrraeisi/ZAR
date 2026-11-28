library;

/// Local DB encryption helpers (ADR Option A).
///
/// Native (`dart:io`) builds get SQLite3MultipleCiphers migration + Keystore
/// passphrase. Web builds use a plaintext stub so `flutter build web` (CI
/// preview) does not pull FFI `sqlite3` into the compile graph.
export 'zar_local_db_encryption_stub.dart'
    if (dart.library.io) 'zar_local_db_encryption_io.dart';
