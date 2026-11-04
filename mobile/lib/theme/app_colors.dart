import 'package:flutter/material.dart';

/// Lab 2 colour tokens (`design/DESIGN.md` §2, green revision), matched to the
/// Figma *03 Final UI* frames: green primary actions, an orange-brown accent
/// for links and secondary actions, and peach containers for warnings.
///
/// Input/radio boundaries use #737980 instead of #E1E3E5 because the lighter
/// value fails WCAG AA (docs/design-traceability.md DV-10). The accent
/// #B4530A keeps 5.7:1 on white and 4.9:1 on its peach container.
abstract final class AppPalette {
  static const primary = Color(0xFF15803D); // white text 5.02:1
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFDCFCE7);
  static const onPrimaryContainer = Color(0xFF14532D); // 8.30:1 on container
  static const accent = Color(0xFFB4530A); // links, secondary buttons, Figma orange
  static const accentContainer = Color(0xFFFDE8DA);
  static const background = Color(0xFFF4F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F1F3);
  static const textPrimary = Color(0xFF1A1D1E);
  static const textSecondary = Color(0xFF596066);
  static const outline = Color(0xFF737980); // 4.40:1, UI boundary
  static const border = Color(0xFFE1E3E5); // decorative dividers only
  static const success = Color(0xFF0F766E);
  static const successContainer = Color(0xFFCCFBF1);
  static const warning = accent;
  static const warningContainer = accentContainer;
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFDF2F2);
  static const info = Color(0xFF1F5FA8);
  static const infoContainer = Color(0xFFE8F1FB);
  static const tag = Color(0xFFEDEFF2);
  static const onTag = Color(0xFF343A40);
  static const disabled = Color(0xFFE1E3E5);
  static const onDisabled = Color(0xFF5E6469);
  static const inverseSurface = Color(0xFF1A1D1E);
}

final ColorScheme appColorScheme = ColorScheme.fromSeed(seedColor: AppPalette.primary, brightness: Brightness.light)
    .copyWith(
      primary: AppPalette.primary,
      onPrimary: AppPalette.onPrimary,
      primaryContainer: AppPalette.primaryContainer,
      onPrimaryContainer: AppPalette.onPrimaryContainer,
      secondary: AppPalette.accent,
      onSecondary: AppPalette.onPrimary,
      secondaryContainer: AppPalette.accentContainer,
      onSecondaryContainer: AppPalette.accent,
      surface: AppPalette.background,
      onSurface: AppPalette.textPrimary,
      onSurfaceVariant: AppPalette.textSecondary,
      surfaceContainerLowest: AppPalette.surface,
      surfaceContainerLow: AppPalette.surface,
      surfaceContainer: AppPalette.surface,
      surfaceContainerHigh: AppPalette.surfaceVariant,
      surfaceContainerHighest: AppPalette.surfaceVariant,
      outline: AppPalette.outline,
      outlineVariant: AppPalette.border,
      error: AppPalette.error,
      onError: AppPalette.onPrimary,
      errorContainer: AppPalette.errorContainer,
      onErrorContainer: AppPalette.error,
      inverseSurface: AppPalette.inverseSurface,
      onInverseSurface: AppPalette.onPrimary,
      inversePrimary: AppPalette.primaryContainer,
    );

/// Status colours that have no slot in [ColorScheme].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.tag,
    required this.onTag,
    required this.disabled,
    required this.onDisabled,
    required this.skeleton,
  });

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;
  final Color tag;
  final Color onTag;
  final Color disabled;
  final Color onDisabled;
  final Color skeleton;

  static const light = AppColors(
    success: AppPalette.success,
    successContainer: AppPalette.successContainer,
    warning: AppPalette.warning,
    warningContainer: AppPalette.warningContainer,
    info: AppPalette.info,
    infoContainer: AppPalette.infoContainer,
    tag: AppPalette.tag,
    onTag: AppPalette.onTag,
    disabled: AppPalette.disabled,
    onDisabled: AppPalette.onDisabled,
    skeleton: AppPalette.tag,
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? tag,
    Color? onTag,
    Color? disabled,
    Color? onDisabled,
    Color? skeleton,
  }) {
    return AppColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      tag: tag ?? this.tag,
      onTag: onTag ?? this.onTag,
      disabled: disabled ?? this.disabled,
      onDisabled: onDisabled ?? this.onDisabled,
      skeleton: skeleton ?? this.skeleton,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      tag: Color.lerp(tag, other.tag, t)!,
      onTag: Color.lerp(onTag, other.onTag, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      onDisabled: Color.lerp(onDisabled, other.onDisabled, t)!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
