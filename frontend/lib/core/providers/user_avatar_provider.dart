import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Provider that stores cached avatar base64 strings by userId
final userAvatarProvider = StateNotifierProvider<UserAvatarNotifier, Map<String, String>>((ref) {
  return UserAvatarNotifier();
});

class UserAvatarNotifier extends StateNotifier<Map<String, String>> {
  UserAvatarNotifier() : super({});

  Future<void> loadAvatar(String userId) async {
    if (state.containsKey(userId)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = prefs.getString('user_avatar_base64_$userId');
      if (base64String != null) {
        state = {...state, userId: base64String};
      }
    } catch (e) {
      debugPrint('Erro ao carregar avatar do cache: $e');
    }
  }

  Future<void> fetchAndCacheAvatar(String userId, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUrl = prefs.getString('user_avatar_url_$userId');
      
      // If cached URL matches and we already have base64 cached, load it
      if (cachedUrl == url && prefs.containsKey('user_avatar_base64_$userId')) {
        final cachedBase64 = prefs.getString('user_avatar_base64_$userId');
        if (cachedBase64 != null) {
          state = {...state, userId: cachedBase64};
          return;
        }
      }

      // Otherwise, download, encode to base64, and save
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final base64String = base64Encode(response.bodyBytes);
        await prefs.setString('user_avatar_base64_$userId', base64String);
        await prefs.setString('user_avatar_url_$userId', url);
        state = {...state, userId: base64String};
      }
    } catch (e) {
      debugPrint('Erro ao salvar avatar no cache: $e');
    }
  }
}
