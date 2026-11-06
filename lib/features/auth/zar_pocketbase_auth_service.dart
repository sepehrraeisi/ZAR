import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/pocketbase/zar_pocketbase_client.dart';
import 'zar_auth_service.dart';
import 'zar_token_store.dart';

/// PocketBase-backed [ZarAuthService] — email/password sign-in on the default
/// `users` auth collection, with the token persisted so the session survives
/// app restarts.
class ZarPocketBaseAuthService implements ZarAuthService {
  ZarPocketBaseAuthService({required ZarPocketBaseClient client, ZarTokenStore? tokenStore})
    : _client = client,
      _tokenStore = tokenStore ?? ZarSecureTokenStore();

  final ZarPocketBaseClient _client;
  final ZarTokenStore _tokenStore;
  ZarAuthUser? _currentUser;

  static const _tokenKey = 'zar_pb_token';
  static const _userIdKey = 'zar_pb_user_id';
  static const _userEmailKey = 'zar_pb_user_email';

  @override
  ZarAuthUser? get currentUser => _currentUser;

  final _state = StreamController<ZarAuthUser?>.broadcast();

  @override
  Stream<ZarAuthUser?> get authStateChanges => _state.stream;

  /// Restores a persisted session (if any) by validating its token against
  /// the server. Await this before the gate renders in cloud mode.
  ///
  /// A rejected token (401/403) clears the persisted session, but transient
  /// failures (offline, 5xx) keep it — the next launch retries instead of
  /// signing the user out over a network blip.
  Future<void> restoreSession() async {
    await _migrateLegacyPreferencesIntoSecureStore();
    final token = await _tokenStore.read(_tokenKey);
    final userId = await _tokenStore.read(_userIdKey);
    if (token == null || userId == null) return;
    try {
      _client.authToken = token;
      final record = await _client.getRecord('users', id: userId);
      _emit(
        ZarAuthUser(
          uid: userId,
          email:
              (record['email'] as String?) ??
              await _tokenStore.read(_userEmailKey),
        ),
      );
    } on ZarPocketBaseException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clear();
      }
    }
  }

  /// Sessions before the Keystore migration lived in plain-text shared
  /// preferences. Move them once, then scrub the legacy keys.
  Future<void> _migrateLegacyPreferencesIntoSecureStore() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);
    if (legacyToken == null) return;
    final existing = await _tokenStore.read(_tokenKey);
    if (existing == null) {
      await _tokenStore.write(_tokenKey, legacyToken);
      final legacyUserId = prefs.getString(_userIdKey);
      if (legacyUserId != null) {
        await _tokenStore.write(_userIdKey, legacyUserId);
      }
      final legacyEmail = prefs.getString(_userEmailKey);
      if (legacyEmail != null) {
        await _tokenStore.write(_userEmailKey, legacyEmail);
      }
    }
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
  }

  @override
  Future<ZarAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _client.authWithPassword(
        'users',
        identity: email,
        password: password,
      );
      await _persist(result.token, result.record);
      final user = ZarAuthUser(
        uid: result.record['id']! as String,
        email: result.record['email'] as String?,
      );
      _emit(user);
      return user;
    } on ZarPocketBaseException catch (error) {
      if (error.statusCode == 400) {
        throw const ZarAuthException('ایمیل یا رمز عبور صحیح نیست.');
      }
      throw ZarAuthException(_friendlyMessage(error));
    }
  }

  @override
  Future<ZarAuthUser> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _client.createRecord('users', {
        'email': email,
        'password': password,
        'passwordConfirm': password,
      });
    } on ZarPocketBaseException catch (error) {
      if (error.statusCode == 400) {
        throw const ZarAuthException(
          'ثبت‌نام انجام نشد. این ایمیل ممکن است قبلاً ثبت شده باشد یا رمز عبور کوتاه باشد.',
        );
      }
      throw ZarAuthException(_friendlyMessage(error));
    }
    return signIn(email: email, password: password);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.requestPasswordReset('users', email: email);
    } on ZarPocketBaseException catch (error) {
      throw ZarAuthException(_friendlyMessage(error));
    }
  }

  @override
  Future<void> signOut() async {
    await _clear();
    _emit(null);
  }

  void _emit(ZarAuthUser? user) {
    _currentUser = user;
    _state.add(user);
  }

  Future<void> _persist(String token, Map<String, Object?> record) async {
    await _tokenStore.write(_tokenKey, token);
    await _tokenStore.write(_userIdKey, record['id']! as String);
    await _tokenStore.write(_userEmailKey, (record['email'] as String?) ?? '');
    _client.authToken = token;
  }

  Future<void> _clear() async {
    await _tokenStore.delete(_tokenKey);
    await _tokenStore.delete(_userIdKey);
    await _tokenStore.delete(_userEmailKey);
    _client.authToken = null;
  }

  String _friendlyMessage(ZarPocketBaseException error) {
    if (error.statusCode == 429) {
      return 'تعداد درخواست‌ها بیش از حد مجاز است. کمی صبر کنید و دوباره تلاش کنید.';
    }
    if (error.statusCode == 0 ||
        (error.statusCode >= 500 && error.statusCode < 600)) {
      return 'اتصال به سرور برقرار نشد. دوباره تلاش کنید.';
    }
    if (error.message.contains('validation')) {
      return 'اطلاعات واردشده معتبر نیست.';
    }
    return error.message;
  }
}
