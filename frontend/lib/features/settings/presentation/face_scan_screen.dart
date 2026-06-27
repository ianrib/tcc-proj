import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FaceScanScreen extends StatelessWidget {
  const FaceScanScreen({super.key});

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
              onTap: () {
                context.go('/mood-history');
              },
              child: const CircleAvatar(
                backgroundImage: NetworkImage(
                  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?fit=crop&w=150&h=150',
                ),
                radius: 20,
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
                      // Oval Dotted Frame mimicking camera view
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(MediaQuery.of(context).size.width * 0.5, MediaQuery.of(context).size.width * 0.7),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Card de instruções no rodapé (cantos superiores arredondados)
          Card(
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Blue camera facial recognition icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
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
                  
                  // Título instrução
                  Text(
                    'Ajuste seu rosto dentro do círculo',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtítulo instrução
                  Text(
                    'por favor, certifique-se que seu rosto está centralizado e olhe para a câmera',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Botão teal de ação
                  ElevatedButton(
                    onPressed: () {
                      // Exibe feedback visual simples de foto tirada
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Foto capturada com sucesso! (Módulo de Visão Computacional Preparado)'),
                        ),
                      );
                      context.go('/chat');
                    },
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

// Custom Clipper to shape the camera preview photo inside the oval frame
class OvalClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return false;
  }
}
