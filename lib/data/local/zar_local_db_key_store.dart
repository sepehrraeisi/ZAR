import 'dart:convert';
import 'dart:math';

import '../../features/auth/zar_token_store.dart';

/// Keystore-backed passphrase for the local Drift DB (ADR Option A).
///
/// No shopkeeper UI — material lives only in [ZarSecureTokenStore].
class ZarLocalDbKeyStore {
  ZarLocalDbKeyStore({ZarTokenStore? tokenStore})
    : _tokens = tokenStore ?? ZarSecureTokenStore();

  static const passphraseKey = 'zar.local.db.passphrase.v1';

  final ZarTokenStore _tokens;

  /// Returns an existing passphrase or creates and persists a new one.
  Future<String> ensurePassphrase() async {
    final existing = await _tokens.read(passphraseKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final created = _newPassphrase();
    await _tokens.write(passphraseKey, created);
    return created;
  }

  String _newPassphrase() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
