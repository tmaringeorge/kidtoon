import 'package:flutter/material.dart';

/// Culorile KidToon: vesele, cu contrast mare, ușor de văzut de departe (pe TV).
class KidColors {
  static const background = Color(0xFF1B1446);
  static const panel = Color(0xFF241A5C);
  static const card = Color(0xFF2E2370);
  static const logoBox = Color(0xFF1F1750);
  static const accent = Color(0xFFFFC93C);
  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xFFC9C2F0);
  static const live = Color(0xFFFF5A79);

  /// Culorile plăcilor mari de pe ecranul principal.
  static const purple = Color(0xFF8E5CFF);
  static const pink = Color(0xFFFF5C9D);
  static const orange = Color(0xFFFF8A3D);
  static const yellow = Color(0xFFFFC93C);
  static const green = Color(0xFF3DD68C);
  static const blue = Color(0xFF3DA5FF);
  static const teal = Color(0xFF2EC4B6);
  static const red = Color(0xFFFF4D4D);

  /// Rama de focus pe TV: copilul vede imediat ce e ales cu telecomanda.
  static const focus = Color(0xFFFFFFFF);
}

ThemeData kidTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: KidColors.purple,
    brightness: Brightness.dark,
    primary: KidColors.accent,
    onPrimary: const Color(0xFF2A1A00),
    secondary: KidColors.pink,
    surface: KidColors.background,
  );
  final round = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: KidColors.background,
    drawerTheme: const DrawerThemeData(backgroundColor: KidColors.panel),
    appBarTheme: const AppBarTheme(
      backgroundColor: KidColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: KidColors.text),
    ),
    cardTheme: const CardThemeData(color: KidColors.card),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: round,
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
    // Pe TV, butonul ales are o ramă albă groasă.
    focusColor: const Color(0x55FFFFFF),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.focused) ? const BorderSide(color: KidColors.focus, width: 3) : null,
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(shape: round),
  );
}

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
