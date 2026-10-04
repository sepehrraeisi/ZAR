import 'package:flutter/material.dart';

/// Material 3 tokens from the ZAR+ design handoff (zar-tokens.css).
/// Base values match the Flutter `_theme()`: seed #C08A3D, scaffold #FBFAF8,
/// card #FFFFFF, divider #ECEAE6, input fill #F6F4F1 r14, sheet r24,
/// dark scaffold #151515 / card #1D1D1D.

class ZarSemanticColors extends ThemeExtension<ZarSemanticColors> {
  const ZarSemanticColors({
    required this.positive,
    required this.onPositive,
    required this.positiveContainer,
    required this.negative,
    required this.onNegative,
    required this.negativeContainer,
  });

  final Color positive;
  final Color onPositive;
  final Color positiveContainer;
  final Color negative;
  final Color onNegative;
  final Color negativeContainer;

  static const light = ZarSemanticColors(
    positive: Color(0xFF1F7A50),
    onPositive: Color(0xFFFFFFFF),
    positiveContainer: Color(0xFFDDF2E6),
    negative: Color(0xFFB3261E),
    onNegative: Color(0xFFFFFFFF),
    negativeContainer: Color(0xFFFBE3E0),
  );

  static const dark = ZarSemanticColors(
    positive: Color(0xFF7FD6A6),
    onPositive: Color(0xFF003922),
    positiveContainer: Color(0xFF16382A),
    negative: Color(0xFFFFB4AB),
    onNegative: Color(0xFF5F1512),
    negativeContainer: Color(0xFF4A1915),
  );

  @override
  ZarSemanticColors copyWith({
    Color? positive,
    Color? onPositive,
    Color? positiveContainer,
    Color? negative,
    Color? onNegative,
    Color? negativeContainer,
  }) => ZarSemanticColors(
    positive: positive ?? this.positive,
    onPositive: onPositive ?? this.onPositive,
    positiveContainer: positiveContainer ?? this.positiveContainer,
    negative: negative ?? this.negative,
    onNegative: onNegative ?? this.onNegative,
    negativeContainer: negativeContainer ?? this.negativeContainer,
  );

  @override
  ZarSemanticColors lerp(ThemeExtension<ZarSemanticColors>? other, double t) {
    if (other is! ZarSemanticColors) return this;
    return ZarSemanticColors(
      positive: Color.lerp(positive, other.positive, t)!,
      onPositive: Color.lerp(onPositive, other.onPositive, t)!,
      positiveContainer:
          Color.lerp(positiveContainer, other.positiveContainer, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      onNegative: Color.lerp(onNegative, other.onNegative, t)!,
      negativeContainer:
          Color.lerp(negativeContainer, other.negativeContainer, t)!,
    );
  }
}

extension ZarSemanticContext on BuildContext {
  ZarSemanticColors get zarSemantic =>
      Theme.of(this).extension<ZarSemanticColors>() ?? ZarSemanticColors.light;
}

const zarAccentLight = Color(0xFFC08A3D);
const zarAccentDark = Color(0xFFD9A355);
const zarOnAccentLight = Color(0xFF1F1300);
const zarOnAccentDark = Color(0xFF241600);

ThemeData zarBuildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final accent = isDark ? zarAccentDark : zarAccentLight;
  final onAccent = isDark ? zarOnAccentDark : zarOnAccentLight;
  final scaffold = isDark ? const Color(0xFF151515) : const Color(0xFFFBFAF8);
  final card = isDark ? const Color(0xFF1D1D1D) : Colors.white;
  final onSurface = isDark ? const Color(0xFFECE7E0) : const Color(0xFF1E1B16);
  final onSurfaceVariant =
      isDark ? const Color(0xFFB8B0A4) : const Color(0xFF605A50);
  final outline = isDark ? const Color(0xFF8F887E) : const Color(0xFF8B8378);
  final outlineVariant =
      isDark ? const Color(0xFF2E2D2B) : const Color(0xFFECEAE6);

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: isDark
        ? const Color(0xFF5E4000)
        : const Color(0xFFF7E4C6),
    onPrimaryContainer: isDark
        ? const Color(0xFFFFDDB0)
        : const Color(0xFF2A1800),
    secondary: accent,
    onSecondary: onAccent,
    secondaryContainer: isDark
        ? const Color(0xFF3A3024)
        : const Color(0xFFF1E6D6),
    onSecondaryContainer: isDark
        ? const Color(0xFFF1E0C8)
        : const Color(0xFF3A2A12),
    tertiary: accent,
    onTertiary: onAccent,
    error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
    onError: isDark ? const Color(0xFF5F1512) : Colors.white,
    errorContainer: isDark
        ? const Color(0xFF4A1915)
        : const Color(0xFFFBE3E0),
    onErrorContainer: isDark
        ? const Color(0xFFFFDAD6)
        : const Color(0xFF410E0B),
    surface: card,
    onSurface: onSurface,
    surfaceContainerLowest: isDark ? const Color(0xFF181818) : Colors.white,
    surfaceContainerLow: isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF8F6F3),
    surfaceContainer: isDark
        ? const Color(0xFF222120)
        : const Color(0xFFF3F0EB),
    surfaceContainerHigh: isDark
        ? const Color(0xFF2A2927)
        : const Color(0xFFEEEAE4),
    surfaceContainerHighest: isDark
        ? const Color(0xFF35332F)
        : const Color(0xFFE9E5DE),
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
  );

  final textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: onSurface,
      height: 44 / 32,
      letterSpacing: -0.3,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: onSurface,
      height: 34 / 24,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: onSurface,
      height: 30 / 20,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: onSurface,
      height: 24 / 16,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: onSurface,
      height: 22 / 14,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: onSurface,
      height: 26 / 16,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: onSurfaceVariant,
      height: 22 / 14,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: onSurfaceVariant,
      height: 18 / 12,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: onSurface,
      height: 20 / 14,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: onSurface,
      height: 16 / 12,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: onSurfaceVariant,
      height: 16 / 11,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: scaffold,
    fontFamily: 'Vazirmatn',
    colorScheme: colorScheme,
    dividerColor: outlineVariant,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: scaffold,
      foregroundColor: onSurface,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF242322) : const Color(0xFFF6F4F1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      selectedColor: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
      labelStyle: textTheme.labelMedium,
    ),
  );
}
