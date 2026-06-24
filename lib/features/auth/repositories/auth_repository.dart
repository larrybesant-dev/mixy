// lib/features/auth/repositories/auth_repository.dart
//
// Firebase implementation of IAuthRepository.
// This is the ONLY place that calls FirebaseAuth methods.
// UI and service layers depend on IAuthRepository, not FirebaseAuth directly.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'i_auth_repository.dart';

class AuthRepository implements IAuthRepository {
  final FirebaseAuth _auth;

  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  @override
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) =>
      _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);

  @override
  Future<UserCredential> signInWithGoogle() async {
    // Google Sign-In is temporarily disabled pending post-launch testing.
    // Re-enable by integrating google_sign_in v7 here.
    throw UnimplementedError('Google Sign-In is not yet enabled');
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<void> deleteAccount() async {
    if (_auth.currentUser == null) throw Exception('No authenticated user');
    await _auth.currentUser!.delete();
  }
}

/// Riverpod provider — inject IAuthRepository everywhere (not the concrete class).
final authRepositoryProvider = Provider<IAuthRepository>(
  (ref) => AuthRepository(),
);
