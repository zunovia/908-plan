import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

/// Anonymous sign-in that runs in the background (local-first: no screen
/// waits for it; the app keeps all data on the device).
final backgroundSignInProvider = Provider<BackgroundSignIn>((ref) {
  return BackgroundSignIn(() => ref.read(authServiceProvider));
});

/// Starts an anonymous sign-in when there is no user, at most one request at
/// a time. Never throws and never blocks the caller.
///
/// On networks that black-hole IPv6 a request can take ~8 minutes (Pixel 6a,
/// 2026-11); the app is fully usable meanwhile and the user simply arrives
/// later through `authStateChanges`.
class BackgroundSignIn {
  BackgroundSignIn(this._auth);

  final AuthService Function() _auth;
  Future<void>? _inFlight;

  /// True while a sign-in request is running.
  bool get isRunning => _inFlight != null;

  /// Fire-and-forget. Returns the running request (for tests), or null when
  /// nothing was started (already signed in, already running, or Firebase is
  /// unavailable).
  Future<void>? ensureSignedIn() {
    if (_inFlight != null) return null;
    final AuthService auth;
    try {
      auth = _auth();
      if (auth.currentUser != null) return null;
    } catch (_) {
      return null; // Firebase not initialized: stay local-only.
    }
    final run = Future.sync(auth.signInAnonymously)
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }
}

class AuthService {
  final FirebaseAuth _auth;

  AuthService(this._auth);

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  Future<UserCredential> linkWithApple() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user to link');
    final provider = OAuthProvider('apple.com');
    return await user.linkWithProvider(provider);
  }

  Future<UserCredential> linkWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user to link');
    final provider = GoogleAuthProvider();
    return await user.linkWithProvider(provider);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }
}
