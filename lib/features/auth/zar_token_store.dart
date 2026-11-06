import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists PocketBase session material outside plain-text shared preferences.
abstract class ZarTokenStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Android-backed [ZarTokenStore]: EncryptedSharedPreferences over the
/// Android Keystore, so the PocketBase auth token never sits in a
/// world-readable XML file.
class ZarSecureTokenStore implements ZarTokenStore {
  ZarSecureTokenStore({FlutterSecureStorage? store})
    : _store =
        store ??
        const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _store;

  @override
  Future<String?> read(String key) => _store.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _store.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _store.delete(key: key);
}
