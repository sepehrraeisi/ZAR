import 'package:firebase_auth/firebase_auth.dart';

import 'zar_auth_service.dart' show ZarAuthException, ZarAuthUser, ZarAuthService;

class FirebaseAuthService implements ZarAuthService {
  FirebaseAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  ZarAuthUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toUser(user);
  }

  @override
  Stream<ZarAuthUser?> get authStateChanges =>
      _auth.authStateChanges().map((user) => user == null ? null : _toUser(user));

  @override
  Future<ZarAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _toUser(credential.user!);
    } on FirebaseAuthException catch (error) {
      throw ZarAuthException(_persianMessage(error), code: error.code);
    }
  }

  @override
  Future<ZarAuthUser> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _toUser(credential.user!);
    } on FirebaseAuthException catch (error) {
      throw ZarAuthException(_persianMessage(error), code: error.code);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw ZarAuthException(_persianMessage(error), code: error.code);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  ZarAuthUser _toUser(User user) =>
      ZarAuthUser(uid: user.uid, email: user.email);

  String _persianMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'ایمیل واردشده معتبر نیست.';
      case 'email-already-in-use':
        return 'با این ایمیل قبلاً حساب ساخته شده است. وارد شوید.';
      case 'weak-password':
        return 'رمز عبور کوتاه است. حداقل ۶ نویسه انتخاب کنید.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'ایمیل یا رمز عبور صحیح نیست.';
      case 'user-disabled':
        return 'دسترسی این حساب غیرفعال شده است.';
      case 'too-many-requests':
        return 'تعداد تلاش‌ها زیاد بوده است. کمی بعد دوباره امتحان کنید.';
      case 'network-request-failed':
        return 'اتصال اینترنت برقرار نیست. دوباره تلاش کنید.';
      default:
        return 'ورود انجام نشد. دوباره تلاش کنید.';
    }
  }
}
