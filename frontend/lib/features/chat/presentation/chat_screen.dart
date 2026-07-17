import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gaia/core/constants/api_constants.dart';
import 'package:gaia/core/providers/user_provider.dart';
import 'package:gaia/core/widgets/app_drawer.dart';
import 'package:gaia/core/widgets/user_avatar.dart';
import 'package:gaia/core/widgets/gaia_avatar.dart';
import 'package:gaia/core/widgets/breathing_exercise_card.dart';
import 'package:gaia/core/utils/string_utils.dart';
import '../../../core/providers/chat_providers.dart';
import '../../../core/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  bool _showEmojiBar = false;
  String? _selectedMoodEmoji;
  http.Client? _activeClient;
  bool _showBreathing = false;
  List<Map<String, dynamic>> _currentSuggestions = [];

  // Emojis de emoção disponíveis na barra flutuante (Níveis 1 a 10)
  static const _moodEmojis = [
    '😊', // 1: Muito Bem
    '🙂', // 2: Bem
    '😐', // 3: Neutro
    '😟', // 4: Preocupado
    '😔', // 5: Triste
    '😰', // 6: Ansioso
    '😫', // 7: Esgotado
    '😠', // 8: Irritado
    '😤', // 9: Muito Irritado
    '😭', // 10: Crise / Angústia
  ];

  // Pool de Sugestões de temas estilo Gemini (serão exibidos 4 aleatórios)
  static const _suggestionsPool = [
    {
      'title': 'Reduzir ansiedade',
      'description': 'Técnicas rápidas para me acalmar.',
      'icon': Icons.spa_outlined,
      'text': 'Quero dicas de técnicas rápidas para reduzir a ansiedade agora.',
    },
    {
      'title': 'Exercício de Respiração',
      'description': 'Iniciar guia de respiração consciente.',
      'icon': Icons.air_outlined,
      'text': 'Gostaria de fazer um exercício de respiração guiado.',
    },
    {
      'title': 'Desabafar sobre o dia',
      'description': 'Hoje foi um dia cansativo/estressante...',
      'icon': Icons.chat_bubble_outline_rounded,
      'text': 'Hoje o dia foi muito cansativo e estressante, preciso desabafar.',
    },
    {
      'title': 'Melhorar o sono',
      'description': 'Dicas de higiene do sono.',
      'icon': Icons.bedtime_outlined,
      'text': 'Quero dicas práticas de higiene do sono para conseguir dormir melhor.',
    },
    {
      'title': 'Pensamentos ruins',
      'description': 'Lidar com autocrítica severa.',
      'icon': Icons.psychology_outlined,
      'text': 'Estou tendo pensamentos muito negativos sobre mim mesmo e queria ajuda para analisá-los.',
    },
    {
      'title': 'Atenção Plena',
      'description': 'Mindfulness simples de 1 min.',
      'icon': Icons.self_improvement_outlined,
      'text': 'Pode me guiar em uma prática rápida de atenção plena (mindfulness)?',
    },
    {
      'title': 'Autocompaixão',
      'description': 'Lidar com erros e falhas.',
      'icon': Icons.favorite_border_rounded,
      'text': 'Preciso de um exercício de autocompaixão para lidar com a autocrítica.',
    },
    {
      'title': 'Organizar rotina',
      'description': 'Atividades e hábitos saudáveis.',
      'icon': Icons.calendar_today_outlined,
      'text': 'Quero ajuda para planejar minhas atividades e organizar uma rotina saudável.',
    },
    {
      'title': 'Lidar com frustração',
      'description': 'Aceitação radical de fatos.',
      'icon': Icons.sentiment_dissatisfied_outlined,
      'text': 'Estou me sentindo muito frustrado com as coisas e queria aprender a lidar melhor com isso.',
    },
    {
      'title': 'Sentimento de solidão',
      'description': 'Conversar e receber acolhimento.',
      'icon': Icons.people_outline_rounded,
      'text': 'Estou me sentindo um pouco solitário hoje e gostaria apenas de conversar.',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().scheduleInactivityNotification();
    });
    // Pick 4 random suggestions from the pool
    final pool = List<Map<String, dynamic>>.from(_suggestionsPool)..shuffle();
    _currentSuggestions = pool.take(4).toList();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await _sendMessageText(text);
  }

  void _stopResponse() {
    if (_isLoading) {
      _activeClient?.close();
      _activeClient = null;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessageText(String text) async {
    // Obtém ou cria o ID da sessão ativa
    var sessionId = ref.read(activeSessionIdProvider);
    final isNewSession = sessionId == null;
    if (isNewSession) {
      // Gera um ID de sessão único
      sessionId = 'sessao_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';
      ref.read(activeSessionIdProvider.notifier).state = sessionId;
    }

    final user = FirebaseAuth.instance.currentUser;
    final String authHeader = user != null ? "Bearer ${user.uid}" : "Bearer mock-token";

    final userMsg = ChatMessage(
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // Adiciona mensagem localmente
    ref.read(sessionMessagesProvider(sessionId).notifier).addMessage(userMsg);

    // Intercepta solicitações de respiração para acionar o card local
    final lowerText = text.toLowerCase();
    if (lowerText.contains('exercício de respiração guiado') || 
        lowerText.contains('exercicio de respiracao guiado') ||
        (lowerText.contains('respiração') && lowerText.contains('guiado'))) {
      setState(() {
        _showBreathing = true;
      });
    }

    // Reseta a notificação de inatividade ao conversar
    NotificationService().scheduleInactivityNotification();
    
    // Atualiza a listagem de sessões no drawer
    final sessionTitle = text.substring(0, math.min(text.length, 35)) + (text.length > 35 ? '...' : '');
    ref.read(chatSessionsProvider.notifier).addOrUpdateSession(sessionId, sessionTitle, DateTime.now());

    _scrollToBottom();

    setState(() {
      _isLoading = true;
    });

    _activeClient = http.Client();

    try {
      final response = await _activeClient!.post(
        Uri.parse("$kBaseUrl/api/v1/chat/message"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": authHeader
        },
        body: jsonEncode({
          "session_id": sessionId,
          "content": text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final assistantText = data["content"] as String;
        final risk = data["risk_level"] as int;

        final assistantMsg = ChatMessage(
          content: assistantText,
          isUser: false,
          riskLevel: risk,
          timestamp: DateTime.now(),
        );

        ref.read(sessionMessagesProvider(sessionId).notifier).addMessage(assistantMsg);

        // Caso haja crise nível 3 ou 4, exibe aviso flutuante / pop-up
        if (risk >= 3) {
          _showCrisisModal(risk, data["emergency_numbers"]);
        }
      } else {
        throw Exception("Erro ao obter resposta do servidor.");
      }
    } catch (e) {
      // Se foi cancelado intencionalmente, _activeClient é nulo
      if (_activeClient == null) return;

      // Fallback offline se o backend FastAPI não estiver acessível
      final fallbackMsg = ChatMessage(
        content: "Olá! Estou operando offline. Lembre-se de ligar o servidor FastAPI para a experiência completa.",
        isUser: false,
        timestamp: DateTime.now(),
      );
      ref.read(sessionMessagesProvider(sessionId).notifier).addMessage(fallbackMsg);
    } finally {
      _activeClient = null;
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _showCrisisModal(int risk, Map<String, dynamic>? emergencyNumbers) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.warning, color: Colors.red, size: 48),
          title: Text(
            risk == 4 ? 'Apoio de Emergência' : 'Deseja conversar com alguém?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            risk == 4 
              ? 'Detectamos sofrimento muito agudo. A IA foi desligada para sua proteção. Por favor, acione a ajuda médica imediata.'
              : 'Percebemos que as coisas estão pesadas para você. Recomendamos ligar para o suporte do CVV 188.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                final Uri telUri = Uri.parse('tel:188');
                try {
                  await launchUrl(telUri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Could not launch dialer: $e');
                }
              },
              icon: const Icon(Icons.phone),
              label: const Text('Ligar CVV (188)'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
            if (risk == 4)
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final Uri telUri = Uri.parse('tel:192');
                  try {
                    await launchUrl(telUri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Could not launch dialer: $e');
                  }
                },
                icon: const Icon(Icons.medical_services),
                label: const Text('Ligar SAMU (192)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeSessionId = ref.watch(activeSessionIdProvider);
    final messagesAsync = ref.watch(sessionMessagesProvider(activeSessionId));
    final user = ref.watch(currentUserProvider);
    final rawDisplayName = user?.displayName ??
        (user?.email != null ? user!.email!.split('@').first : 'Usuário');
    final displayName = StringUtils.formatDisplayName(rawDisplayName);
    



    // Rola para o final se já carregou os dados
    ref.listen(sessionMessagesProvider(activeSessionId), (previous, next) {
      if (next.hasValue) {
        _scrollToBottom();
      }
    });

    // Cancela pensamento anterior ao tocar em Novo Chat (que define o ID como null)
    ref.listen(activeSessionIdProvider, (previous, next) {
      if (next == null) {
        _stopResponse();
      }
    });

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
        actions: [
          IconButton(
            icon: Icon(Icons.air, color: theme.colorScheme.secondary),
            tooltip: 'Exercício de Respiração',
            onPressed: () {
              setState(() {
                _showBreathing = true;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                context.go('/mood-history');
              },
              child: const UserAvatar(
                radius: 20,
                fontSize: 16,
              ),
            ),
          )
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (_showEmojiBar) {
            setState(() {
              _showEmojiBar = false;
            });
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            if (_showBreathing)
              BreathingExerciseCard(
                onClose: () {
                  setState(() {
                    _showBreathing = false;
                  });
                },
              ),
            Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Erro ao carregar mensagens. Por favor, verifique a conexão com o servidor.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sentiment_satisfied_alt_rounded,
                              size: 72,
                              color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Olá, $displayName',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Como você está se sentindo hoje? Escolha uma sugestão ou fale comigo.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final showTyping = _isLoading;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (showTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return const TypingIndicator();
                    }
                    final msg = messages[index];
                    final timeStr = "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}";
                    final double maxBubbleWidth = MediaQuery.of(context).size.width * 0.72;
                    
                    final avatar = msg.isUser
                        ? const UserAvatar(
                            radius: 16,
                            fontSize: 12,
                          )
                        : const GaiaAvatar(radius: 16);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!msg.isUser) ...[
                            avatar,
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: msg.isUser 
                                  ? theme.colorScheme.primary
                                  : theme.cardColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
                                  bottomRight: Radius.circular(msg.isUser ? 4 : 20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: msg.riskLevel >= 3 
                                  ? Border.all(color: Colors.red.withValues(alpha: 0.6), width: 1.5)
                                  : Border.all(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                                      width: 1,
                                    ),
                              ),
                              child: Column(
                                crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    msg.content
                                        .replaceAll('action:create_reminder', '')
                                        .replaceAll('action:breathing_exercise', '')
                                        .trim(),
                                    style: TextStyle(
                                      color: msg.isUser 
                                        ? Colors.white 
                                        : theme.colorScheme.onSurface,
                                      fontSize: 15,
                                      height: 1.35,
                                    ),
                                  ),
                                  if (!msg.isUser && msg.content.contains('action:create_reminder')) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          context.go('/reminders?openAdd=true');
                                        },
                                        icon: const Icon(Icons.alarm_add_rounded, size: 16),
                                        label: const Text('⏰ Criar Lembrete'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.secondary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (!msg.isUser && msg.content.contains('action:breathing_exercise')) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _showBreathing = true;
                                          });
                                        },
                                        icon: const Icon(Icons.air_rounded, size: 16),
                                        label: const Text('🧘 Iniciar Exercício'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  if (msg.isUser)
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                    )
                                  else
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        timeStr,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (msg.isUser) ...[
                            const SizedBox(width: 8),
                            avatar,
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // ── Barra flutuante de emojis (responsiva, com fade-out nas bordas e interativa) ───────────
          if (_showEmojiBar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                color: theme.cardColor,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.mood_outlined, size: 22, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                              stops: [0.0, 0.05, 0.95, 1.0],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: _moodEmojis.map((emoji) {
                                final isSelected = emoji == _selectedMoodEmoji;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedMoodEmoji = emoji;
                                      _showEmojiBar = false;
                                    });
                                    _sendMessageText(emoji); // Envia para o chat imediatamente
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    padding: const EdgeInsets.all(6),
                                    decoration: isSelected ? BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ) : null,
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Sugestões horizontais estilo Gemini (só aparecem se a conversa estiver vazia)
          messagesAsync.maybeWhen(
            data: (messages) {
              if (messages.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4, top: 8),
                  child: SizedBox(
                    height: 44,
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                          stops: [0.0, 0.04, 0.96, 1.0],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: _currentSuggestions.map((suggestion) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: OutlinedButton.icon(
                                onPressed: () => _sendMessageText(suggestion['text'] as String),
                                icon: Icon(
                                  suggestion['icon'] as IconData,
                                  size: 16,
                                  color: theme.colorScheme.secondary,
                                ),
                                label: Text(
                                  suggestion['title'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: theme.cardColor,
                                  side: BorderSide(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // Caixa de Entrada Flutuante (Estilo ChatGPT/Gemini)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Botão de Emoji sutil
                IconButton(
                  onPressed: () => setState(() => _showEmojiBar = !_showEmojiBar),
                  icon: Icon(
                    Icons.sentiment_satisfied_alt_outlined,
                    size: 24,
                    color: _showEmojiBar ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // Botão de Câmera/Anexo
                IconButton(
                  icon: Icon(
                    Icons.photo_camera_outlined,
                    size: 24,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    context.go('/face-scan');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // Campo de Texto
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: TextField(
                      controller: _textController,
                      maxLines: 5,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'Pergunte à Gaia...',
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Botão de Enviar que muda para Parar durante carregamento
                GestureDetector(
                  onTap: _isLoading ? _stopResponse : _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isLoading ? Colors.redAccent : theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isLoading ? Icons.stop_circle_outlined : Icons.arrow_upward,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Aviso de responsabilidade de IA
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16, top: 4),
              child: Text(
                'Este modelo pode cometer erros. Por isso, verifique as informações.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}

// ── Animação de digitação do assistente (Bouncing Dots) ──────────────────────────
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animations = List.generate(3, (index) {
      final delay = index * 0.2;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(delay, delay + 0.6, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const GaiaAvatar(radius: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _animations[index],
                    builder: (context, child) {
                      final val = _animations[index].value;
                      return Transform.translate(
                        offset: Offset(0, -6 * math.sin(val * math.pi)),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.3 + (0.7 * val)),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
