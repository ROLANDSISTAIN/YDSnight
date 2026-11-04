import 'package:flutter/material.dart';

/// Couleurs de Nocta : bleu nuit et cyan.
/// Un seul mode, sombre : lisible dans la pénombre du club ou du bar.
/// (Les noms « or » sont gardés pour l'historique du code : ce sont
/// désormais les teintes cyan de l'accent.)
class HC {
  static const fond = Color(0xFF070D1C);
  static const surface = Color(0xFF0F1B33);
  static const surface2 = Color(0xFF142440);
  static const bordure = Color(0xFF263C63);
  static const or = Color(0xFF22D3EE);        // accent cyan
  static const orClair = Color(0xFF6EE7FB);
  static const orFonce = Color(0xFF2AA7BD);
  static const texte = Color(0xFFE6F0FF);
  static const gris = Color(0xFF8CA4C6);
  static const vert = Color(0xFF5CC489);
  static const rouge = Color(0xFFF07167);
  static const bleu = Color(0xFF6FA8FF);

  static const fondVert = Color(0xFF15281D);
  static const fondRouge = Color(0xFF331816);
  static const fondOr = Color(0xFF0E2E3A);     // pastille d'accent (cyan foncé)
  static const fondBleu = Color(0xFF14213A);
}

class HaremTheme {
  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: HC.or,
        onPrimary: Color(0xFF04121F),
        secondary: HC.orClair,
        onSecondary: Color(0xFF04121F),
        surface: HC.surface,
        onSurface: HC.texte,
        surfaceContainerHighest: HC.surface2,
        error: HC.rouge,
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: HC.fond,
      canvasColor: HC.surface,
      dividerColor: HC.bordure,
    );
    final arrondi = BorderRadius.circular(12);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: HC.fond,
        foregroundColor: HC.texte,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: HC.texte),
      ),
      cardTheme: CardThemeData(
        color: HC.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: arrondi, side: const BorderSide(color: HC.bordure)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HC.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HC.surface2,
        border: OutlineInputBorder(borderRadius: arrondi, borderSide: const BorderSide(color: HC.bordure)),
        enabledBorder: OutlineInputBorder(borderRadius: arrondi, borderSide: const BorderSide(color: HC.bordure)),
        focusedBorder: OutlineInputBorder(borderRadius: arrondi, borderSide: const BorderSide(color: HC.or, width: 2)),
        labelStyle: const TextStyle(color: HC.gris),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HC.or,
          foregroundColor: const Color(0xFF04121F),
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: arrondi),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HC.or,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: HC.bordure),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: arrondi),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: HC.or)),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: HC.surface2,
        contentTextStyle: TextStyle(color: HC.texte, fontSize: 15),
        behavior: SnackBarBehavior.floating,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: HC.surface,
        indicatorColor: HC.fondOr,
        selectedIconTheme: IconThemeData(color: HC.or),
        unselectedIconTheme: IconThemeData(color: HC.gris),
        selectedLabelTextStyle: TextStyle(color: HC.or, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: TextStyle(color: HC.gris),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: HC.surface2,
        selectedColor: HC.fondOr,
        side: const BorderSide(color: HC.bordure),
        labelStyle: const TextStyle(color: HC.texte),
      ),
    );
  }
}
