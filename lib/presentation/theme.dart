import 'package:flutter/material.dart';

/// Farben aus dem visuellen Konzept (Konzeptbericht Kapitel 3).
class RefindColors {
  static const background = Color(0xFFECEAE6); // warmes Hellgrau
  static const field = Colors.white;
  static const ink = Color(0xFF1A1A1A); // fast Schwarz: Text, Buttons
  static const muted = Color(0xFF8A8782); // Grau für Hinweise
  static const accent = Color(0xFFB5452B); // Rostrot: Angebot senden, Fehler
}

/// Kleine Grossbuchstaben-Beschriftung über Feldern («MAILADRESSE»).
const TextStyle refindLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.2,
  color: RefindColors.muted,
);

ThemeData buildRefindTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: RefindColors.accent,
    surface: RefindColors.background,
  ).copyWith(
    primary: RefindColors.ink,
    onPrimary: Colors.white,
    secondary: RefindColors.accent,
    error: RefindColors.accent,
  );

  const stadium = StadiumBorder();
  const buttonSize = Size.fromHeight(52);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RefindColors.background,
    // Titel in Serifenschrift wie «Melde dich an.» im Konzept.
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontFamily: 'serif', fontSize: 34, height: 1.1, color: RefindColors.ink),
      headlineMedium: TextStyle(fontFamily: 'serif', fontSize: 30, height: 1.1, color: RefindColors.ink),
      titleLarge: TextStyle(fontFamily: 'serif', fontSize: 22, color: RefindColors.ink),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RefindColors.background,
      foregroundColor: RefindColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RefindColors.ink,
        foregroundColor: Colors.white,
        minimumSize: buttonSize,
        shape: stadium,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RefindColors.ink,
        minimumSize: buttonSize,
        shape: stadium,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: RefindColors.ink),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: RefindColors.field,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: RefindColors.ink),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: RefindColors.accent),
      ),
      hintStyle: TextStyle(color: RefindColors.muted),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: RefindColors.background,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: RefindColors.background,
      showDragHandle: true,
    ),
    // Auswahl-Chips wie «Uhren», «Möbel»: gewählt schwarz, sonst weiss.
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: RefindColors.ink,
      labelStyle: const TextStyle(color: RefindColors.ink),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      showCheckmark: false,
      side: const BorderSide(color: Color(0xFFDDDAD5)),
      shape: const StadiumBorder(),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: RefindColors.ink,
      inactiveTrackColor: Color(0xFFD5D2CC),
      thumbColor: RefindColors.ink,
      trackHeight: 2,
    ),
  );
}
