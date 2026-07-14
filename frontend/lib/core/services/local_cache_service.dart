import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaia/core/providers/chat_providers.dart';
import 'package:gaia/models/mood_entry.dart';

class LocalCacheService {
  static final LocalCacheService _instance = LocalCacheService._internal();
  factory LocalCacheService() => _instance;
  LocalCacheService._internal();

  // Chat Sessions
  Future<void> saveChatSessions(String userId, List<ChatSession> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = sessions.map((s) => s.toJson()).toList();
      await prefs.setString('chat_sessions_$userId', jsonEncode(data));
    } catch (e) {
      // Ignora erro de persistência
    }
  }

  Future<List<ChatSession>> loadChatSessions(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('chat_sessions_$userId');
      if (jsonStr == null) return [];
      final List data = jsonDecode(jsonStr);
      return data.map((s) => ChatSession.fromJson(s)).toList();
    } catch (e) {
      return [];
    }
  }

  // Chat Messages
  Future<void> saveChatMessages(String userId, String sessionId, List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = messages.map((m) => m.toJson()).toList();
      await prefs.setString('chat_messages_${userId}_$sessionId', jsonEncode(data));
    } catch (e) {
      // Ignora erro de persistência
    }
  }

  Future<List<ChatMessage>> loadChatMessages(String userId, String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('chat_messages_${userId}_$sessionId');
      if (jsonStr == null) return [];
      final List data = jsonDecode(jsonStr);
      return data.map((m) => ChatMessage.fromJson(m)).toList();
    } catch (e) {
      return [];
    }
  }

  // Mood Entries
  Future<void> saveMoodEntries(String userId, List<MoodEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = entries.map((e) => e.toJson()).toList();
      await prefs.setString('mood_entries_$userId', jsonEncode(data));
    } catch (e) {
      // Ignora erro de persistência
    }
  }

  Future<List<MoodEntry>> loadMoodEntries(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('mood_entries_$userId');
      if (jsonStr == null) return [];
      final List data = jsonDecode(jsonStr);
      return data.map((e) => MoodEntry.fromJson(e, id: e['id'])).toList();
    } catch (e) {
      return [];
    }
  }
}
