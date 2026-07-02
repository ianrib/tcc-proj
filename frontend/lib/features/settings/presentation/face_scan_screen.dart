import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'package:tcc_apoio_psicologico/core/providers/user_provider.dart';
import 'package:tcc_apoio_psicologico/core/widgets/app_drawer.dart';
import '../../../core/providers/mood_providers.dart';

class FaceScanScreen extends ConsumerWidget {
  const FaceScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ??
        (user?.email != null ? user!.email!.split('@').first : 'U');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    // Lista de simulações de expressões para o Face Scan
    final List<Map<String, dynamic>> simulatedMoods = [
      {
        "score": 8,
        "emoji": "😃",
        "label": "Feliz",
        "description": "Expressão alegre detectada. Humor geral excelente com sentimentos de entusiasmo.",
        "tags": ["feliz", "alegre", "energia"]
      },
      {
        "score": 7,
        "emoji": "😌",
        "label": "Calmo",
        "description": "Expressão tranquila e serena detectada. Níveis ideais de foco e estabilidade.",
        "tags": ["calmo", "sereno", "focado"]
      },
      {
        "score": 5,
        "emoji": "🥱",
        "label": "Cansado (Intermediário)",
        "description": "Leves sinais de fadiga ou cansaço facial detectados. Recomendável fazer uma pausa.",
        "tags": ["cansado", "neutro", "pausa"]
      },
      {
        "score": 3,
        "emoji": "😢",
        "label": "Triste",
        "description": "Expressão de desânimo ou melancolia identificada. Se precisar, converse com a IA.",
        "tags": ["triste", "desanimado", "melancólico"]
      },
      {
        "score": 2,
        "emoji": "😠",
        "label": "Mal (Estressado)",
        "description": "Expressão facial indicando alta tensão ou estresse. Atenção aos cuidados emocionais.",
        "tags": ["mal", "estressado", "tenso"]
      }
    ];

    Future<void> runFaceScanSimulation() async {
      // 1. Mostrar diálogo de carregamento/análise
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Analisando expressão facial...',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mapeando pontos biométricos...',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );

      // 2. Aguarda 1.5s para simular o processamento
      await Future.delayed(const Duration(milliseconds: 1500));

      // Fecha o diálogo de carregamento
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 3. Sorteia um humor da lista
      final randomIndex = math.Random().nextInt(simulatedMoods.length);
      final mood = simulatedMoods[randomIndex];

      // 4. Salva o registro de humor
      await ref.read(moodEntriesProvider.notifier).addMoodEntry(
        score: mood["score"] as int,
        emoji: mood["emoji"] as String,
        description: mood["description"] as String,
        tags: List<String>.from(mood["tags"]),
      );

      // 5. Feedback visual e navegação
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Face-Scan detectou: ${mood["label"]} ${mood["emoji"]} (Humor ${mood["score"]}/10) e salvou no histórico!',
            ),
            backgroundColor: theme.colorScheme.secondary,
            duration: const Duration(seconds: 4),
          ),
        );
        // Redireciona para a tela de histórico para ver o gráfico e detalhes
        context.go('/mood-history');
      }
    }

    return Scaffold(
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
          'Face-Scan',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => context.go('/mood-history'),
              child: CircleAvatar(
                radius: 20,
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                backgroundColor: theme.colorScheme.secondary,
                child: photoUrl == null
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(
                              MediaQuery.of(context).size.width * 0.5,
                              MediaQuery.of(context).size.width * 0.7,
                            ),
                          ),
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            style: BorderStyle.solid,
                            width: 2.0,
                          ),
                        ),
                        child: ClipOval(
                          clipper: OvalClipper(),
                          child: Image.network(
                            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?fit=crop&w=350&h=450',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: theme.colorScheme.secondary
                                  .withValues(alpha: 0.1),
                              child: Icon(
                                Icons.face,
                                size: 80,
                                color: theme.colorScheme.secondary
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Card de instruções no rodapé
          Card(
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.face,
                        color: theme.colorScheme.primary,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Ajuste seu rosto dentro do círculo',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Por favor, certifique-se que seu rosto está centralizado e olhe para a câmera',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: runFaceScanSimulation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Tirar Foto',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OvalClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}
