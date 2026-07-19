import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/api_constants.dart';
import '../services/local_cache_service.dart';

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ChatSuggestion {
  final String title;
  final String action;
  final String description;

  const ChatSuggestion({
    required this.title,
    required this.action,
    required this.description,
  });

  factory ChatSuggestion.fromJson(Map<String, dynamic> json) {
    return ChatSuggestion(
      title: json['title'] ?? '',
      action: json['action'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'action': action,
      'description': description,
    };
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  final int riskLevel;
  final DateTime timestamp;
  final List<ChatSuggestion>? suggestions;

  ChatMessage({
    required this.content,
    required this.isUser,
    this.riskLevel = 0,
    required this.timestamp,
    this.suggestions,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<ChatSuggestion>? suggestionsList;
    if (json['suggestions'] != null) {
      suggestionsList = (json['suggestions'] as List)
          .map((s) => ChatSuggestion.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return ChatMessage(
      content: json['content'] ?? '',
      isUser: json['sender'] == 'user',
      riskLevel: json['riskLevel'] ?? json['risk_level'] ?? 0,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      suggestions: suggestionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'sender': isUser ? 'user' : 'assistant',
      'risk_level': riskLevel,
      'timestamp': timestamp.toIso8601String(),
      if (suggestions != null)
        'suggestions': suggestions!.map((s) => s.toJson()).toList(),
    };
  }
}

// Guarda o ID da sessão de chat ativa. Se for null, o chatScreen iniciará uma nova sessão.
final activeSessionIdProvider = StateProvider<String?>((ref) => null);

class ChatSessionsNotifier extends StateNotifier<AsyncValue<List<ChatSession>>> {
  ChatSessionsNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final cached = await LocalCacheService().loadChatSessions(user.uid);
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      }
    }
    await fetchSessions();
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
        await LocalCacheService().saveChatSessions(user.uid, list);
      } else {
        throw Exception("Erro ao buscar sessões do servidor: ${response.statusCode}");
      }
    } catch (e, stack) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  void addOrUpdateSession(String id, String title, DateTime date) {
    state.whenData((list) {
      List<ChatSession> newList;
      final exists = list.any((s) => s.id == id);
      if (exists) {
        newList = list.map((s) {
          if (s.id == id) {
            return ChatSession(id: s.id, title: title, updatedAt: date);
          }
          return s;
        }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      } else {
        newList = [
          ChatSession(id: id, title: title, updatedAt: date),
          ...list
        ];
      }
      state = AsyncValue.data(newList);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        LocalCacheService().saveChatSessions(user.uid, newList);
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
        final newList = list.where((s) => s.id != id).toList();
        state = AsyncValue.data(newList);
        if (user != null) {
          LocalCacheService().saveChatSessions(user.uid, newList);
        }
      });
    } catch (e) {
      state.whenData((list) {
        final newList = list.where((s) => s.id != id).toList();
        state = AsyncValue.data(newList);
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          LocalCacheService().saveChatSessions(user.uid, newList);
        }
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

  SessionMessagesNotifier(this.ref, this.sessionId)
      : super(
          _isNewOrEmptySession(ref, sessionId)
              ? const AsyncValue.data([])
              : const AsyncValue.loading(),
        ) {
    _init();
  }

  static bool _isNewOrEmptySession(Ref ref, String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return true;
    if (sessionId.startsWith('sessao_')) {
      final sessions = ref.read(chatSessionsProvider).value ?? [];
      final exists = sessions.any((s) => s.id == sessionId);
      return !exists;
    }
    return false;
  }

  Future<void> _init() async {
    if (_isNewOrEmptySession(ref, sessionId)) {
      state = const AsyncValue.data([]);
      return;
    }
    if (sessionId != null && sessionId!.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final cached = await LocalCacheService().loadChatMessages(user.uid, sessionId!);
        if (cached.isNotEmpty) {
          state = AsyncValue.data(cached);
        }
      }
    }
    await fetchMessages();
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
        await LocalCacheService().saveChatMessages(user.uid, sessionId!, list);
      } else {
        throw Exception("Erro ao buscar mensagens: ${response.statusCode}");
      }
    } catch (e, stack) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  void addMessage(ChatMessage msg) {
    final currentList = state.value ?? [];
    final newList = [...currentList, msg];
    state = AsyncValue.data(newList);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && sessionId != null) {
      LocalCacheService().saveChatMessages(user.uid, sessionId!, newList);
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

final sessionMessagesProvider = StateNotifierProvider.family<SessionMessagesNotifier, AsyncValue<List<ChatMessage>>, String?>((ref, sessionId) {
  return SessionMessagesNotifier(ref, sessionId);
});
