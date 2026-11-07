import 'package:flutter/material.dart';

/// Web-only visual system. It mirrors the reference EXEMatching portal without
/// changing the shared mobile theme in packages/core.
abstract final class AdminPalette {
  static const page = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFF1F5F9);
  static const hover = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF475569);
  static const slate400 = Color(0xFF94A3B8);
  static const primary = Color(0xFF15803D);
  static const primaryDark = Color(0xFF166534);
  static const primaryLight = Color(0xFFDCFCE7);
  static const primaryBorder = Color(0xFFBBF7D0);
  static const teal = Color(0xFF0F766E);
  static const tealLight = Color(0xFFCCFBF1);
  static const warning = Color(0xFFB45309);
  static const warningLight = Color(0xFFFEF3C7);
  static const danger = Color(0xFFBA1A1A);
  static const dangerLight = Color(0xFFFEE2E2);
}

ThemeData buildAdminTheme() {
  const scheme = ColorScheme.light(
    primary: AdminPalette.primary,
    onPrimary: Colors.white,
    primaryContainer: AdminPalette.primaryLight,
    onPrimaryContainer: AdminPalette.primaryDark,
    surface: AdminPalette.surface,
    onSurface: AdminPalette.ink,
    onSurfaceVariant: AdminPalette.muted,
    outline: AdminPalette.border,
    error: AdminPalette.danger,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Inter');
  return base.copyWith(
    scaffoldBackgroundColor: AdminPalette.page,
    appBarTheme: const AppBarTheme(
      backgroundColor: AdminPalette.surface,
      foregroundColor: AdminPalette.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: AdminPalette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        side: BorderSide(color: AdminPalette.border),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AdminPalette.surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: AdminPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: AdminPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        borderSide: BorderSide(color: AdminPalette.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AdminPalette.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 44),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AdminPalette.primary, minimumSize: const Size(44, 44)),
    ),
    dividerTheme: const DividerThemeData(color: AdminPalette.border),
  );
}
