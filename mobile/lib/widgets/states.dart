import 'package:flutter/material.dart';

import '../models/view_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';

/// Lab 2 *Loading · Spinner*.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'state_loading',
      liveRegion: true,
      label: message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(message, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lab 2 *Loading · Skeleton*: one mechanism for list screens.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    final bone = context.appColors.skeleton;
    Widget bar(double width) => Container(
      height: AppSpacing.md,
      width: width,
      decoration: BoxDecoration(color: bone, borderRadius: AppRadius.fullAll),
    );
    return Semantics(
      identifier: 'state_loading',
      label: 'Loading',
      liveRegion: true,
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(color: context.colors.surfaceContainerLowest, borderRadius: AppRadius.mdAll),
                child: Row(
                  children: [
                    CircleAvatar(radius: AppSize.avatar / 2, backgroundColor: bone),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(double.infinity),
                          const SizedBox(height: AppSpacing.sm),
                          bar(120),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lab 2 *Empty state*: icon, title, message, one action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      identifier: 'state_empty',
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: AppSize.illustration / 2,
              backgroundColor: c.primaryContainer,
              child: Icon(icon, size: 48, color: c.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: actionLabel!, onPressed: onAction, semanticId: 'empty_action'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lab 2 *Error state*: what happened, the cause in plain language, retry.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.failure, this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      identifier: 'state_error',
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: AppSize.illustration / 2,
              backgroundColor: c.errorContainer,
              child: Icon(failure.code == 'offline' ? Icons.cloud_off : Icons.error_outline, size: 48, color: c.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(failure.title, style: context.text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              failure.cause,
              style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (failure.retryable && onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Try Again', icon: Icons.refresh, onPressed: onRetry, semanticId: 'error_retry'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lab 2 *Loading · Overlay*: blocks input during an irreversible action.
class BlockingOverlay extends StatelessWidget {
  const BlockingOverlay({super.key, required this.visible, required this.message, required this.child});

  final bool visible;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: ColoredBox(
              color: context.colors.scrim.withValues(alpha: 0.5),
              child: Center(
                // A compact card over the dimmed screen, so the user keeps context.
                child: Semantics(
                  identifier: 'state_blocking',
                  liveRegion: true,
                  label: message,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: AppSpacing.lg),
                          Text(message, style: context.text.bodyLarge),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Renders a [ViewState] with the shared loading / empty / error treatments,
/// so every data screen uses one mechanism (UI consistency checklist).
class ViewStateView<T> extends StatelessWidget {
  const ViewStateView({
    super.key,
    required this.state,
    required this.builder,
    required this.onRetry,
    this.empty,
    this.loading,
  });

  final ViewState<T> state;
  final Widget Function(BuildContext context, T value) builder;
  final VoidCallback onRetry;
  final Widget? empty;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      Loading<T>() => loading ?? const SkeletonList(),
      Empty<T>() => empty ?? const EmptyState(title: 'Nothing here yet', message: 'New items will show up here.'),
      Failure<T>(:final failure) => ErrorState(failure: failure, onRetry: onRetry),
      Data<T>(:final value) => builder(context, value),
    };
  }
}
