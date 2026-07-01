import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tcc_apoio_psicologico/core/providers/user_provider.dart';
import 'package:tcc_apoio_psicologico/core/repositories/auth_repository.dart';

// ── Modelo simples de sessão de chat ─────────────────────────────────────────
class ChatSession {
  final String id;
  final String title;
  final DateTime updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
  });
}

// ── Provider com lista de histórico de chats (mock inicial) ───────────────────
// Futuramente pode ser substituído por dados reais do Firestore
class ChatHistoryNotifier extends StateNotifier<List<ChatSession>> {
  ChatHistoryNotifier()
      : super([
          ChatSession(
            id: 'sessao_tcc_1',
            title: 'Como estou me sentindo hoje',
            updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
          ChatSession(
            id: 'sessao_tcc_2',
            title: 'Ansiedade antes da prova',
            updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          ChatSession(
            id: 'sessao_tcc_3',
            title: 'Dificuldade para dormir',
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          ChatSession(
            id: 'sessao_tcc_4',
            title: 'Sentindo-me sobrecarregado',
            updatedAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
        ]);

  void addSession(ChatSession session) {
    state = [session, ...state];
  }

  void removeSession(String id) {
    state = state.where((s) => s.id != id).toList();
  }
}

final chatHistoryProvider =
    StateNotifierProvider<ChatHistoryNotifier, List<ChatSession>>(
  (ref) => ChatHistoryNotifier(),
);

// ── Drawer principal ──────────────────────────────────────────────────────────
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(userProvider);
    final chatHistory = ref.watch(chatHistoryProvider);
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return userAsync.when(
      loading: () =>
          const Drawer(child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Drawer(),
      data: (user) {
        final displayName = user?.displayName ??
            (user?.email != null
                ? user!.email!.split('@').first
                : 'Usuário');
        final email = user?.email ?? '';
        final photoUrl = user?.photoURL;
        final initial =
            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

        // Separa histórico em "Hoje" e "Anteriores"
        final now = DateTime.now();
        final today = chatHistory
            .where((s) => s.updatedAt.day == now.day &&
                s.updatedAt.month == now.month &&
                s.updatedAt.year == now.year)
            .toList();
        final older =
            chatHistory.where((s) => !today.contains(s)).toList();

        return Drawer(
          backgroundColor: theme.scaffoldBackgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                // ── Header do usuário ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        backgroundColor: theme.colorScheme.secondary,
                        child: photoUrl == null
                            ? Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              email,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Botão "Novo Chat" ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go('/chat');
                      },
                      icon: Icon(Icons.add,
                          color: theme.colorScheme.secondary, size: 18),
                      label: Text(
                        'Novo chat',
                        style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: theme.colorScheme.secondary
                                .withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),
                Divider(
                    height: 1,
                    color:
                        theme.dividerColor.withValues(alpha: 0.25)),
                const SizedBox(height: 4),

                // ── Navegação principal ───────────────────────────────
                _DrawerNavItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  route: '/chat',
                  currentRoute: currentRoute,
                ),
                _DrawerNavItem(
                  icon: Icons.face_retouching_natural,
                  label: 'Face Scan',
                  route: '/face-scan',
                  currentRoute: currentRoute,
                ),
                _DrawerNavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Histórico de Humor',
                  route: '/mood-history',
                  currentRoute: currentRoute,
                ),

                const SizedBox(height: 4),
                Divider(
                    height: 1,
                    color:
                        theme.dividerColor.withValues(alpha: 0.25)),
                const SizedBox(height: 4),

                // ── Histórico de Chats (scrollável) ──────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    children: [
                      if (today.isNotEmpty) ...[
                        const _SectionLabel('Hoje'),
                        ...today.map((s) => _ChatHistoryItem(
                              session: s,
                              onTap: () {
                                Navigator.of(context).pop();
                                context.go('/chat');
                              },
                              onDelete: () => ref
                                  .read(chatHistoryProvider.notifier)
                                  .removeSession(s.id),
                            )),
                      ],
                      if (older.isNotEmpty) ...[
                        const _SectionLabel('Anteriores'),
                        ...older.map((s) => _ChatHistoryItem(
                              session: s,
                              onTap: () {
                                Navigator.of(context).pop();
                                context.go('/chat');
                              },
                              onDelete: () => ref
                                  .read(chatHistoryProvider.notifier)
                                  .removeSession(s.id),
                            )),
                      ],
                    ],
                  ),
                ),

                Divider(
                    height: 1,
                    color:
                        theme.dividerColor.withValues(alpha: 0.25)),

                // ── Botão Sair ────────────────────────────────────────
                ListTile(
                  leading: Icon(Icons.logout_rounded,
                      color: theme.colorScheme.error),
                  title: Text(
                    'Sair',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await AuthRepository().signOut();
                    if (context.mounted) context.go('/login');
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Item de navegação ─────────────────────────────────────────────────────────
class _DrawerNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;

  const _DrawerNavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = currentRoute == route;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.secondary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon,
            color: isActive
                ? theme.colorScheme.secondary
                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            size: 22),
        title: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? theme.colorScheme.secondary
                : theme.colorScheme.onSurface,
          ),
        ),
        onTap: () {
          Navigator.of(context).pop();
          context.go(route);
        },
      ),
    );
  }
}

// ── Label de seção ("Hoje", "Anteriores") ────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Item individual de histórico de chat ──────────────────────────────────────
class _ChatHistoryItem extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatHistoryItem({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(
        Icons.chat_bubble_outline,
        size: 18,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      title: Text(
        session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.delete_outline,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        onPressed: onDelete,
        tooltip: 'Remover',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
