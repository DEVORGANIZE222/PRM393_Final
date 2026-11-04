import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Lab 2 type scale (`DESIGN.md` §2), tightened to the sizes measured on the
/// Figma *03 Final UI* frames. Roboto is the platform font on Android, which
/// the brief allows ("Inter or Roboto"), so no font asset is bundled.
TextTheme _textTheme(ColorScheme c) {
  TextStyle s(double size, double height, FontWeight weight, [Color? color]) => TextStyle(
    fontSize: size,
    height: height / size,
    fontWeight: weight,
    color: color ?? c.onSurface,
    letterSpacing: 0,
  );
  return TextTheme(
    headlineLarge: s(26, 32, FontWeight.w700), // hero numbers (deadline countdown)
    headlineMedium: s(24, 30, FontWeight.w700), // type-display (greeting, brand)
    titleLarge: s(20, 26, FontWeight.w700), // type-headline (screen / app bar title)
    titleMedium: s(17, 24, FontWeight.w700), // type-title (card heading, section)
    titleSmall: s(15, 22, FontWeight.w600), // card name
    bodyLarge: s(15, 22, FontWeight.w400),
    bodyMedium: s(14, 20, FontWeight.w400), // type-body
    labelLarge: s(14, 20, FontWeight.w600), // type-label (buttons, chips)
    labelMedium: s(13, 18, FontWeight.w500, c.onSurfaceVariant),
    labelSmall: s(12, 16, FontWeight.w600), // badges, overlines
    bodySmall: s(12, 16, FontWeight.w400, c.onSurfaceVariant), // type-caption (timestamps only)
  );
}

ThemeData buildAppTheme() {
  final c = appColorScheme;
  final t = _textTheme(c);
  const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.buttonAll);
  const minButton = Size(AppSize.touchTarget, AppSize.button);

  return ThemeData(
    useMaterial3: true,
    colorScheme: c,
    textTheme: t,
    scaffoldBackgroundColor: c.surface,
    shadowColor: const Color(0x14101828),
    extensions: const [AppColors.light],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: c.surfaceContainerLowest,
      foregroundColor: c.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.none,
      scrolledUnderElevation: AppElevation.card,
      centerTitle: false,
      toolbarHeight: AppSize.appBar,
      titleTextStyle: t.titleLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minButton,
        shape: buttonShape,
        textStyle: t.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        disabledBackgroundColor: AppPalette.disabled,
        disabledForegroundColor: AppPalette.onDisabled,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minButton,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
        textStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        disabledBackgroundColor: AppPalette.disabled,
        disabledForegroundColor: AppPalette.onDisabled,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minButton,
        shape: buttonShape,
        textStyle: t.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size.square(AppSize.touchTarget)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: c.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: c.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: c.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: c.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: c.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: c.outlineVariant),
      ),
      labelStyle: t.labelLarge,
      helperStyle: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
      errorStyle: t.bodyMedium?.copyWith(color: c.error),
      hintStyle: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      color: c.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.none,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: AppSize.navBar,
      backgroundColor: c.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      // Figma: no indicator pill; the selected tab is green, bold and uses the
      // filled icon, so selection is not shown by colour alone.
      indicatorColor: Colors.transparent,
      shadowColor: const Color(0x1F101828),
      elevation: AppElevation.bar,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => t.labelSmall?.copyWith(
          color: s.contains(WidgetState.selected) ? c.primary : c.onSurfaceVariant,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.primary : c.onSurfaceVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.dialog,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      titleTextStyle: t.titleLarge,
      contentTextStyle: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: c.outlineVariant),
      selectedColor: c.primaryContainer,
      backgroundColor: c.surfaceContainerLowest,
      labelStyle: t.labelLarge,
      checkmarkColor: c.onPrimaryContainer,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.inverseSurface,
      contentTextStyle: t.bodyMedium?.copyWith(color: c.onInverseSurface),
      actionTextColor: c.inversePrimary,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: AppPalette.tag,
      linearMinHeight: AppSize.progress,
    ),
    dividerTheme: DividerThemeData(color: c.outlineVariant, space: AppSpacing.lg),
  );
}
