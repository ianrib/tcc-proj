import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase Core
import 'package:flutter_dotenv/flutter_dotenv.dart'; // dotenv for environment variables
import 'dart:io';
import 'package:flutter/foundation.dart'; // dotenv for environment variables
import 'core/services/notification_service.dart';

Future<void> _setupPortForward() async {
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await Process.run('adb', ['reverse', 'tcp:8000', 'tcp:8000']);
      debugPrint('Port forwarding set up via adb reverse');
    } catch (e) {
      debugPrint('Failed to set up adb reverse: $e');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _setupPortForward();

  // Inicializa o serviço de notificações locais
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint("Erro ao inicializar o NotificationService: $e");
  }

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Erro ao carregar .env: $e");
  }

  try {
    await Firebase.initializeApp(); // Initialize Firebase
  } catch (e) {
    debugPrint("Erro ao inicializar o Firebase: $e");
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Apoio Psicológico Complementar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Foco em design escuro premium por padrão
      routerConfig: router,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
      ),
    );
  }
}
