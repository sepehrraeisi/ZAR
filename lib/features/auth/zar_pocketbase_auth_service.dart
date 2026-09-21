import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/pocketbase/zar_pocketbase_client.dart';
import 'zar_auth_service.dart';

/// PocketBase-backed [ZarAuthService] — email/password sign-in on the default
/// `users` auth collection, with the token persisted so the session survives
/// app restarts.
class ZarPocketBaseAuthService implements ZarAuthService {
  ZarPocketBaseAuthService({required ZarPocketBaseClient client})
    : _client = client;

  final ZarPocketBaseClient _client;
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
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getString(_userIdKey);
    if (token == null || userId == null) return;
    try {
      _client.authToken = token;
      final record = await _client.getRecord('users', id: userId);
      _emit(
        ZarAuthUser(
          uid: userId,
          email: (record['email'] as String?) ?? prefs.getString(_userEmailKey),
        ),
      );
    } catch (_) {
      await _clear(prefs);
    }
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
    await _client.requestPasswordReset('users', email: email);
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await _clear(prefs);
    _emit(null);
  }

  void _emit(ZarAuthUser? user) {
    _currentUser = user;
    _state.add(user);
  }

  Future<void> _persist(
    String token,
    Map<String, Object?> record,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, record['id']! as String);
    await prefs.setString(_userEmailKey, (record['email'] as String?) ?? '');
    _client.authToken = token;
  }

  Future<void> _clear(SharedPreferences prefs) async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    _client.authToken = null;
  }

  String _friendlyMessage(ZarPocketBaseException error) {
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
