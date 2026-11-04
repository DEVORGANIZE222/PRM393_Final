import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification.dart';
import '../../models/view_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/notifications_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/feedback.dart';
import '../shared/profile_action.dart';
import '../shared/team_status.dart';

/// SCR_02 Dashboard (Figma `SCR_02: Dashboard / Home`).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    return Scaffold(
      appBar: const AppTopBar(title: 'Home', showBack: false, actions: [ProfileAction()]),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          padding: AppSpacing.screen,
          children: [
            ViewStateView<DashboardData>(
              state: vm.state,
              onRetry: vm.load,
              builder: (context, d) => _DashboardBody(data: d),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final team = data.team;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('Hi, ${data.student.firstName}! 👋', style: context.text.headlineMedium)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [data.student.studentCode, data.student.major].where((s) => s.isNotEmpty).join(' · '),
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (data.registrationClosed)
          InfoBanner(
            semanticId: 'banner_registration_closed',
            tone: Tone.error,
            title: 'Registration is closed',
            message: team == null
                ? 'You were not in a team at the deadline, so the system placed you in the Random Pool.'
                : 'Changes to ${team.name} now go through the Academic Office.',
          )
        else ...[
          // Figma: peach deadline panel, green/red countdown and progress bar.
          Builder(
            builder: (context) {
              final remainingFraction = (1.0 - data.window.elapsed(data.now)).clamp(0.0, 1.0);
              final isUrgent = data.urgent || remainingFraction < 0.15;
              final accentColor = isUrgent ? context.colors.error : context.colors.primary;
              return AppCard(
                semanticId: 'card_deadline',
                color: isUrgent ? const Color(0xFFFEF2F2) : context.appColors.warningContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 20,
                          color: isUrgent ? context.colors.error : context.appColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            isUrgent ? 'Registration deadline closing soon!' : 'Registration deadline',
                            style: context.text.titleSmall?.copyWith(
                              color: isUrgent ? context.colors.error : context.appColors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isUrgent) const StatusBadge(label: 'Urgent', tone: Tone.error),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      Fmt.countdown(data.timeLeft),
                      style: context.text.headlineLarge?.copyWith(color: accentColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('System locks on ${Fmt.dateTime(data.window.closesAt)}', style: context.text.bodyMedium),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${data.window.semester} Timeline',
                          style: context.text.labelMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isUrgent ? Icons.warning_amber_rounded : Icons.hourglass_bottom,
                                size: 12,
                                color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(remainingFraction * 100).round()}% time left',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      label: 'Registration period',
                      value: '${(remainingFraction * 100).round()} percent remaining',
                      excludeSemantics: true,
                      child: ClipRRect(
                        borderRadius: AppRadius.fullAll,
                        child: LinearProgressIndicator(
                          value: remainingFraction,
                          minHeight: AppSize.progress,
                          color: accentColor,
                          backgroundColor: isUrgent ? const Color(0xFFFEE2E2) : context.colors.surfaceContainerLowest,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        if (data.registrationClosed && data.showPoolEntry && team == null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            semanticId: 'btn_view_matching_status',
            label: 'View Matching Status',
            icon: Icons.hourglass_top,
            onPressed: () => context.push('/home/pool'),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (team == null) ...[
          const SectionHeader(title: 'My team'),
          const SizedBox(height: AppSpacing.md),
          _NoTeamCard(closed: data.registrationClosed),
        ] else ...[
          TeamStatusCard(team: team),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (!data.registrationClosed) ...[
          if (team == null) ...[
            AppButton(
              semanticId: 'btn_browse_teams',
              label: 'Browse Available Teams',
              icon: Icons.search,
              onPressed: () => context.go('/browse'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              semanticId: 'btn_create_team_home',
              label: 'Create a New Team',
              icon: Icons.group_add,
              backgroundColor: const Color(0xFFFFF7ED),
              foregroundColor: const Color(0xFFC2410C),
              borderColor: const Color(0xFFF97316),
              onPressed: () => context.push('/create-team'),
            ),
          ]
          else ...[
            AppButton(
              semanticId: 'btn_manage_team',
              label: 'Manage ${team.name}',
              icon: Icons.groups,
              onPressed: () => context.go('/team'),
            ),
            if (team.locked && team.leaderId == data.student.id) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                semanticId: 'btn_unlock_team_home',
                label: 'Unlock ${team.name} (Recovery)',
                icon: Icons.lock_open_rounded,
                backgroundColor: const Color(0xFFFEF2F2),
                foregroundColor: const Color(0xFFDC2626),
                borderColor: const Color(0xFFFCA5A5),
                onPressed: () async {
                  final ok = await showAppDialog(
                    context,
                    semanticId: 'dialog_unlock_team',
                    icon: Icons.lock_open_rounded,
                    title: 'Unlock ${team.name}?',
                    message: 'Unlocking allows you to add or modify team members again.',
                    confirmLabel: 'Unlock Team',
                  );
                  if (ok && context.mounted) {
                    final failure = await context.read<DashboardViewModel>().unlockTeam(team);
                    if (context.mounted) {
                      if (failure != null) {
                        showFailure(context, failure);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${team.name} unlocked successfully!')),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ],
        ],
        const SizedBox(height: AppSpacing.xl),
        const _RecentNotices(),
      ],
    );
  }
}

class _NoTeamCard extends StatelessWidget {
  const _NoTeamCard({required this.closed});

  final bool closed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticId: 'card_no_team',
      child: Row(
        children: [
          const IconTile(icon: Icons.group_add, tone: Tone.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("You're not in a team yet", style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  closed
                      ? 'The Random Pool will place you in a team. Check your matching status for updates.'
                      : 'Teams with open slots are waiting. Join one before the deadline.',
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentNotices extends StatelessWidget {
  const _RecentNotices();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationsViewModel>().state;
    final items = switch (state) {
      Data<List<AppNotification>>(:final value) => value.take(2).toList(),
      _ => const <AppNotification>[],
    };
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Recent notices')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: context.colors.secondary),
              onPressed: () => context.go('/alerts'),
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final n in items) ...[
          AppCard(
            onTap: () => context.go('/alerts'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                  icon: notificationIcon(n.kind),
                  tone: n.kind == NotificationKind.invite ? Tone.warning : Tone.success,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title, style: context.text.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.xs),
                      Text(Fmt.ago(n.createdAt, DateTime.now()), style: context.text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
