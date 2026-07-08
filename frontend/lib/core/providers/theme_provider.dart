import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode_preference';

  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  /// Carrega a preferência de tema salva nas SharedPreferences do dispositivo.
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_key);
      if (themeIndex != null) {
        state = ThemeMode.values[themeIndex];
      }
    } catch (e) {
      debugPrint("Erro ao carregar tema persistido: $e");
    }
  }

  /// Define e persiste o novo modo de tema do aplicativo.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, mode.index);
    } catch (e) {
      debugPrint("Erro ao salvar escolha de tema: $e");
    }
  }
}

/// Provider global que expõe o estado do ThemeMode e permite atualizá-lo.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});
