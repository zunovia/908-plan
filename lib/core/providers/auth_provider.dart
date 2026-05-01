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
