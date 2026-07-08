import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import 'package:tcc_apoio_psicologico/core/providers/user_provider.dart';
import 'package:tcc_apoio_psicologico/core/widgets/app_drawer.dart';
import 'package:tcc_apoio_psicologico/core/utils/string_utils.dart';
import '../../../core/providers/mood_providers.dart';
import '../../../core/constants/api_constants.dart';

class FaceScanScreen extends ConsumerStatefulWidget {
  const FaceScanScreen({super.key});

  @override
  ConsumerState<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends ConsumerState<FaceScanScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  
  // Separação de estados de erro
  String? _cameraError;
  String? _apiError;

  // Resultado do escaneamento
  String? _detectedEmotion;
  double? _confidence;
  String? _providerUsed;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = "Nenhuma câmera física detectada no dispositivo móvel.";
        });
        return;
      }

      // Procura pela câmera frontal
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _cameraError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = "Erro ao acessar permissões ou hardware da câmera: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _apiError = null;
      _detectedEmotion = null;
      _confidence = null;
    });

    try {
      // 1. Captura o frame/foto na hora
      final XFile rawPhoto = await _cameraController!.takePicture();

      // CONFORMIDADE LGPD (Privacy by Design):
      // Lemos os bytes diretamente do arquivo de cache gerado temporariamente pela câmera.
      final bytes = await rawPhoto.readAsBytes();

      // Imediatamente apagamos o arquivo físico gerado temporariamente no armazenamento do celular,
      // garantindo que os dados biométricos de imagem não fiquem persistidos no disco do dispositivo.
      try {
        final tempFile = File(rawPhoto.path);
        if (await tempFile.exists()) {
          await tempFile.delete();
          debugPrint("LGPD Compliance: Arquivo de imagem em cache do celular deletado imediatamente.");
        }
      } catch (e) {
        debugPrint("Aviso ao deletar cache da foto no Flutter: $e");
      }

      // 2. Prepara e envia os bytes via Multipart para o endpoint FastAPI
      final currentUser = FirebaseAuth.instance.currentUser;
      final token = currentUser?.uid ?? "user_teste_local";

      final url = Uri.parse("$kBaseUrl/api/v1/visao/detectar-emocao");
      final request = http.MultipartRequest("POST", url);

      request.headers["Authorization"] = "Bearer $token";
      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          bytes,
          filename: "face_scan_frame.jpg",
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        
        setState(() {
          _detectedEmotion = result["emocao_dominante"];
          _confidence = result["confianca"];
          _providerUsed = result["provedor"];
          _isProcessing = false;
        });

        // 3. Mapeia e persiste o sentimento detectado na base de dados de humor do usuário
        if (_detectedEmotion != null && _confidence != null) {
          await _mapAndSaveMoodEntry(_detectedEmotion!, _confidence!);
        }

        // Redireciona para a tela de histórico/dashboard para ver o humor gravado
        if (mounted) {
          context.go('/mood-history');
        }
      } else {
        throw Exception("Backend retornou erro HTTP ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _apiError = "Falha no reconhecimento da expressão: $e";
        });
      }
    }
  }

  Future<void> _mapAndSaveMoodEntry(String emotion, double confidence) async {
    int score = 5;
    String emoji = "😐";
    String label = emotion;
    String description = "Expressão facial capturada pela câmera.";
    List<String> tags = ["facial-scan", emotion.toLowerCase()];

    switch (emotion) {
      case 'Felicidade':
        score = 8;
        emoji = "😃";
        label = "Feliz";
        description = "A análise facial identificou expressão de Felicidade (${(confidence * 100).toStringAsFixed(0)}% de confiança).";
        tags.addAll(["feliz", "alegre", "energia"]);
        break;
      case 'Neutro':
        score = 7;
        emoji = "😌";
        label = "Calmo / Neutro";
        description = "Expressão tranquila ou serena detectada pelo Face-Scan (${(confidence * 100).toStringAsFixed(0)}% de confiança).";
        tags.addAll(["calmo", "sereno"]);
        break;
      case 'Tristeza':
        score = 3;
        emoji = "😢";
        label = "Triste";
        description = "Sinais faciais de Tristeza detectados (${(confidence * 100).toStringAsFixed(0)}% de confiança). Lembre-se de conversar sobre isso no chat.";
        tags.addAll(["triste", "desanimado"]);
        break;
      case 'Raiva':
        score = 2;
        emoji = "😠";
        label = "Raiva / Estressado";
        description = "Expressão indicando alto nível de tensão ou irritabilidade (${(confidence * 100).toStringAsFixed(0)}% de confiança).";
        tags.addAll(["estressado", "tenso"]);
        break;
      case 'Medo':
        score = 3;
        emoji = "😨";
        label = "Apreensivo";
        description = "Face-Scan indicou sinais de receio ou apreensão (${(confidence * 100).toStringAsFixed(0)}% de confiança).";
        tags.addAll(["medo", "ansioso"]);
        break;
      case 'Surpresa':
        score = 7;
        emoji = "😮";
        label = "Surpreso";
        description = "Expressão de espanto ou surpresa identificada (${(confidence * 100).toStringAsFixed(0)}% de confiança).";
        tags.addAll(["surpresa", "energia"]);
        break;
      default:
        score = 5;
        emoji = "😐";
        description = "Expressão facial analisada: $emotion (${(confidence * 100).toStringAsFixed(0)}% de confiança).";
        tags.add("neutro");
    }

    try {
      // Salva no Firestore histórico de humor do usuário
      await ref.read(moodEntriesProvider.notifier).addMoodEntry(
        score: score,
        emoji: emoji,
        description: description,
        tags: tags,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Face-Scan detectou: $label $emoji e salvou no histórico!',
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint("Erro ao salvar entrada de humor obtida por face: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    final photoUrl = user?.photoURL;
    final rawDisplayName = user?.displayName ??
        (user?.email != null ? user!.email!.split('@').first : 'U');
    final displayName = StringUtils.formatDisplayName(rawDisplayName);
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
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Face-Scan Realtime',
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
          // Área de visualização (Câmera ou Erros)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AspectRatio(
                  aspectRatio: 0.8,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Contêiner Oval da Câmera
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: const BorderRadius.all(
                            Radius.elliptical(180, 240),
                          ),
                          border: Border.all(
                            color: _isProcessing 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.secondary,
                            style: BorderStyle.solid,
                            width: 3.0,
                          ),
                        ),
                        child: ClipPath(
                          clipper: OvalClipper(),
                          child: _isCameraInitialized && _cameraController != null
                              ? CameraPreview(_cameraController!)
                              : _cameraError != null
                                  ? Container(
                                      color: Colors.red.withOpacity(0.1),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                          const SizedBox(height: 12),
                                          Text(
                                            _cameraError!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.red, fontSize: 13),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            onPressed: _initializeCamera,
                                            icon: const Icon(Icons.refresh, size: 16),
                                            label: const Text("Tentar Câmera"),
                                          )
                                        ],
                                      ),
                                    )
                                  : const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text("Inicializando Câmera frontal..."),
                                        ],
                                      ),
                                    ),
                        ),
                      ),
                      
                      // Animação de escaneamento a laser
                      if (_isProcessing)
                        Positioned.fill(
                          child: ClipPath(
                            clipper: OvalClipper(),
                            child: const FaceScanLineAnimator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Card informativo e de interação
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
                        color: _isProcessing
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : _apiError != null
                                ? theme.colorScheme.error.withOpacity(0.1)
                                : theme.colorScheme.secondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isProcessing 
                            ? Icons.biotech 
                            : _apiError != null
                                ? Icons.warning_amber_rounded
                                : Icons.face,
                        color: _isProcessing
                            ? theme.colorScheme.primary 
                            : _apiError != null
                                ? theme.colorScheme.error
                                : theme.colorScheme.secondary,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Títulos dependendo do estado
                  if (_isProcessing) ...[
                    Text(
                      'Análise Biométrica em Andamento',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Os bytes faciais estão sendo processados estritamente em memória RAM de forma volátil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ] else if (_apiError != null) ...[
                    Text(
                      'Erro na Detecção',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _apiError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.error.withOpacity(0.9)),
                    ),
                  ] else if (_detectedEmotion != null) ...[
                    Text(
                      'Emoção Detectada: $_detectedEmotion',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Taxa de Confiança: ${(_confidence! * 100).toStringAsFixed(0)}%\n(Análise efetuada por $_providerUsed)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ] else ...[
                    Text(
                      'Ajuste seu rosto dentro da máscara oval',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Segurança e LGPD: Nenhuma cópia de imagem ou dados biométricos será persistida no disco ou banco de dados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Botão de ação
                  ElevatedButton(
                    onPressed: _isCameraInitialized && !_isProcessing ? _captureAndAnalyze : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _detectedEmotion != null || _apiError != null ? 'Escanear Novamente' : 'Analisar Expressão',
                            style: const TextStyle(
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

class OvalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Widget Animado para laser de Scanner
class FaceScanLineAnimator extends StatefulWidget {
  const FaceScanLineAnimator({super.key});

  @override
  State<FaceScanLineAnimator> createState() => _FaceScanLineAnimatorState();
}

class _FaceScanLineAnimatorState extends State<FaceScanLineAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScanLinePainter(_animController.value, theme.colorScheme.primary),
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScanLinePainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.0), color, color.withOpacity(0.0)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final y = size.height * progress;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    final glowPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    
    final glowRect = Rect.fromLTRB(0, y - 12, size.width, y + 12);
    canvas.drawRect(glowRect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
