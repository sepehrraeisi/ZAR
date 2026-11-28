import 'dart:io';

import 'package:flutter_app/data/local/zar_local_db_encryption.dart';
import 'package:flutter_app/data/local/zar_local_db_key_store.dart';
import 'package:flutter_app/features/auth/zar_token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

class _MemoryTokenStore implements ZarTokenStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

void main() {
  test('zarEscapeSqlString doubles single quotes', () {
    expect(zarEscapeSqlString("a'b"), "a''b");
    expect(zarEscapeSqlString('plain'), 'plain');
  });

  test('ZarLocalDbKeyStore persists passphrase across reads', () async {
    final store = _MemoryTokenStore();
    final keys = ZarLocalDbKeyStore(tokenStore: store);
    final first = await keys.ensurePassphrase();
    final second = await keys.ensurePassphrase();
    expect(first, isNotEmpty);
    expect(second, first);
    expect(first.contains('='), isFalse);
  });

  test('plaintext → encrypted migration when cipher is available', () async {
    final dir = await Directory.systemTemp.createTemp('zar-enc-spike-');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final probe = sqlite3.openInMemory();
    final hasCipher = zarHasCipher(probe);
    probe.close();
    if (!hasCipher) {
      // CI/desktop without sqlite3mc hooks: document skip, do not fail suite.
      // ignore: avoid_print
      print('SKIP migration: PRAGMA cipher unavailable in this environment');
      return;
    }

    final plain = File('${dir.path}${Platform.pathSeparator}plain.sqlite');
    final enc = File('${dir.path}${Platform.pathSeparator}enc.sqlite');
    final seed = sqlite3.open(plain.path);
    seed.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT);');
    seed.execute("INSERT INTO t (name) VALUES ('shop');");
    seed.close();

    const passphrase = 'spike-test-key';
    await zarMigratePlaintextToEncrypted(
      plaintextPath: plain.path,
      encryptedPath: enc.path,
      passphrase: passphrase,
    );

    expect(await plain.exists(), isFalse);
    expect(await enc.exists(), isTrue);

    final wrong = sqlite3.open(enc.path);
    wrong.execute("PRAGMA key = 'wrong';");
    expect(
      () => wrong.select('SELECT count(*) AS c FROM t;'),
      throwsA(isA<SqliteException>()),
    );
    wrong.close();

    final right = sqlite3.open(enc.path);
    right.execute("PRAGMA key = '$passphrase';");
    final rows = right.select('SELECT name FROM t;');
    expect(rows.single['name'], 'shop');
    right.close();
  });
}
