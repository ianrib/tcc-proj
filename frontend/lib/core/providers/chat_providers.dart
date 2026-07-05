import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/api_constants.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] ?? '',
      title: json['title'] ?? json['id'] ?? 'Sessão de Chat',
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  final int riskLevel;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.isUser,
    this.riskLevel = 0,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] ?? '',
      isUser: json['sender'] == 'user',
      // Aceita tanto 'riskLevel' (Firestore/camelCase) quanto 'risk_level' (backend/snake_case)
      riskLevel: json['riskLevel'] ?? json['risk_level'] ?? 0,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }
}

// Guarda o ID da sessão de chat ativa. Se for null, o chatScreen iniciará uma nova sessão.
final activeSessionIdProvider = StateProvider<String?>((ref) => null);

class ChatSessionsNotifier extends StateNotifier<AsyncValue<List<ChatSession>>> {
  ChatSessionsNotifier() : super(const AsyncValue.loading()) {
    fetchSessions();
  }

  Future<void> fetchSessions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        state = const AsyncValue.data([]);
        return;
      }
      final response = await http.get(
        Uri.parse("$kBaseUrl/api/v1/chat/sessions"),
        headers: {
          "Authorization": "Bearer ${user.uid}"
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['sessions'] as List)
            .map((s) => ChatSession.fromJson(s))
            .toList();
        state = AsyncValue.data(list);
      } else {
        throw Exception("Erro ao buscar sessões do servidor: ${response.statusCode}");
      }
    } catch (e, stack) {
      // Fallback em caso de erro (ex: offline)
      state = AsyncValue.error(e, stack);
    }
  }

  void addOrUpdateSession(String id, String title, DateTime date) {
    state.whenData((list) {
      final exists = list.any((s) => s.id == id);
      if (exists) {
        state = AsyncValue.data(list.map((s) {
          if (s.id == id) {
            return ChatSession(id: s.id, title: title, updatedAt: date);
          }
          return s;
        }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
      } else {
        state = AsyncValue.data([
          ChatSession(id: id, title: title, updatedAt: date),
          ...list
        ]);
      }
    });
  }

  Future<void> deleteSession(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await http.delete(
          Uri.parse("$kBaseUrl/api/v1/chat/session/$id"),
          headers: {
            "Authorization": "Bearer ${user.uid}"
          },
        );
      }
      state.whenData((list) {
        state = AsyncValue.data(list.where((s) => s.id != id).toList());
      });
    } catch (e) {
      // Fallback local se o servidor estiver inacessível
      state.whenData((list) {
        state = AsyncValue.data(list.where((s) => s.id != id).toList());
      });
    }
  }
}

final chatSessionsProvider = StateNotifierProvider<ChatSessionsNotifier, AsyncValue<List<ChatSession>>>((ref) {
  return ChatSessionsNotifier();
});

class SessionMessagesNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final Ref ref;
  final String? sessionId;
  SessionMessagesNotifier(this.ref, this.sessionId) : super(const AsyncValue.loading()) {
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    if (sessionId == null || sessionId!.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    final sessions = ref.read(chatSessionsProvider).value ?? [];
    final exists = sessions.any((s) => s.id == sessionId);
    if (sessionId!.startsWith('sessao_') && !exists) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        state = const AsyncValue.data([]);
        return;
      }
      final response = await http.get(
        Uri.parse("$kBaseUrl/api/v1/chat/session/$sessionId/messages"),
        headers: {
          "Authorization": "Bearer ${user.uid}"
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['messages'] as List)
            .map((m) => ChatMessage.fromJson(m))
            .toList();
        state = AsyncValue.data(list);
      } else {
        throw Exception("Erro ao buscar mensagens: ${response.statusCode}");
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void addMessage(ChatMessage msg) {
    state.whenData((list) {
      state = AsyncValue.data([...list, msg]);
    });
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

final sessionMessagesProvider = StateNotifierProvider.family<SessionMessagesNotifier, AsyncValue<List<ChatMessage>>, String?>((ref, sessionId) {
  return SessionMessagesNotifier(ref, sessionId);
});
