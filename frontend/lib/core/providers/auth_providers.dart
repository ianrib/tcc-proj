import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/auth_repository.dart';

/// Provider for the AuthRepository instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
