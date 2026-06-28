import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Modelo de Mensagem local
class ChatMessage {
  final String content;
  final bool isUser;
  final int riskLevel;

  ChatMessage({
    required this.content,
    required this.isUser,
    this.riskLevel = 0,
  });
}

// Provedor de estado simples para as mensagens do chat
class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier() : super([]);

  void addMessage(ChatMessage msg) {
    state = [...state, msg];
  }

  void clear() {
    state = [];
  }
}

final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier();
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  final String _sessionId = "sessao_tcc_1";
  int _currentRiskLevel = 0;

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
    final userMsg = ChatMessage(content: text, isUser: true);
    ref.read(chatMessagesProvider.notifier).addMessage(userMsg);
    _scrollToBottom();

    setState(() {
      _isLoading = true;
    });

    try {
      // Faz chamada HTTP POST para o nosso servidor FastAPI
      final response = await http.post(
        Uri.parse("http://127.0.0.1:8000/api/v1/chat/message"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer mock-token"
        },
        body: jsonEncode({
          "session_id": _sessionId,
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
        );

        ref.read(chatMessagesProvider.notifier).addMessage(assistantMsg);
        
        setState(() {
          _currentRiskLevel = risk;
        });

        // Caso haja crise nível 3 ou 4, exibe aviso flutuante / pop-up
        if (risk >= 3) {
          _showCrisisModal(risk, data["emergency_numbers"]);
        }
      } else {
        throw Exception("Erro ao obter resposta do servidor.");
      }
    } catch (e) {
      // Fallback offline se o backend FastAPI não estiver acessível
      final fallbackMsg = ChatMessage(
        content: "Olá! Estou operando offline. Lembre-se de ligar o servidor FastAPI para a experiência completa.",
        isUser: false,
      );
      ref.read(chatMessagesProvider.notifier).addMessage(fallbackMsg);
    } finally {
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
                // Ação de ligação simulada
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
    final messages = ref.watch(chatMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.grid_view, color: theme.colorScheme.secondary),
          onPressed: () {
            // Volta para a tela de login ou abre configurações
            context.go('/login');
          },
        ),
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
          // Indicador de carregamento
          if (_isLoading) const LinearProgressIndicator(),
          // Exibe nível de risco
          if (_currentRiskLevel > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Nível de risco: $_currentRiskLevel',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.redAccent),
              ),
            ),
          // Área Central
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'Olá, Lucca',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
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
                    'Fale com Lucci',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Botão de Anexo (+)
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {},
                      ),
                      
                      // Input de texto principal
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
                                  decoration: const InputDecoration(
                                    hintText: 'Escreva uma mensagem...',
                                    border: InputBorder.none,
                                    filled: false,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              // Botão Câmera Azul (Tira foto)
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
                      // Botão Send Teal
                      GestureDetector(
                        onTap: _sendMessage,
                        child: CircleAvatar(
                          backgroundColor: theme.colorScheme.secondary,
                          radius: 24,
                          child: const Icon(Icons.send, color: Colors.white),
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
    );
  }
}
