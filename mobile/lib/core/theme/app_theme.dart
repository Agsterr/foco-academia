import 'package:flutter/material.dart';

/// Tema visual do app do aluno: escuro, com azul da marca e cantos arredondados.
/// Centralizado aqui para que todas as telas (cards, botões, campos, barras)
/// sigam o mesmo padrão sem precisar de estilo em cada widget.
class AppTheme {
  AppTheme._();

  static const brand = Color(0xFF3B82F6);
  static const brandDeep = Color(0xFF1D4ED8);
  static const accent = Color(0xFF22D3EE);
  static const background = Color(0xFF070B17);
  static const surface = Color(0xFF0F172A);
  static const surfaceHigh = Color(0xFF16213A);
  static const outline = Color(0xFF1F2A44);

  static const brandGradient = LinearGradient(
    colors: [Color(0xFF60A5FA), brandDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.dark,
    ).copyWith(
      primary: brand,
      secondary: accent,
      surface: surface,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHigh,
      outline: outline,
      outlineVariant: outline,
    );

    final radius = BorderRadius.circular(16);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaceHigh,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF93C5FD)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: outline)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: brand, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: Color(0xFFF87171))),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        iconColor: Color(0xFF93C5FD),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brand.withValues(alpha: 0.22),
        height: 68,
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: brand,
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: brand),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1),
    );
  }
}
