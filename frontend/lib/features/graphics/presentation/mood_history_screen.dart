import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gaia/core/providers/user_provider.dart';
import 'package:gaia/core/widgets/app_drawer.dart';
import 'package:gaia/core/widgets/user_avatar.dart';
import 'package:gaia/core/utils/string_utils.dart';
import '../../../core/providers/mood_providers.dart';
import '../../../models/mood_entry.dart';

class MoodHistoryScreen extends ConsumerStatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  ConsumerState<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends ConsumerState<MoodHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Filtros selecionados
  String _selectedCategory = 'Todos'; // Todos, Feliz, Triste, Mal
  String _selectedPeriod = '30d'; // 24h, 7d, 30d

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final moodAsync = ref.watch(moodEntriesProvider);
    final rawDisplayName = user?.displayName ??
        (user?.email != null ? user!.email!.split('@').first : 'Usuário');
    final displayName = StringUtils.formatDisplayName(rawDisplayName);



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
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      body: SafeArea(
        child: moodAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Não há histórico ainda, tente iniciar uma conversa.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ),
          ),
          data: (allEntries) {
            final now = DateTime.now();

            final sortedEntries = List<MoodEntry>.from(allEntries)
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
            final latestEntry = sortedEntries.firstOrNull;

            // Determinar status do humor mais recente
            Color statusColor = theme.colorScheme.primary; // default teal
            String statusLabel = "Sem registros";
            if (latestEntry != null) {
              if (latestEntry.score >= 7) {
                statusColor = theme.colorScheme.primary; // Teal
                statusLabel = "Estável / Equilibrado";
              } else if (latestEntry.score >= 4) {
                statusColor = Colors.orange;
                statusLabel = "Neutro / Cansado";
              } else {
                statusColor = Colors.red;
                statusLabel = "Atenção / Crise";
              }
            }

            // Calcular consistência: registros nos últimos 7 dias
            final sevenDaysAgo = now.subtract(const Duration(days: 7));
            final last7DaysEntries = allEntries.where((e) => e.timestamp.isAfter(sevenDaysAgo)).toList();
            // Agrupar dias com registro
            final activeDays = last7DaysEntries.map((e) => e.timestamp.day).toSet().length;

            // ── LÓGICA DE FILTRAGEM DOS DETALHES ──
            final filteredEntries = allEntries.where((e) {
              // 1. Filtro de Texto (Busca)
              final matchesQuery = _searchQuery.isEmpty ||
                  e.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  e.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));

              // 2. Filtro de Categoria
              bool matchesCategory = true;
              if (_selectedCategory == 'Feliz') {
                matchesCategory = e.score >= 7;
              } else if (_selectedCategory == 'Triste') {
                matchesCategory = e.score >= 4 && e.score <= 6;
              } else if (_selectedCategory == 'Mal') {
                matchesCategory = e.score >= 1 && e.score <= 3;
              }

              // 3. Filtro de Período
              bool matchesPeriod = true;
              if (_selectedPeriod == '24h') {
                matchesPeriod = e.timestamp.isAfter(now.subtract(const Duration(hours: 24)));
              } else if (_selectedPeriod == '7d') {
                matchesPeriod = e.timestamp.isAfter(now.subtract(const Duration(days: 7)));
              } else if (_selectedPeriod == '30d') {
                matchesPeriod = e.timestamp.isAfter(now.subtract(const Duration(days: 30)));
              }

              return matchesQuery && matchesCategory && matchesPeriod;
            }).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Histórico de Humor',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Avatar com indicador sutil de status
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.8),
                              width: 3,
                            ),
                          ),
                          child: UserAvatar(
                            radius: 64,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            textColor: theme.colorScheme.primary,
                            fontSize: 40,
                          ),
                        ),
                        // Status badge sutil no canto inferior direito
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nome do Usuário
                  Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Rótulo de status
                  Text(
                    statusLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Linha sutil de consistência dos registros diários nos últimos 7 dias
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 16, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text(
                          'Consistência Semanal: $activeDays de 7 dias ativos',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── SEÇÃO DE FILTROS ──
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Filtros',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Campo de Busca
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.light
                          ? Colors.grey.shade100
                          : theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Buscar por tags ou descrição...',
                              border: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                          ),
                        ),
                        Icon(Icons.search, color: theme.colorScheme.secondary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Chips de Categoria (Feliz, Triste, Mal)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['Todos', 'Feliz', 'Triste', 'Mal'].map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Chips de Período (24h, 7d, 30d)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PeriodChip(
                        label: 'Últimas 24h',
                        value: '24h',
                        selectedValue: _selectedPeriod,
                        onSelected: (val) => setState(() => _selectedPeriod = val),
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        label: 'Últimos 7 dias',
                        value: '7d',
                        selectedValue: _selectedPeriod,
                        onSelected: (val) => setState(() => _selectedPeriod = val),
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        label: 'Últimos 30 dias',
                        value: '30d',
                        selectedValue: _selectedPeriod,
                        onSelected: (val) => setState(() => _selectedPeriod = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── DETALHES / LISTAGEM DE CARDS ──
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Detalhes (${filteredEntries.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (filteredEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.filter_list_off_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum registro encontrado para estes filtros.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        return _MoodDetailCard(entry: entry);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ));
  }
}

// Widget auxiliar para badge de período
class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const _PeriodChip({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = selectedValue == value;

    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      selectedColor: theme.colorScheme.secondary.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.secondary : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => onSelected(value),
    );
  }
}

// Card Individual de Detalhe de Humor
class _MoodDetailCard extends StatelessWidget {
  final MoodEntry entry;

  const _MoodDetailCard({required this.entry});

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Definir cor e título do humor baseado no score
    Color scoreColor;
    String moodLabel;

    if (entry.score >= 7) {
      scoreColor = theme.colorScheme.secondary;
      moodLabel = 'Feliz / Calmo';
    } else if (entry.score >= 4) {
      scoreColor = Colors.orange;
      moodLabel = 'Neutro / Cansado';
    } else {
      scoreColor = Colors.red;
      moodLabel = 'Mal / Estressado';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji / Ícone com a cor associada
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                entry.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(width: 16),

            // Conteúdo principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        moodLabel,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scoreColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry.score}/10',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Data
                  Text(
                    _formatDate(entry.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Descrição
                  Text(
                    entry.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tags
                  if (entry.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: entry.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#$tag',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontSize: 10,
                          ),
                        ),
                      )).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

