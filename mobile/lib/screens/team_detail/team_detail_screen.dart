import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/team.dart';
import '../../models/view_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../viewmodels/team_detail_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/feedback.dart';
import '../shared/team_status.dart';

/// SCR_04 Team Detail + join dialog (Figma `SCR_04: Group Detail`, `SRC4 Diaglog`).
class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({super.key});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  /// Shown after the alternative path: the team filled up before we joined.
  String? _filledMessage;

  Future<void> _join(Team team) async {
    final vm = context.read<TeamDetailViewModel>();
    final me = vm.applicant;
    final ok = await showAppDialog(
      context,
      semanticId: 'dialog_join',
      icon: Icons.group_add,
      title: 'Join ${team.name}?',
      message: "You'll take ${vm.slotFor(team)}. You can leave from My Team until the roster is locked.",
      confirmLabel: 'Join Team',
      details: AppCard(
        color: context.colors.surfaceContainerHigh,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            MemberAvatar(initials: me.initials, avatarUrl: me.avatarUrl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(me.fullName, style: context.text.titleSmall),
                  Text(
                    '${me.studentCode} · ${me.preferredRoles.isEmpty ? 'Member' : me.preferredRoles.first}',
                    style: context.text.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!ok || !mounted) return;
    final outcome = await vm.join();
    if (!mounted) return;
    switch (outcome) {
      case Joined(:final team):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You joined ${team.name}')));
        context.go('/team');
      case TeamWasFull(:final team):
        setState(
          () => _filledMessage =
              'Another student took the last slot just before you. '
              '${team.name} now has ${team.memberCount} of ${team.capacity} members.',
        );
      case JoinFailed(:final failure):
        showFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TeamDetailViewModel>();
    final state = vm.state;
    final team = state is Data<Team> ? state.value : null;
    final blocked = team == null ? null : vm.joinBlockedReason(team);
    return BlockingOverlay(
      visible: vm.joining,
      message: 'Joining…',
      child: Scaffold(
        appBar: AppTopBar(title: team?.name ?? 'Team Details'),
        body: RefreshIndicator(
          onRefresh: vm.load,
          child: ListView(
            padding: AppSpacing.screen,
            children: [
              if (_filledMessage != null) ...[
                InfoBanner(
                  semanticId: 'banner_team_filled',
                  tone: Tone.error,
                  title: '${team?.name ?? 'This team'} just filled up',
                  message: _filledMessage,
                  action: AppButton(
                    semanticId: 'btn_back_to_browse',
                    label: 'Back to Browse',
                    variant: AppButtonVariant.secondary,
                    expand: false,
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              ViewStateView<Team>(
                state: state,
                onRetry: vm.load,
                loading: const LoadingState(message: 'Loading team…'),
                builder: (context, t) => _Body(team: t),
              ),
            ],
          ),
        ),
        bottomNavigationBar: team == null
            ? null
            : SafeArea(
                child: Material(
                  elevation: AppElevation.bar,
                  color: context.colors.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppButton(
                          semanticId: 'btn_join_team',
                          label: 'Join Team',
                          icon: Icons.group_add,
                          loading: vm.joining,
                          onPressed: blocked == null ? () => _join(team) : null,
                        ),
                        if (blocked != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Semantics(
                            identifier: 'join_blocked_reason',
                            child: Text(blocked, style: context.text.bodyMedium, textAlign: TextAlign.center),
                          ),
                          if (team.isMember(vm.applicant.id) && team.leaderId == vm.applicant.id && team.openSlots >= 1) ...[
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              semanticId: 'btn_seed_members_detail',
                              label: 'Seed 2 Members',
                              icon: Icons.person_add_alt_1_rounded,
                              variant: AppButtonVariant.secondary,
                              onPressed: () async {
                                final failure = await vm.seedMembers(count: 2);
                                if (!context.mounted) return;
                                if (failure != null) {
                                  showFailure(context, failure);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Seeded 2 members to ${team.name}!')),
                                  );
                                }
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final p = teamPhase(team);
    final progress = team.memberCount / team.capacity;
    final missing = TeamRules.minMembers - team.memberCount;
    // Figma SCR_04: header card, roster breakdown, open slots, assembly progress.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          semanticId: 'card_team_topic',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconTile(icon: Icons.groups, tone: Tone.warning, size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(team.code, style: context.text.titleSmall)),
                  Flexible(child: StatusBadge(label: p.label, tone: p.tone, icon: p.icon)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(team.topic, style: context.text.titleLarge),
              if (team.supervisor.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.school_outlined, size: AppSize.iconSmall, color: context.appColors.info),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Mentor: ${team.supervisor}',
                        style: context.text.labelMedium?.copyWith(color: context.appColors.info),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(team.description, style: context.text.bodyMedium),
              if (team.tags.isNotEmpty || team.category.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'CORE TECHNOLOGIES',
                  style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant, letterSpacing: 0.6),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (team.category.isNotEmpty) StatusBadge(label: team.category, tone: Tone.warning),
                    for (final tag in team.tags) StatusBadge(label: tag),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: 'Roster breakdown', trailing: '${team.capacity} total slots'),
        const SizedBox(height: AppSpacing.md),
        for (final m in team.members) ...[
          MemberTile(
            member: m,
            isLeader: team.hasLeader && m.studentId == team.leaderId,
            isMe: m.studentId == context.read<TeamDetailViewModel>().applicant.id,
            badges: [
              if (team.hasLeader && m.studentId == team.leaderId)
                const StatusBadge(label: 'Leader', tone: Tone.primary, icon: Icons.star)
              else
                const StatusBadge(label: 'Confirmed', tone: Tone.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (var i = 0; i < team.openSlots; i++) ...[
          OpenSlotTile(
            slot: team.memberCount + i + 1,
            lookingFor: i < team.openRoles.length ? team.openRoles[i] : 'Any role',
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Team assembly progress', style: context.text.titleSmall)),
                  Text(
                    '${(progress * 100).round()}%',
                    style: context.text.labelLarge?.copyWith(color: context.colors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadius.fullAll,
                child: LinearProgressIndicator(value: progress, minHeight: AppSize.progress),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: Text('${team.memberCount} members confirmed', style: context.text.bodySmall)),
                  Text(
                    missing > 0 ? '$missing more needed to lock' : 'Minimum size reached',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
