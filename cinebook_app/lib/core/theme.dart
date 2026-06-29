import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

//The Grand Cinema palette — obsidian surfaces, champagne gold accent.
abstract class AppColors {
  static const background = Color(0xFF121414);
  static const surface = Color(0xFF121414);
  static const surfaceContainerLowest = Color(0xFF0D0E0F);
  static const surfaceContainerLow = Color(0xFF1A1C1C);
  static const surfaceContainer = Color(0xFF1E2020);
  static const surfaceContainerHigh = Color(0xFF292A2A);
  static const surfaceContainerHighest = Color(0xFF343535);
  static const surfaceBright = Color(0xFF383939);
  static const surfaceVariant = Color(0xFF343535);

  static const onSurface = Color(0xFFE3E2E2);
  static const onSurfaceVariant = Color(0xFFD0C5AF);
  static const onBackground = Color(0xFFE3E2E2);

  static const primary = Color(0xFFF2CA50);
  static const primaryContainer = Color(0xFFD4AF37);
  static const primaryFixed = Color(0xFFFFE088);
  static const onPrimary = Color(0xFF3C2F00);
  static const inversePrimary = Color(0xFF735C00);

  static const outline = Color(0xFF99907C);
  static const outlineVariant = Color(0xFF4D4635);

  static const secondaryFixedDim = Color(0xFFC8C6C8);

  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);

  //Seat-category colors mirror the seat-selection design.
  static const seatFront = Color(0xFF343535);
  static const seatStandard = Color(0xFF2A4365);
  static const seatPremium = Color(0xFF553C9A);
  static const seatRecliner = Color(0xFF735C00);
}

//Glow + glass tokens reused across screens.
abstract class AppShadows {
  static const goldGlow = [
    BoxShadow(color: Color(0x33F2CA50), blurRadius: 20, spreadRadius: -5),
  ];
  static const ambient = [
    BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 10)),
  ];
}

abstract class AppRadii {
  static const button = 8.0;
  static const card = 12.0;
  static const pill = 999.0;
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    surfaceContainerHighest: AppColors.surfaceContainerHighest,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    secondary: AppColors.primaryContainer,
    onSecondary: AppColors.onPrimary,
    error: AppColors.error,
    onError: AppColors.onError,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
  );

  final body = GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
    bodyColor: AppColors.onSurface,
    displayColor: AppColors.onSurface,
  );

  //Playfair Display for the editorial headline roles.
  final display = GoogleFonts.playfairDisplay;

  final textTheme = body.copyWith(
    displayLarge: display(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 40 / 32,
      color: AppColors.onSurface,
    ),
    headlineMedium: display(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 32 / 24,
      color: AppColors.onSurface,
    ),
    titleLarge: display(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 32 / 24,
      color: AppColors.onSurface,
    ),
    bodyLarge: body.bodyLarge?.copyWith(fontSize: 18, height: 28 / 18),
    bodyMedium: body.bodyMedium?.copyWith(fontSize: 16, height: 24 / 16),
    labelMedium: body.labelMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.7,
      color: AppColors.onSurface,
    ),
    labelSmall: body.labelSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.onSurfaceVariant,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    textTheme: textTheme,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.onSurface,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        textStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        textStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerHigh,
      hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outlineVariant,
      thickness: 1,
    ),
  );
}
