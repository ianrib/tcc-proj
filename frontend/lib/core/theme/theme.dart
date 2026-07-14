import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Cores do Tema Claro (Paleta Terapêutica)
  static const Color primaryLight = Color(0xFF0F766E);    // Teal profundo
  static const Color secondaryLight = Color(0xFF0284C7);  // Azul calmo
  static const Color backgroundLight = Color(0xFFF8FAFC); // Off-white suave
  static const Color cardLight = Color(0xFFFFFFFF);       // Branco puro
  static const Color textLight = Color(0xFF0F172A);       // Slate Escuro

  // Cores do Tema Escuro (Paleta Terapêutica)
  static const Color primaryDark = Color(0xFF0D9488);     // Teal calmo
  static const Color secondaryDark = Color(0xFF38BDF8);   // Azul Céu suave
  static const Color backgroundDark = Color(0xFF0F172A);  // Slate Escuro
  static const Color cardDark = Color(0xFF1E293B);        // Slate Médio
  static const Color textDark = Color(0xFFF8FAFC);        // Branco Gelo fosco

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        secondary: secondaryLight,
        surface: cardLight,
        onSurface: textLight,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: textLight,
        displayColor: textLight,
      ),
      cardTheme: const CardThemeData(
        color: cardLight,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        secondary: secondaryDark,
        surface: cardDark,
        onSurface: textDark,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textDark,
        displayColor: textDark,
      ),
        cardTheme: const CardThemeData(
          color: cardDark,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
