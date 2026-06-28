import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/graphics/presentation/mood_history_screen.dart';
import '../../features/settings/presentation/face_scan_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
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
    ],
  );
});
