import 'package:flutter/material.dart';

class AppColors {
  static const black = Color(0xff050505);
  static const surface = Color(0xff1e1e1f);
  static const surfaceAlt = Color(0xff2a2a2c);
  static const textMuted = Color(0xffa7a7ad);
  static const mint = Color(0xff5af28a);
  static const cyan = Color(0xff55e1cf);
  static const lime = Color(0xffd9ff3f);
  static const blue = Color(0xff1689ff);
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.black,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.mint,
      secondary: AppColors.cyan,
      surface: AppColors.surface,
      onSurface: Colors.white,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
      fontFamily: 'Roboto',
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.mint),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.mint,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceAlt,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}

const leagueGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xfff0ff18),
    Color(0xff55f48e),
    Color(0xff20b4ff),
    Color(0xff1768ff),
  ],
);

const cardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff60f590), Color(0xff56decf)],
);
