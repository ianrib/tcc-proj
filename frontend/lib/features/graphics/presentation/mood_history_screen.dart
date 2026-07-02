import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'package:tcc_apoio_psicologico/core/providers/user_provider.dart';
import 'package:tcc_apoio_psicologico/core/widgets/app_drawer.dart';
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

    final displayName = user?.displayName ??
        (user?.email != null ? user!.email!.split('@').first : 'Usuário');
    final photoUrl = user?.photoURL;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
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

            // ── LÓGICA DE PORCENTAGENS ──
            // Filtrar registros do período das últimas 24h
            final dayAgo = now.subtract(const Duration(hours: 24));
            var chartEntries = allEntries.where((e) => e.timestamp.isAfter(dayAgo)).toList();
            bool isUsingFallback = false;

            // Se não houver dados nas últimas 24h, cai para os últimos 30 dias
            if (chartEntries.isEmpty) {
              final thirtyDaysAgo = now.subtract(const Duration(days: 30));
              chartEntries = allEntries.where((e) => e.timestamp.isAfter(thirtyDaysAgo)).toList();
              isUsingFallback = true;
            }

            double happyPct = 0;
            double sadPct = 0;
            double badPct = 0;

            if (chartEntries.isNotEmpty) {
              final total = chartEntries.length;
              final happyCount = chartEntries.where((e) => e.score >= 7).length;
              final sadCount = chartEntries.where((e) => e.score >= 4 && e.score <= 6).length;
              final badCount = chartEntries.where((e) => e.score >= 1 && e.score <= 3).length;

              happyPct = (happyCount / total) * 100;
              sadPct = (sadCount / total) * 100;
              badPct = (badCount / total) * 100;
            } else {
              // Valores padrão se não houver dados em lugar nenhum
              happyPct = 0;
              sadPct = 0;
              badPct = 0;
            }

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
                  const SizedBox(height: 8),
                  
                  // Label do período exibido no gráfico
                  Text(
                    isUsingFallback 
                      ? 'Nenhum dado nas últimas 24h. Exibindo últimos 30 dias.' 
                      : 'Análise baseada nas últimas 24 horas',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isUsingFallback 
                          ? Colors.orangeAccent 
                          : theme.colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Segmented Circular Chart surrounding profile image
                  Center(
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Custom Painter com valores dinâmicos
                          CustomPaint(
                            size: const Size(220, 220),
                            painter: SegmentedCirclePainter(
                              happyPct: happyPct,
                              sadPct: sadPct,
                              badPct: badPct,
                              theme: theme,
                            ),
                          ),
                          
                          // Avatar do Usuário
                          CircleAvatar(
                            radius: 80,
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                            backgroundColor: theme.colorScheme.secondary,
                            child: photoUrl == null
                                ? Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          
                          // Badges de porcentagem dinâmicos (só aparecem se > 0%)
                          if (sadPct > 0)
                            Positioned(
                              left: 10,
                              top: 40,
                              child: CircleBadge(
                                percentage: '${sadPct.toStringAsFixed(0)}%', 
                                color: Colors.orange,
                              ),
                            ),
                          if (badPct > 0)
                            Positioned(
                              right: 10,
                              top: 40,
                              child: CircleBadge(
                                percentage: '${badPct.toStringAsFixed(0)}%', 
                                color: Colors.red,
                              ),
                            ),
                          if (happyPct > 0)
                            Positioned(
                              bottom: 10,
                              right: 70,
                              child: CircleBadge(
                                percentage: '${happyPct.toStringAsFixed(0)}%', 
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nome do Usuário
                  Text(
                    displayName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Linha decorativa
                  Container(
                    width: 140,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(2),
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
    );
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

// Circle Badge widget for percentage tags
class CircleBadge extends StatelessWidget {
  final String percentage;
  final Color color;

  const CircleBadge({
    super.key,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        percentage,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Custom Painter para desenhar a borda circular segmentada baseada em dados reais
class SegmentedCirclePainter extends CustomPainter {
  final double happyPct;
  final double sadPct;
  final double badPct;
  final ThemeData theme;

  SegmentedCirclePainter({
    required this.happyPct,
    required this.sadPct,
    required this.badPct,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 12.0;

    final paintHappy = Paint()
      ..color = const Color(0xFF5BC0BE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintSad = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintBad = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Se não houver dados, desenha um arco cinza padrão
    if (happyPct == 0 && sadPct == 0 && badPct == 0) {
      final paintEmpty = Paint()
        ..color = theme.dividerColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, paintEmpty);
      return;
    }

    // Convertendo porcentagens para radianos de forma proporcional
    final happyAngle = (happyPct / 100) * 2 * math.pi;
    final sadAngle = (sadPct / 100) * 2 * math.pi;
    final badAngle = (badPct / 100) * 2 * math.pi;

    var startAngle = -math.pi / 2; // Início no topo

    // Desenhar arco Triste (Orange)
    if (sadAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sadAngle,
        false,
        paintSad,
      );
      startAngle += sadAngle;
    }

    // Desenhar arco Mal (Red)
    if (badAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        badAngle,
        false,
        paintBad,
      );
      startAngle += badAngle;
    }

    // Desenhar arco Feliz (Happy)
    if (happyAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        happyAngle,
        false,
        paintHappy,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
