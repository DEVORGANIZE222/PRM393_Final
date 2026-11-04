import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppButtonVariant { primary, secondary, destructive, text }

/// Lab 2 *Button*: Type × State (default, pressed, disabled, loading).
///
/// Pressed is the Material ink state; disabled is `onPressed == null`;
/// loading shows a spinner, keeps the label and blocks taps.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.semanticId,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  /// Stable id exposed to the accessibility tree (Android resource-id) for E2E tests.
  final String? semanticId;

  /// Optional custom background color to create high-visibility accent buttons.
  final Color? backgroundColor;

  /// Optional custom foreground/text color.
  final Color? foregroundColor;

  /// Optional custom border color.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final callback = loading ? null : onPressed;
    final fg = foregroundColor ??
        switch (variant) {
          AppButtonVariant.primary || AppButtonVariant.destructive => colors.onPrimary,
          AppButtonVariant.secondary => const Color(0xFF0F172A),
          AppButtonVariant.text => colors.primary,
        };

    final iconColor = callback == null
        ? null
        : (variant == AppButtonVariant.secondary ? colors.primary : fg);

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: variant == AppButtonVariant.primary || variant == AppButtonVariant.destructive
                    ? colors.onPrimary
                    : colors.primary,
              ),
            ),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1)),
      ],
    );

    final Widget button = backgroundColor != null
        ? FilledButton(
            onPressed: callback,
            style: FilledButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: fg,
              side: borderColor != null ? BorderSide(color: borderColor!, width: 1.5) : null,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
            ),
            child: content,
          )
        : switch (variant) {
            AppButtonVariant.primary => FilledButton(onPressed: callback, child: content),
            AppButtonVariant.destructive => FilledButton(
                onPressed: callback,
                style: FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError),
                child: content,
              ),
            AppButtonVariant.secondary => OutlinedButton(
                onPressed: callback,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: fg,
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  elevation: 1,
                  shadowColor: Colors.black.withValues(alpha: 0.04),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: AppSpacing.lg),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
                ),
                child: content,
              ),
            AppButtonVariant.text => TextButton(onPressed: callback, child: content),
          };

    return Semantics(
      identifier: semanticId,
      button: true,
      enabled: callback != null,
      label: loading ? '$label, in progress' : null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
