import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/user_provider.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/graphics/presentation/mood_history_screen.dart';
import '../../features/settings/presentation/face_scan_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/profile/presentation/user_profile_screen.dart';
import '../../features/reminders/presentation/reminders_screen.dart';


final routerProvider = Provider<GoRouter>((ref) {
  final userAsync = ref.watch(userProvider);

  return GoRouter(
    initialLocation: '/chat', // Start at chat, let redirect redirect to login if needed
    redirect: (context, state) {
      // Se estiver carregando, usamos o cache síncrono do Firebase Auth
      // para evitar oscilar a tela de login ao abrir o app
      final user = userAsync.valueOrNull ?? FirebaseAuth.instance.currentUser;
      final loggedIn = user != null;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!loggedIn) {
        // Se não estiver logado e não estiver na tela de login/cadastro, redireciona para login
        return isLoggingIn ? null : '/login';
      }

      // Se estiver logado e tentar ir para login ou cadastro, vai para o chat
      if (isLoggingIn) {
        return '/chat';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: '/mood-history',
        builder: (context, state) => const MoodHistoryScreen(),
      ),
      GoRoute(
        path: '/face-scan',
        builder: (context, state) => const FaceScanScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const UserProfileScreen(),
      ),
      GoRoute(
        path: '/reminders',
        builder: (context, state) => const RemindersScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
