import 'package:flutter/material.dart';

/// The web app's look: Tailwind's gray scale, white cards with soft shadows,
/// rounded corners, the Figtree font and blue/green/orange pill buttons.
class Tw {
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF111827);

  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const orange500 = Color(0xFFF97316);
  static const orange600 = Color(0xFFEA580C);
  static const amber600 = Color(0xFFD97706);
  static const amber400 = Color(0xFFFBBF24);
  static const yellow500 = Color(0xFFEAB308);
  static const purple500 = Color(0xFFA855F7);
  static const red600 = Color(0xFFDC2626);
  static const red400 = Color(0xFFF87171);

  /// The colour the server calls "green", "orange"... for a list's overall state.
  static Color named(String color) => switch (color) {
        'green' => green500,
        'blue' => blue500,
        'orange' => orange500,
        'yellow' => yellow500,
        'purple' => purple500,
        _ => gray500,
      };
}

class AppTheme {
  static const fontFamily = 'Figtree';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final page = dark ? Tw.gray900 : Tw.gray100;
    final surface = dark ? Tw.gray800 : Colors.white;
    final text = dark ? Tw.gray100 : Tw.gray900;
    final border = dark ? Tw.gray600 : Tw.gray300;

    final scheme = ColorScheme.fromSeed(
      seedColor: Tw.blue500,
      brightness: brightness,
    ).copyWith(
      primary: dark ? Tw.gray200 : Tw.gray800, // the web's dark "primary button"
      onPrimary: dark ? Tw.gray800 : Colors.white,
      surface: surface,
      onSurface: text,
      outline: border,
      error: dark ? Tw.red400 : Tw.red600,
    );

    OutlineInputBorder outline(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      canvasColor: surface,
      dividerColor: dark ? Tw.gray700 : Tw.gray200,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black54,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        shadowColor: Colors.black45,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: dark ? Tw.gray700 : Tw.gray100,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: text)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: outline(border),
        enabledBorder: outline(border),
        focusedBorder: outline(dark ? Tw.gray300 : Tw.gray800, 2),
        errorBorder: outline(scheme.error),
        focusedErrorBorder: outline(scheme.error, 2),
        labelStyle: TextStyle(color: dark ? Tw.gray300 : Tw.gray700, fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(color: dark ? Tw.gray300 : Tw.gray700, fontWeight: FontWeight.w500),
      ),
      // The web's main button: dark, small, bold, upper case, softly rounded
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? Tw.blue500 : Tw.blue600,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? Tw.gray700 : Tw.gray800,
        contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: dark ? Tw.gray700 : Tw.gray200, space: 1, thickness: 1),
    );
  }
}
