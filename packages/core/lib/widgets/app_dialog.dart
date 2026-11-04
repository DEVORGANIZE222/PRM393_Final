import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';

/// Lab 2 *Dialog*: confirmation and destructive. Buttons are stacked full width,
/// confirm first, so long labels never truncate at 360 dp (Lab 2 decision D9).
/// Figma `SRC4 Diaglog`: icon in a tinted circle, centred title and message,
/// details in a grey panel, white outlined Cancel.
/// Returns `true` when the user confirms.
Future<bool> showAppDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
  Widget? details,
  String? semanticId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final c = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: destructive ? c.errorContainer : context.appColors.warningContainer,
          ),
          child: Icon(
            icon ?? (destructive ? Icons.warning_amber_rounded : Icons.info_outline),
            color: destructive ? c.error : context.appColors.warning,
          ),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (details != null) ...[const SizedBox(height: AppSpacing.lg), details],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: confirmLabel,
                semanticId: semanticId == null ? null : '${semanticId}_confirm',
                variant: destructive ? AppButtonVariant.destructive : AppButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                identifier: semanticId == null ? null : '${semanticId}_cancel',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: c.surfaceContainerLowest,
                      foregroundColor: c.onSurface,
                      side: BorderSide(color: c.outlineVariant),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(cancelLabel),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}
