import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gaia/core/widgets/app_drawer.dart';
import 'package:gaia/core/repositories/auth_repository.dart';
import 'package:gaia/core/providers/user_provider.dart';
import 'package:gaia/core/widgets/user_avatar.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/chat_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(userProvider);
    final currentThemeMode = ref.watch(themeProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        context.go('/chat');
      },
      child: Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.grid_view, color: theme.colorScheme.secondary),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Configurações',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ── SEÇÃO: APARÊNCIA (GERENCIAMENTO DE TEMA) ──────────────────────────────
          _buildSectionHeader(context, "Aparência"),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getThemeIcon(currentThemeMode),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: const Text(
                      'Tema do Aplicativo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      _getThemeModeLabel(currentThemeMode),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                    trailing: DropdownButton<ThemeMode>(
                      value: currentThemeMode,
                      underline: const SizedBox(),
                      dropdownColor: theme.colorScheme.surface,
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text("Claro"),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text("Escuro"),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text("Automático"),
                        ),
                      ],
                      onChanged: (ThemeMode? newMode) {
                        if (newMode != null) {
                          ref.read(themeProvider.notifier).setThemeMode(newMode);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── SEÇÃO: CONTA (FIREBASE & LOGOUT) ──────────────────────────────────
          _buildSectionHeader(context, "Conta"),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: userAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text("Erro ao carregar dados: $e")),
                data: (user) {
                  final email = user?.email ?? 'Sem e-mail';
                  final displayName = user?.displayName ?? 'Usuário';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const UserAvatar(radius: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Divider(color: theme.dividerColor.withValues(alpha: 0.2), height: 1),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _handleLogout(context, ref),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text(
                          'Mudar de Conta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error.withValues(alpha: 0.1),
                          foregroundColor: theme.colorScheme.error,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── SEÇÃO: INFORMAÇÕES DO TCC (PRIVACIDADE) ───────────────────────────
          _buildSectionHeader(context, "Privacidade"),
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.secondary.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: theme.colorScheme.secondary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Privacy by Design & LGPD",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Este aplicativo processa todas as fotos capturadas na detecção facial de humor "
                    "estritamente em memória RAM volátil. Nenhum arquivo ou registro de imagem biométrica "
                    "é persistido localmente ou enviado a terceiros, garantindo conformidade absoluta com a LGPD.",
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.secondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.settings_brightness_outlined;
    }
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return "Tema Claro ativado";
      case ThemeMode.dark:
        return "Tema Escuro ativado";
      case ThemeMode.system:
        return "Respeitando as preferências do sistema operacional";
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    // Diálogo de confirmação
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirmar saída"),
          content: const Text("Deseja desconectar a sua conta atual para entrar com uma nova?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text("Sair"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // Diálogo de carregamento/processamento
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final authRepo = AuthRepository();
      // Executa a troca de conta estilo YouTube
      final user = await authRepo.switchGoogleAccount();

      // Fecha o diálogo de carregamento
      if (context.mounted) {
        Navigator.of(context).pop(); // fecha carregando
        if (user != null) {
          // Limpa IDs de sessões de chat do Riverpod antes de conectar na nova conta
          ref.read(activeSessionIdProvider.notifier).state = null;
          context.go('/chat');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Conta alterada com sucesso!"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Se cancelado, permanece logado na mesma conta
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Troca de conta cancelada."),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // fecha carregando
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao mudar de conta: $e"),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }
}
