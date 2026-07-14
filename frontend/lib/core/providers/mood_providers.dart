import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/mood_entry.dart';
import '../constants/api_constants.dart';
import '../services/local_cache_service.dart';

class MoodEntriesNotifier extends StateNotifier<AsyncValue<List<MoodEntry>>> {
  MoodEntriesNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final cached = await LocalCacheService().loadMoodEntries(user.uid);
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      }
    }
    await fetchMoodEntries();
  }

  Future<void> fetchMoodEntries() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        state = const AsyncValue.data([]);
        return;
      }
      final response = await http.get(
        Uri.parse("$kBaseUrl/api/v1/mood/"),
        headers: {
          "Authorization": "Bearer ${user.uid}"
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['entries'] as List)
            .map((e) => MoodEntry.fromJson(e, id: e['id']))
            .toList();
        state = AsyncValue.data(list);
        await LocalCacheService().saveMoodEntries(user.uid, list);
      } else {
        throw Exception("Erro ao buscar histórico de humor: ${response.statusCode}");
      }
    } catch (e, stack) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> addMoodEntry({
    required int score,
    required String emoji,
    required String description,
    required List<String> tags,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final response = await http.post(
        Uri.parse("$kBaseUrl/api/v1/mood/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${user.uid}"
        },
        body: jsonEncode({
          "score": score,
          "emoji": emoji,
          "description": description,
          "tags": tags,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newEntry = MoodEntry.fromJson(data, id: data['id']);
        state.whenData((list) {
          final newList = [newEntry, ...list];
          state = AsyncValue.data(newList);
          LocalCacheService().saveMoodEntries(user.uid, newList);
        });
      } else {
        throw Exception("Erro ao salvar registro de humor: ${response.statusCode}");
      }
    } catch (e) {
      // Fallback local se offline
      final user = FirebaseAuth.instance.currentUser;
      final newEntry = MoodEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user?.uid ?? '',
        score: score,
        emoji: emoji,
        tags: tags,
        description: description,
        timestamp: DateTime.now(),
      );
      state.whenData((list) {
        final newList = [newEntry, ...list];
        state = AsyncValue.data(newList);
        if (user != null) {
          LocalCacheService().saveMoodEntries(user.uid, newList);
        }
      });
    }
  }
}

final moodEntriesProvider = StateNotifierProvider<MoodEntriesNotifier, AsyncValue<List<MoodEntry>>>((ref) {
  return MoodEntriesNotifier();
});
