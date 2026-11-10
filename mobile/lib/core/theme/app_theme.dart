import 'package:flutter/material.dart';

/// Tema visual do app: escuro, com cores vivas, gradientes e a fonte Poppins.
///
/// Centralizado aqui para que todas as telas (cards, botões, campos, barras)
/// sigam o mesmo padrão sem precisar de estilo em cada widget.
class AppTheme {
  AppTheme._();

  static const fontFamily = 'Poppins';

  // ---------------------------------------------------------------- cores da marca
  /// Violeta elétrico: cor principal (botões, seleção, links).
  static const brand = Color(0xFF7C5CFF);
  static const brandDeep = Color(0xFF5B3DF5);

  /// Rosa neon: segunda cor da marca, usada nos gradientes.
  static const accent = Color(0xFFFF4D9D);

  static const background = Color(0xFF0B0A1A);
  static const surface = Color(0xFF15142B);
  static const surfaceHigh = Color(0xFF1F1D3B);
  static const outline = Color(0xFF2C2A4E);
  static const muted = Color(0xFFA5A3C9);

  // ---------------------------------------------------------------- paleta viva
  static const violet = Color(0xFF8B5CF6);
  static const pink = Color(0xFFFF4D9D);
  static const orange = Color(0xFFFF7A1A);
  static const amber = Color(0xFFFFC233);
  static const lime = Color(0xFFB4F02B);
  static const green = Color(0xFF22D97A);
  static const teal = Color(0xFF14D2C4);
  static const cyan = Color(0xFF22C7F5);
  static const blue = Color(0xFF3D8BFF);
  static const red = Color(0xFFFF4D5E);

  // ---------------------------------------------------------------- gradientes
  /// Violeta → rosa: a "cara" do app (botão principal, cabeçalhos).
  static const brandGradient = LinearGradient(
    colors: [Color(0xFF7C5CFF), Color(0xFFC04DFF), Color(0xFFFF4D9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const fireGradient = LinearGradient(
    colors: [Color(0xFFFF4D5E), Color(0xFFFF7A1A), Color(0xFFFFB020)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const oceanGradient = LinearGradient(
    colors: [Color(0xFF3D8BFF), Color(0xFF22C7F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const freshGradient = LinearGradient(
    colors: [Color(0xFF14D2C4), Color(0xFF22D97A), Color(0xFFB4F02B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFFFC233), Color(0xFFFF7A1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const berryGradient = LinearGradient(
    colors: [Color(0xFFFF4D9D), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const nightGradient = LinearGradient(
    colors: [Color(0xFF5B3DF5), Color(0xFF3D8BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Cor sólida que representa cada gradiente (sombras, textos, bordas).
  static Color glowOf(Gradient gradient) => gradient.colors.first;

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.dark,
    ).copyWith(
      primary: brand,
      onPrimary: Colors.white,
      secondary: accent,
      tertiary: teal,
      surface: surface,
      onSurface: Colors.white,
      onSurfaceVariant: muted,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHigh,
      outline: outline,
      outlineVariant: outline,
      error: red,
    );

    final radius = BorderRadius.circular(18);
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: fontFamily);
    final text = base.textTheme.apply(fontFamily: fontFamily, bodyColor: Colors.white, displayColor: Colors.white).copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontFamily: fontFamily, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
              fontFamily: fontFamily, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: Colors.white),
          titleLarge: base.textTheme.titleLarge?.copyWith(
              fontFamily: fontFamily, fontWeight: FontWeight.w700, color: Colors.white),
          titleMedium: base.textTheme.titleMedium?.copyWith(
              fontFamily: fontFamily, fontWeight: FontWeight.w600, color: Colors.white),
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceHigh,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaceHigh,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: outline, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFC4B5FD),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 6,
        extendedTextStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? brand : surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? Colors.white : muted,
          ),
          side: WidgetStateProperty.all(const BorderSide(color: outline)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: muted),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.6)),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused) ? brand : muted,
        ),
        border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: outline)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: brand, width: 1.8)),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: red)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: brand.withValues(alpha: 0.35),
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brand : Colors.transparent,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brand : surfaceHigh,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        iconColor: Color(0xFFC4B5FD),
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        subtitleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 13, color: muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brand.withValues(alpha: 0.30),
        height: 70,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? Colors.white : muted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? Colors.white : muted,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: brand,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: muted,
        indicatorColor: accent,
        labelStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: const TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: outline,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: brand, linearTrackColor: surfaceHigh),
      sliderTheme: const SliderThemeData(activeTrackColor: brand, thumbColor: Colors.white),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1),
    );
  }
}
