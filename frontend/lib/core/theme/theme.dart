import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Cores do Tema Claro (fornecidas pelo usuário)
  static const Color primaryLight = Color(0xFF4A90E2);    // Azul suave
  static const Color secondaryLight = Color(0xFF5BC0BE);  // Teal/Verde água
  static const Color backgroundLight = Color(0xFFF6FAFD); // Azulado bem claro
  static const Color cardLight = Color(0xFFFFFFFF);       // Branco
  static const Color textLight = Color(0xFF2C3E50);       // Cinza escuro/Slate

  // Cores do Tema Escuro (fornecidas pelo usuário)
  static const Color primaryDark = Color(0xFF60A5FA);     // Azul claro vibrante
  static const Color secondaryDark = Color(0xFF5EEAD4);   // Turquesa/Teal claro
  static const Color backgroundDark = Color(0xFF0F172A);  // Slate Escuro
  static const Color cardDark = Color(0xFF1E293B);        // Slate Médio
  static const Color textDark = Color(0xFFF8FAFC);        // Quase branco

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
        fillColor: backgroundLight,
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
        fillColor: backgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
