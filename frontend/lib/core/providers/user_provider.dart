import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider que expõe o usuário atual do Firebase em tempo real.
/// Retorna null quando o usuário não está autenticado.
final userProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider conveniente para pegar apenas o User atual (sem o AsyncValue).
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(userProvider).value;
});
