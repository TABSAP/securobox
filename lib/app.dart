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
    final bg = dark ? const Color(0xFF0B0B0F) : const Color(0xFFFFFFFF);
    final surface = dark ? const Color(0xFF141418) : const Color(0xFFFFFFFF);
    final raised = dark ? const Color(0xFF1A1A20) : const Color(0xFFF3F4F6);
    final textPrimary =
        dark ? const Color(0xFFFFFFFF) : const Color(0xFF0A0A0C);
    final textSecondary =
        dark ? const Color(0xFFA0A4AB) : const Color(0xFF5B5F66);
    final textTertiary =
        dark ? const Color(0xFF6B7078) : const Color(0xFF9AA0A8);
    final accent = dark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);
    final outline = dark ? const Color(0x1AFFFFFF) : const Color(0xFFE6E8EC);
    final inputFill = dark ? const Color(0x14FFFFFF) : const Color(0xFFF1F2F4);
    final divider = dark ? const Color(0x14FFFFFF) : const Color(0xFFEDEEF1);

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
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
