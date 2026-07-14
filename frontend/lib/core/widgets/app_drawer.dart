import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gaia/core/providers/user_provider.dart';
import 'package:gaia/core/repositories/auth_repository.dart';
import 'package:gaia/core/utils/string_utils.dart';
import '../providers/chat_providers.dart';

// ── AppDrawer funcional com integração ao backend ──────────────────────────────
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(userProvider);
    final sessionsAsync = ref.watch(chatSessionsProvider);
    final activeSessionId = ref.watch(activeSessionIdProvider);
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return userAsync.when(
      loading: () =>
          const Drawer(child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Drawer(),
      data: (user) {
        final rawDisplayName = user?.displayName ??
            (user?.email != null
                ? user!.email!.split('@').first
                : 'Usuário');
        final displayName = StringUtils.formatDisplayName(rawDisplayName);
        final email = user?.email ?? '';
        final photoUrl = user?.photoURL;
        final initial =
            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

        return Drawer(
          backgroundColor: theme.scaffoldBackgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                // ── Header do usuário (clícavel → navega para perfil) ───────────────
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go('/profile');
                  },
                  child: Container(
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
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
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
                        // Limpa o ID da sessão ativa para iniciar uma nova conversa
                        ref.read(activeSessionIdProvider.notifier).state = null;
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
                _DrawerNavItem(
                  icon: Icons.access_time_rounded,
                  label: 'Lembretes',
                  route: '/reminders',
                  currentRoute: currentRoute,
                ),
                _DrawerNavItem(
                  icon: Icons.settings_outlined,
                  label: 'Configurações',
                  route: '/settings',
                  currentRoute: currentRoute,
                ),


                const SizedBox(height: 4),
                Divider(
                    height: 1,
                    color:
                        theme.dividerColor.withValues(alpha: 0.25)),
                const SizedBox(height: 4),

                // ── Histórico de Chats Dinâmico ──────────────────────
                Expanded(
                  child: sessionsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Não há histórico ainda, tente iniciar uma conversa.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    data: (chatHistory) {
                      if (chatHistory.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 36,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Nenhuma conversa ainda.\nToque em "Novo chat" para começar!',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Separa histórico em "Hoje" e "Anteriores"
                      final now = DateTime.now();
                      final today = chatHistory
                          .where((s) => s.updatedAt.day == now.day &&
                              s.updatedAt.month == now.month &&
                              s.updatedAt.year == now.year)
                          .toList();
                      final older =
                          chatHistory.where((s) => !today.contains(s)).toList();

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        children: [
                          if (today.isNotEmpty) ...[
                            const _SectionLabel('Hoje'),
                            ...today.map((s) => _ChatHistoryItem(
                                  session: s,
                                  isActive: activeSessionId == s.id,
                                  onTap: () {
                                    ref.read(activeSessionIdProvider.notifier).state = s.id;
                                    Navigator.of(context).pop();
                                    context.go('/chat');
                                  },
                                  onDelete: () {
                                    if (activeSessionId == s.id) {
                                      ref.read(activeSessionIdProvider.notifier).state = null;
                                    }
                                    ref.read(chatSessionsProvider.notifier).deleteSession(s.id);
                                  },
                                )),
                          ],
                          if (older.isNotEmpty) ...[
                            const _SectionLabel('Anteriores'),
                            ...older.map((s) => _ChatHistoryItem(
                                  session: s,
                                  isActive: activeSessionId == s.id,
                                  onTap: () {
                                    ref.read(activeSessionIdProvider.notifier).state = s.id;
                                    Navigator.of(context).pop();
                                    context.go('/chat');
                                  },
                                  onDelete: () {
                                    if (activeSessionId == s.id) {
                                      ref.read(activeSessionIdProvider.notifier).state = null;
                                    }
                                    ref.read(chatSessionsProvider.notifier).deleteSession(s.id);
                                  },
                                )),
                          ],
                        ],
                      );
                    },
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
                    // Limpar ID de sessão ativa ao deslogar
                    ref.read(activeSessionIdProvider.notifier).state = null;
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
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatHistoryItem({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        leading: Icon(
          Icons.chat_bubble_outline,
          size: 18,
          color: isActive 
              ? theme.colorScheme.primary 
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        title: Text(
          session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive 
                ? theme.colorScheme.primary 
                : theme.colorScheme.onSurface.withValues(alpha: 0.85),
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
      ),
    );
  }
}
