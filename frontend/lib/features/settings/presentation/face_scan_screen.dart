import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tcc_apoio_psicologico/core/providers/user_provider.dart';
import 'package:tcc_apoio_psicologico/core/widgets/app_drawer.dart';

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

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Builder necessário para que Scaffold.of(context) encontre o Scaffold pai
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
                      // Oval Dotted Frame mimicking camera view
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
                  // Ícone de reconhecimento facial
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
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Foto capturada com sucesso! (Módulo de Visão Computacional Preparado)',
                          ),
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

// Custom Clipper para a moldura oval da câmera
class OvalClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}
