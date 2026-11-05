import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/mentor.dart';
import '../../models/team.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../viewmodels/my_team_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/profile_action.dart';
import '../shared/feedback.dart';
import '../shared/team_status.dart';

/// SCR_05 My Team (Figma `SCR_05: My Group Hub` and `SCR_05 (Leader View - Ready to Lock)`).
class MyTeamScreen extends StatelessWidget {
  const MyTeamScreen({super.key});

  Future<void> _leave(BuildContext context, Team team) async {
    final vm = context.read<MyTeamViewModel>();
    final ok = await showAppDialog(
      context,
      semanticId: 'dialog_leave',
      destructive: true,
      title: 'Leave ${team.name}?',
      message:
          'Your slot opens for other students and your vote is removed. '
          'You can join again only if a slot is still open.',
      confirmLabel: 'Leave Team',
    );
    if (!ok || !context.mounted) return;
    final failure = await vm.leave(team);
    if (!context.mounted) return;
    if (failure != null) return showFailure(context, failure);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You left ${team.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MyTeamViewModel>();
    return BlockingOverlay(
      visible: vm.leaving,
      message: 'Leaving team…',
      child: Scaffold(
        appBar: const AppTopBar(title: 'My Team', showBack: false, actions: [ProfileAction()]),
        body: RefreshIndicator(
          onRefresh: vm.load,
          child: ListView(
            padding: AppSpacing.screen,
            children: [
              ViewStateView<Team>(
                state: vm.state,
                onRetry: vm.load,
                empty: const NoTeamState(),
                builder: (context, team) => _Body(team: team, onLeave: () => _leave(context, team)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.team, required this.onLeave});

  final Team team;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<MyTeamViewModel>();
    final phase = vm.phaseOf(team);
    final p = teamPhase(team);
    final leader = vm.isLeader(team);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          semanticId: 'card_my_team_header',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Figma SCR_05 hub header: overline, name + code, join progress.
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: context.colors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'ACTIVE TEAM HUB',
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Flexible(child: StatusBadge(label: p.label, tone: p.tone, icon: p.icon)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(header: true, child: Text(team.name, style: context.text.headlineMedium)),
              const SizedBox(height: AppSpacing.xs),
              StatusBadge(label: team.code, icon: Icons.tag),
              const SizedBox(height: AppSpacing.sm),
              Text(team.topic, style: context.text.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${team.memberCount} of ${team.capacity} members joined',
                      style: context.text.labelLarge,
                    ),
                  ),
                  Text(
                    '${(team.memberCount * 100 / team.capacity).round()}%',
                    style: context.text.labelLarge?.copyWith(color: context.colors.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                label: '${team.memberCount} of ${team.capacity} members joined',
                excludeSemantics: true,
                child: ClipRRect(
                  borderRadius: AppRadius.fullAll,
                  child: LinearProgressIndicator(
                    value: team.memberCount / team.capacity,
                    minHeight: AppSize.progress,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Steps(phase: phase),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _PhaseBanner(team: team, phase: phase, isLeader: leader, hasVoted: vm.hasVoted(team)),
        if (phase == TeamPhase.locked && leader) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            semanticId: 'btn_unlock_team_my_team',
            label: 'Unlock Roster (Recovery)',
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
                final failure = await vm.unlock(team);
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
        if (phase != TeamPhase.locked) ...[
          const SizedBox(height: AppSpacing.lg),
          if (phase == TeamPhase.electLeader || !vm.hasVoted(team))
            AppButton(
              semanticId: 'btn_vote_leader',
              label: vm.hasVoted(team) ? 'Change Vote' : 'Vote for Leader',
              icon: Icons.how_to_vote,
              variant: (!vm.hasVoted(team) || phase == TeamPhase.electLeader)
                  ? AppButtonVariant.primary
                  : AppButtonVariant.secondary,
              onPressed: () => context.push('/team/vote'),
            ),
          if (phase != TeamPhase.electLeader) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              semanticId: 'btn_review_lock',
              label: 'Review & Lock',
              icon: Icons.fact_check,
              variant: (leader && vm.hasVoted(team))
                  ? AppButtonVariant.primary
                  : AppButtonVariant.secondary,
              onPressed: () => context.push('/team/lock'),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SectionHeader(title: 'Members', trailing: '${team.memberCount} of ${team.capacity}'),
            ),
            if (team.openSlots >= 2) ...[
              TextButton.icon(
                onPressed: () async {
                  final failure = await vm.seedMembers(team, count: 2);
                  if (context.mounted && failure != null) {
                    showFailure(context, failure);
                  }
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Seed 2 Members', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final m in team.members) ...[
          MemberTile(
            member: m,
            isLeader: team.hasLeader && m.studentId == team.leaderId,
            isMe: m.studentId == vm.myId,
            badges: [
              if (m.studentId == vm.myId) const StatusBadge(label: 'You', tone: Tone.info, icon: Icons.person),
              if (team.hasLeader && m.studentId == team.leaderId)
                const StatusBadge(label: 'Leader', tone: Tone.primary, icon: Icons.star),
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
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Mentor'),
        const SizedBox(height: AppSpacing.md),
        _MentorCard(team: team, request: context.watch<MyTeamViewModel>().mentorRequest),
        const SizedBox(height: AppSpacing.lg),
        if (phase != TeamPhase.locked) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            semanticId: 'btn_leave_team',
            label: 'Leave Team',
            icon: Icons.logout,
            variant: AppButtonVariant.destructive,
            onPressed: onLeave,
          ),
        ],
      ],
    );
  }
}

/// The team's mentor, or where choosing one stands. Opens the mentor's profile
/// when there is one to look at, otherwise the directory.
class _MentorCard extends StatelessWidget {
  const _MentorCard({required this.team, required this.request});

  final Team team;
  final MentorRequest? request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final (String title, String detail, StatusBadge? badge) = switch (r) {
      _ when team.hasMentor => (team.supervisor, 'Your team\'s mentor', null),
      MentorRequest(isPending: true) => (
        r.mentorName,
        'Waiting for a reply',
        const StatusBadge(label: 'Pending', tone: Tone.warning),
      ),
      MentorRequest(isRejected: true) => (
        'Choose another mentor',
        '${r.mentorName} declined'
            '${(r.decisionReason ?? '').isEmpty ? '' : ': ${r.decisionReason}'}',
        const StatusBadge(label: 'Declined', tone: Tone.error),
      ),
      _ => ('No mentor yet', 'Browse lecturers and send a request', null),
    };
    final mentorId = team.mentorId ?? (r != null && r.isPending ? r.mentorId : null);
    return AppCard(
      semanticId: 'card_team_mentor',
      onTap: () => context.push(mentorId == null ? '/mentors' : '/mentors/$mentorId'),
      child: Row(
        children: [
          const IconTile(icon: Icons.school_outlined, tone: Tone.primary, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(detail, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
          ),
          if (badge != null) ...[const SizedBox(width: AppSpacing.sm), badge],
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// Three-step progress (Form → Elect → Lock) so the next step is always visible.
class _Steps extends StatelessWidget {
  const _Steps({required this.phase});

  final TeamPhase phase;

  @override
  Widget build(BuildContext context) {
    final done = switch (phase) {
      TeamPhase.electLeader => 0,
      TeamPhase.inFormation => 1,
      TeamPhase.readyToLock => 2,
      TeamPhase.locked => 3,
    };
    const labels = ['Elect leader', '4+ members', 'Lock roster'];
    return Semantics(
      label: 'Step ${done.clamp(0, 2) + 1} of 3: ${labels[done.clamp(0, 2)]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Column(
                children: [
                  Icon(
                    i < done ? Icons.check_circle : (i == done ? Icons.radio_button_checked : Icons.circle_outlined),
                    color: i < done
                        ? context.appColors.success
                        : (i == done ? context.colors.primary : context.colors.outline),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(labels[i], style: context.text.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({required this.team, required this.phase, required this.isLeader, required this.hasVoted});

  final Team team;
  final TeamPhase phase;
  final bool isLeader;
  final bool hasVoted;

  @override
  Widget build(BuildContext context) {
    final voted = team.votes.length;
    return switch (phase) {
      TeamPhase.electLeader => InfoBanner(
        semanticId: 'banner_phase',
        tone: Tone.warning,
        icon: Icons.how_to_vote,
        title: hasVoted ? 'Waiting for more votes' : 'Vote for your team leader',
        message:
            '$voted of ${team.memberCount} members have voted. '
            'A leader needs ${team.votesNeeded} votes.',
      ),
      TeamPhase.inFormation => InfoBanner(
        semanticId: 'banner_phase',
        tone: Tone.warning,
        icon: Icons.group_add,
        title: 'Needs ${Fmt.count(TeamRules.minMembers - team.memberCount, 'more member')} to lock',
        message: isLeader
            ? 'Invite students from the Waiting Pool on Review & Lock.'
            : '${team.leader!.fullName}, your leader, can invite students from the Waiting Pool.',
      ),
      TeamPhase.readyToLock => InfoBanner(
        semanticId: 'banner_phase',
        tone: Tone.success,
        title: 'Ready to lock',
        message: isLeader
            ? 'Review the roster and lock it to send it to the Academic Office.'
            : 'Waiting for ${team.leader!.fullName} to lock the roster.',
      ),
      TeamPhase.locked => InfoBanner(
        semanticId: 'banner_phase',
        tone: Tone.success,
        icon: Icons.lock,
        title: 'Roster locked · ${team.lockCode}',
        message:
            'Sent to the Academic Office'
            '${team.lockedAt == null ? '' : ' on ${Fmt.dateTime(team.lockedAt!)}'}. '
            'Contact them to change your team.',
      ),
    };
  }
}
