import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Farbpalette: tiefes Nachtblau, Neon-Akzente, viel Glas.
abstract final class AppColors {
  static const bg = Color(0xFF05060B);
  static const text = Color(0xFFF4F5FA);
  static const textDim = Color(0x99F4F5FA);
  static const textFaint = Color(0x55F4F5FA);
  static const stroke = Color(0x1FFFFFFF);

  static const violet = Color(0xFF7B5CFF);
  static const cyan = Color(0xFF22D3EE);
  static const pink = Color(0xFFFF4FD8);
  static const green = Color(0xFF2EF2A0);
  static const greenDeep = Color(0xFF0BAE6E);
  static const red = Color(0xFFFF3D6E);
  static const redDeep = Color(0xFFD1194A);
  static const amber = Color(0xFFFFC145);

  static const auroraIdle = [violet, cyan, pink, Color(0xFF3B5BFF)];
  static const auroraError = [red, pink, violet, Color(0xFF8A1F4F)];
  static const auroraWarn = [amber, pink, violet, Color(0xFF6B3CFF)];
  static const auroraRinging = [pink, violet, cyan, amber];
  static const auroraLive = [green, cyan, violet, Color(0xFF00A3FF)];
  static const auroraEnded = [
    Color(0xFF3A3F55),
    violet,
    Color(0xFF1C2033),
    red,
  ];

  static const accentGradient = LinearGradient(
    colors: [violet, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyan,
        secondary: AppColors.violet,
        surface: AppColors.bg,
        error: AppColors.red,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
    return base.copyWith(
      textTheme: GoogleFonts.soraTextTheme(
        base.textTheme,
      ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.cyan,
        selectionColor: Color(0x5522D3EE),
        selectionHandleColor: AppColors.cyan,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
