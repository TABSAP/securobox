import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_app/splash_screen/splash_screen.dart';
import 'package:video_player_app/utils/liquid_colors.dart';
import 'package:video_player_app/utils/liquid_page_transitions.dart';
import 'package:video_player_app/utils/theme_controller.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final mode = ThemeController.instance.mode;
        final isDark =
            ThemeController.instance.effectiveBrightness == Brightness.dark;
        // Keep LiquidColors + the status bar in sync with the resolved theme.
        LiquidColors.applyBrightness(
            isDark ? Brightness.dark : Brightness.light);
        SystemChrome.setSystemUIOverlayStyle(
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SecuroBox',
          themeMode: mode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: const SplashScreen(),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // LiquidColors is global mutable state, so compute palette pieces
    // explicitly here rather than reading the (possibly mismatched) getters.
    final bg = dark ? const Color(0xFF0A0F1E) : const Color(0xFFF4F6FB);
    final surface = dark ? const Color(0xFF141B2B) : const Color(0xFFFFFFFF);
    final raised = dark ? const Color(0xFF1E2738) : const Color(0xFFF1F4FA);
    final textPrimary =
        dark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1F2E);
    final textSecondary =
        dark ? const Color(0xFF9CA3AF) : const Color(0xFF5B6472);
    final textTertiary =
        dark ? const Color(0xFF6B7280) : const Color(0xFF8A93A3);
    final accent = dark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
    final outline = dark ? const Color(0x14FFFFFF) : const Color(0xFFE1E6EF);
    final inputFill = dark ? const Color(0x14FFFFFF) : const Color(0xFFEDF0F7);
    final divider = dark ? const Color(0x0FFFFFFF) : const Color(0xFFE6EAF1);

    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(surface: surface, onSurface: textPrimary, primary: accent);

    return base.copyWith(
      colorScheme: scheme,
      pageTransitionsTheme: liquidPageTransitionsTheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: divider,
      iconTheme: IconThemeData(color: textPrimary),
      primaryIconTheme: IconThemeData(color: textPrimary),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
        decorationColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: textSecondary, height: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: raised,
      ),
      cardColor: surface,
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: dark ? 0 : 1,
      ),
      dividerTheme: DividerThemeData(color: divider),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: TextStyle(color: textTertiary),
        labelStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : (dark ? const Color(0xFF6B7280) : const Color(0xFFB8C0CE)),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.45)
              : (dark ? const Color(0x33FFFFFF) : const Color(0xFFD7DCE6)),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.3),
        selectionHandleColor: accent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: raised,
        contentTextStyle: TextStyle(color: textPrimary),
        actionTextColor: accent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: raised,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
      ),
    );
  }
}
