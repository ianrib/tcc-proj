import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tcc_apoio_psicologico/core/constants/api_constants.dart';
import 'package:tcc_apoio_psicologico/core/providers/user_provider.dart';
import 'package:tcc_apoio_psicologico/core/widgets/app_drawer.dart';
import '../../../core/providers/chat_providers.dart';

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

  // Sugestões de temas estilo Gemini
  static const _suggestions = [
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
  ];

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
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.phone),
              label: const Text('Ligar CVV (188)'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
            if (risk == 4)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
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
    
    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 600 ? 3 : 2;
    final double childAspectRatio = screenWidth > 600 ? 2.0 : 1.4;

    // Calcula nome de exibição e avatar
    final displayName = user?.displayName ??
        (user?.email != null ? user!.email!.split('@').first : 'Usuário');
    final photoUrl = user?.photoURL;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                context.go('/mood-history');
              },
              child: CircleAvatar(
                radius: 20,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                backgroundColor: theme.colorScheme.secondary,
                child: photoUrl == null
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
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
                              Icons.psychology_outlined,
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
                            const SizedBox(height: 24),
                            
                            // Grid de sugestões estilo Gemini (Responsivo)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: childAspectRatio,
                              ),
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                final suggestion = _suggestions[index];
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  color: theme.cardColor,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _sendMessageText(suggestion['text'] as String),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            suggestion['icon'] as IconData,
                                            color: theme.colorScheme.secondary,
                                            size: 20,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            suggestion['title'] as String,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Expanded(
                                            child: Text(
                                              suggestion['description'] as String,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                fontSize: 10,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
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
                    return Align(
                      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: msg.isUser 
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : theme.cardColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                          ),
                          border: msg.riskLevel >= 3 
                            ? Border.all(color: Colors.red.withValues(alpha: 0.6), width: 1.5)
                            : null,
                        ),
                        child: Text(
                          msg.content,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
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
                      Icon(Icons.mood_outlined, size: 22, color: theme.colorScheme.secondary),
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
                                      color: theme.colorScheme.secondary.withValues(alpha: 0.15),
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

          // Card de Entrada Flutuante (Rodapé)
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fale com Gaia',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Botão de Emoji (Ícone estilizado no lugar de texto emoji)
                      IconButton(
                        onPressed: () => setState(() => _showEmojiBar = !_showEmojiBar),
                        icon: Icon(
                          Icons.sentiment_satisfied_alt_outlined,
                          size: 28,
                          color: _showEmojiBar ? theme.colorScheme.secondary : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.light
                              ? Colors.grey.shade100
                              : theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  maxLines: 5,
                                  minLines: 1,
                                  keyboardType: TextInputType.multiline,
                                  decoration: const InputDecoration(
                                    hintText: 'Escreva uma mensagem...',
                                    border: InputBorder.none,
                                    filled: false,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.photo_camera, color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  context.go('/face-scan');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Botão de Enviar que muda para Parar durante carregamento
                      GestureDetector(
                        onTap: _isLoading ? _stopResponse : _sendMessage,
                        child: CircleAvatar(
                          backgroundColor: _isLoading ? Colors.redAccent : theme.colorScheme.secondary,
                          radius: 24,
                          child: Icon(
                            _isLoading ? Icons.stop_circle_outlined : Icons.send,
                            color: Colors.white,
                            size: _isLoading ? 28 : 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Aviso de responsabilidade de IA
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Este modelo pode cometer erros. Por isso, verifique as informações.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
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
    );
  }
}
