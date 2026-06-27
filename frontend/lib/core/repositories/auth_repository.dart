import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Falha ao autenticar');
    }
  }

  Future<void> signOut() async => await _auth.signOut();

  Stream<User?> authStateChanges() => _auth.authStateChanges();
}
