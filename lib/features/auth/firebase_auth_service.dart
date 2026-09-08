import 'package:firebase_auth/firebase_auth.dart';

class ZarAuthException implements Exception {
  const ZarAuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw ZarAuthException(_persianMessage(error), code: error.code);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw ZarAuthException(_persianMessage(error), code: error.code);
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _persianMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'ایمیل واردشده معتبر نیست.';
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
