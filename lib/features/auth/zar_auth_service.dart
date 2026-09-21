import 'dart:async';

/// Authentication boundary used by the app shell.
///
/// The concrete Firebase implementation is only touched when the cloud mode
/// (`ZAR_USE_FIREBASE` dart-define) is active; local mode passes no auth
/// service at all and the shell renders without a gate. Tests provide fakes.
abstract class ZarAuthService {
  ZarAuthService();

  /// Emits the signed-in user (or null) whenever auth state changes.
  Stream<ZarAuthUser?> get authStateChanges;

  /// Currently signed-in user, or null when signed out.
  ZarAuthUser? get currentUser;

  Future<ZarAuthUser> signIn({
    required String email,
    required String password,
  });

  Future<ZarAuthUser> signUp({
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

/// Raised by auth operations with a ready-to-show Persian message.
class ZarAuthException implements Exception {
  const ZarAuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Provider-neutral identity snapshot for the UI layer.
class ZarAuthUser {
  const ZarAuthUser({required this.uid, required this.email});

  final String uid;
  final String? email;
}

/// Replays an initial value then forwards later state changes; shared by the
/// Firebase implementation and test fakes.
class ZarAuthStateController {
  final StreamController<ZarAuthUser?> _controller =
      StreamController<ZarAuthUser?>.broadcast();

  ZarAuthUser? _current;

  ZarAuthUser? get current => _current;

  set current(ZarAuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  Stream<ZarAuthUser?> get stream => _controller.stream;

  Future<void> close() => _controller.close();
}
