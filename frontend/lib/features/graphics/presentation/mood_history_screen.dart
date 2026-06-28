import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;

class MoodHistoryScreen extends StatelessWidget {
  const MoodHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.grid_view, color: theme.colorScheme.secondary),
          onPressed: () {
            context.go('/chat');
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Historico de Humor',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 32),

              // Segmented Circular Chart surrounding profile image
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Custom Painter drawing segmented colored ring
                      CustomPaint(
                        size: const Size(220, 220),
                        painter: SegmentedCirclePainter(),
                      ),
                      // User photo in the center
                      const CircleAvatar(
                        backgroundImage: NetworkImage(
                          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?fit=crop&w=150&h=150',
                        ),
                        radius: 80,
                      ),
                      
                      // Percentage labels
                      // Orange 35% label (Top Left)
                      const Positioned(
                        left: 10,
                        top: 40,
                        child: CircleBadge(percentage: '35%', color: Colors.orange),
                      ),
                      // Red 20% label (Top Right)
                      const Positioned(
                        right: 10,
                        top: 40,
                        child: CircleBadge(percentage: '20%', color: Colors.red),
                      ),
                      // Teal 45% label (Bottom Right)
                      Positioned(
                        bottom: 10,
                        right: 70,
                        child: CircleBadge(percentage: '45%', color: theme.colorScheme.secondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // User Name
              Text(
                'Lucca R. Garcia',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              // Thick decorative horizontal line
              Container(
                width: 140,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 40),

              // Details Header
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Detalhes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Search Bar & Filter Button row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.light
                  ? Colors.grey.shade100
                  : theme.cardColor,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: '',
                                border: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          Icon(Icons.search, color: theme.colorScheme.secondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.filter_alt_outlined, color: theme.colorScheme.secondary, size: 28),
                ],
              ),
              const SizedBox(height: 24),

              // Detailed Cards
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_emotions, color: theme.colorScheme.secondary, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dia equilibrado',
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Humor geral avaliado em 8/10. Sentimentos de calma e foco.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Oscilação leve',
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Humor geral avaliado em 5/10. Relato de cansaço extremo.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

// Custom Painter to draw Segmented Circle Ring
class SegmentedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 12.0;

    final paintTeal = Paint()
      ..color = const Color(0xFF5BC0BE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintOrange = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintRed = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Segmentos:
    // 35% Laranja = 126 graus
    // 20% Vermelho = 72 graus
    // 45% Teal = 162 graus
    
    // Convertendo para radianos:
    const orangeAngle = 35 * 2 * math.pi / 100;
    const redAngle = 20 * 2 * math.pi / 100;
    const tealAngle = 45 * 2 * math.pi / 100;

    // Desenhando os arcos
    // Arco Laranja (Início no topo -pi/2)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      orangeAngle,
      false,
      paintOrange,
    );

    // Arco Vermelho
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + orangeAngle,
      redAngle,
      false,
      paintRed,
    );

    // Arco Teal
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + orangeAngle + redAngle,
      tealAngle,
      false,
      paintTeal,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
