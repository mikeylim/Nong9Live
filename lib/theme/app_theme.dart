import 'package:flutter/material.dart';

class AppColors {
  static const orange = Color(0xFFFF6B1A);
  static const orangeDeep = Color(0xFFE2550A);
  static const court = Color(0xFF161925);
  static const courtLow = Color(0xFF10121B);
  static const courtCard = Color(0xFF1F2333);
  static const courtCardHigh = Color(0xFF292E42);
  static const win = Color(0xFF22C55E);
  static const loss = Color(0xFFEF4444);
  static const gold = Color(0xFFFFC83D);
  static const made = Color(0xFF16A34A);
  static const miss = Color(0xFF64748B);
  static const foul = Color(0xFFF59E0B);
  static const live = Color(0xFFFF3B47);
}

/// Single-series chart color, stepped per mode so it passes the lightness
/// band and 3:1 contrast against each card surface (validated).
Color chartSeriesColor(Brightness b) => b == Brightness.dark ? const Color(0xFFF0601A) : const Color(0xFFE2550A);

const displayFont = 'BarlowCondensed';

/// Shirt colors can be near-black or near-white; nudge them so a team bar or
/// stripe stays visible against the surface it sits on.
Color visibleTeamColor(Color c, {required bool onDark}) {
  final l = c.computeLuminance();
  if (onDark && l < 0.06) return Color.lerp(c, Colors.white, 0.42)!;
  if (!onDark && l > 0.75) return Color.lerp(c, Colors.black, 0.25)!;
  return c;
}

Color visibleTeamColorIn(BuildContext context, Color c) =>
    visibleTeamColor(c, onDark: Theme.of(context).brightness == Brightness.dark);

/// Dark theme used by the live scorer regardless of the app theme.
final ThemeData arenaTheme = buildTheme(Brightness.dark);
const bodyFont = 'Barlow';

/// Big condensed numerals for scores and stats.
TextStyle scoreStyle(double size, {Color? color, FontWeight weight = FontWeight.w900}) => TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      fontWeight: weight,
      height: 1.0,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(seedColor: AppColors.orange, brightness: brightness);
  final scheme = base.copyWith(
    primary: AppColors.orange,
    onPrimary: Colors.white,
    primaryContainer: dark ? const Color(0xFF4A2410) : const Color(0xFFFFE3D2),
    onPrimaryContainer: dark ? const Color(0xFFFFD2B8) : const Color(0xFF4A1E05),
    secondary: dark ? const Color(0xFF8AB4FF) : const Color(0xFF2F5BD3),
    tertiary: AppColors.gold,
    error: AppColors.loss,
    surface: dark ? AppColors.court : const Color(0xFFF7F5F2),
    onSurface: dark ? const Color(0xFFF2F3F7) : const Color(0xFF15171F),
    onSurfaceVariant: dark ? const Color(0xFFA3A8BC) : const Color(0xFF5F6271),
    surfaceContainerLowest: dark ? AppColors.courtLow : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF1A1D2A) : const Color(0xFFFBFAF8),
    surfaceContainer: dark ? AppColors.courtCard : Colors.white,
    surfaceContainerHigh: dark ? AppColors.courtCardHigh : const Color(0xFFF0ECE7),
    surfaceContainerHighest: dark ? const Color(0xFF333850) : const Color(0xFFE6E1DB),
    outline: dark ? const Color(0xFF454B63) : const Color(0xFFC9C3BB),
    outlineVariant: dark ? const Color(0xFF2C3044) : const Color(0xFFE7E2DC),
  );

  final textBase = (dark ? Typography.whiteMountainView : Typography.blackMountainView).apply(
    fontFamily: bodyFont,
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  TextStyle? condensed(TextStyle? s, double size, [FontWeight w = FontWeight.w800]) =>
      s?.copyWith(fontFamily: displayFont, fontSize: size, fontWeight: w, height: 1.1, letterSpacing: 0.2);

  final text = textBase.copyWith(
    displayLarge: condensed(textBase.displayLarge, 56, FontWeight.w900),
    displayMedium: condensed(textBase.displayMedium, 44, FontWeight.w900),
    displaySmall: condensed(textBase.displaySmall, 36, FontWeight.w900),
    headlineLarge: condensed(textBase.headlineLarge, 34),
    headlineMedium: condensed(textBase.headlineMedium, 28),
    headlineSmall: condensed(textBase.headlineSmall, 24),
    titleLarge: condensed(textBase.titleLarge, 22, FontWeight.w700),
    titleMedium: textBase.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
    titleSmall: textBase.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: textBase.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
    labelMedium: textBase.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: textBase.bodyLarge?.copyWith(fontSize: 16),
    bodyMedium: textBase.bodyMedium?.copyWith(fontSize: 14.5),
  );

  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: bodyFont,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.headlineSmall,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: dark ? BorderSide.none : BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: scheme.outline),
        textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: rounded,
        textStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.orange,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: 16),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600, color: scheme.onSurface),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(rounded),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: dark ? AppColors.courtLow : Colors.white,
      indicatorColor: AppColors.orange.withValues(alpha: 0.18),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.orange : scheme.onSurfaceVariant),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: bodyFont,
          fontSize: 12.5,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.onDrag),
  );
}
