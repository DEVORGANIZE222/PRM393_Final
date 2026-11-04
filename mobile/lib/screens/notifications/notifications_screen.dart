import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification.dart';
import '../../models/view_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../viewmodels/notifications_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/feedback.dart';
import '../shared/team_status.dart';

/// SCR_09 Alerts (Figma `SCR_09: Notifications & Invites`).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _filterLabels = {AlertFilter.all: 'All', AlertFilter.invites: 'Invites', AlertFilter.system: 'Updates'};

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    return Scaffold(
      appBar: AppTopBar(
        title: 'Alerts',
        showBack: true,
        actions: [
          if (vm.unread > 0)
            Semantics(
              identifier: 'btn_mark_all_read',
              child: TextButton(
                onPressed: () async {
                  final failure = await vm.markAllRead();
                  if (failure != null && context.mounted) showFailure(context, failure);
                },
                child: const Text('Mark All Read'),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          Semantics(
            identifier: 'alert_filters',
            container: true,
            // Figma SCR_09: pill filters, the selected one solid green.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in AlertFilter.values) ...[
                    ChoiceChip(
                      label: Text('${_filterLabels[f]} (${vm.count(f)})'),
                      selected: vm.filter == f,
                      showCheckmark: false,
                      onSelected: (_) => vm.setFilter(f),
                      selectedColor: context.colors.primary,
                      backgroundColor: context.colors.surfaceContainerHigh,
                      side: vm.filter == f
                          ? BorderSide.none
                          : const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                      labelStyle: context.text.labelLarge?.copyWith(
                        color: vm.filter == f ? context.colors.onPrimary : context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ViewStateView<List<AppNotification>>(
            state: vm.state,
            onRetry: vm.start,
            empty: EmptyState(
              icon: Icons.notifications_none,
              title: "You're all caught up",
              message: vm.filter == AlertFilter.invites
                  ? 'Team invites will show up here.'
                  : 'Votes, invites and deadline reminders will show up here.',
            ),
            builder: (context, items) => Column(
              children: [
                for (final n in items) ...[_NotificationCard(item: n), const SizedBox(height: AppSpacing.md)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final AppNotification item;

  Future<void> _decline(BuildContext context) async {
    // The Firestore stream removes the declined invite at once, which disposes
    // this card. Everything after the await therefore goes through the
    // screen-level messenger, never this card's (by then unmounted) context;
    // checking context.mounted here used to skip the Undo snackbar entirely.
    final vm = context.read<NotificationsViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    void report(AppFailure f) => messenger.showSnackBar(SnackBar(content: Text('${f.title}. ${f.cause}')));
    final failure = await vm.decline(item);
    if (failure != null) return report(failure);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Invite declined'),
        // Long enough to find and press Undo (WCAG 2.2.1), not the default 4 s.
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final undoFailure = await vm.restore(item);
            if (undoFailure != null) report(undoFailure);
          },
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    final vm = context.read<NotificationsViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final failure = await vm.accept(item);
    if (!context.mounted) return;
    if (failure != null) return showFailure(context, failure);
    messenger.showSnackBar(const SnackBar(content: Text('Invite accepted. Welcome to your new team')));
    context.go('/team');
  }

  void _open(BuildContext context) {
    context.read<NotificationsViewModel>().open(item);
    if (item.teamId == null) return;
    switch (item.kind) {
      case NotificationKind.vote:
        context.push('/team/vote');
      case NotificationKind.application:
        context.push('/team/lock');
      case NotificationKind.invite:
        context.push('/browse/team/${item.teamId}');
      case NotificationKind.system:
        // FCM campaign messages are persisted as `system` unless their
        // payload explicitly supplies another kind. A teamId must still open
        // the corresponding detail screen when the student taps the inbox
        // item, just like a system notification opened from Android.
        context.push('/browse/team/${item.teamId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (kindLabel, kindTone) = switch (item.kind) {
      NotificationKind.invite => ('Team invitation', Tone.warning),
      NotificationKind.vote => ('Vote update', Tone.info),
      NotificationKind.system => ('System alert', Tone.error),
      NotificationKind.application => ('Application status', Tone.primary),
    };
    return AppCard(
      semanticId: 'alert_${item.id}',
      semanticLabel: '${item.read ? '' : 'Unread. '}${item.title}',
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(label: kindLabel, tone: kindTone),
              if (!item.read) ...[
                const SizedBox(width: AppSpacing.xs),
                const StatusBadge(label: 'New', tone: Tone.primary),
              ],
              const Spacer(),
              Text(Fmt.ago(item.createdAt, DateTime.now()), style: context.text.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: notificationIcon(item.kind), tone: kindTone),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: context.text.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(item.body, style: context.text.bodyMedium),
                    // Aligned with the text column, not the card edge.
                    if (!item.isInvite && item.actionLabel != null && item.teamId != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.secondary,
                          padding: EdgeInsets.zero,
                        ),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: Text(item.actionLabel!),
                        onPressed: () => _open(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (item.isInvite) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    semanticId: 'btn_accept_${item.id}',
                    label: 'Accept',
                    icon: Icons.check_circle_outline,
                    onPressed: () => _accept(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    semanticId: 'btn_decline_${item.id}',
                    label: 'Decline',
                    icon: Icons.close,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _decline(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
