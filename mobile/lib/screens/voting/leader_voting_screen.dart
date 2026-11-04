import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/team.dart';
import '../../models/view_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../viewmodels/voting_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/feedback.dart';

/// SCR_06 Leader Voting (Figma `SCR_06: Leader Voting`), Flow 2.
class LeaderVotingScreen extends StatelessWidget {
  const LeaderVotingScreen({super.key});

  Future<void> _submit(BuildContext context, Team team) async {
    final vm = context.read<VotingViewModel>();
    final candidate = team.members.firstWhere((m) => m.studentId == vm.selected);
    if (vm.isChange(team)) {
      final previous = team.members.firstWhere((m) => m.studentId == vm.myVote(team));
      final ok = await showAppDialog(
        context,
        semanticId: 'dialog_change_vote',
        icon: Icons.swap_horiz,
        title: 'Change your vote?',
        message: 'Your vote moves from ${previous.fullName} to ${candidate.fullName}.',
        confirmLabel: 'Change Vote',
      );
      if (!ok || !context.mounted) return;
    }
    final result = await vm.submit();
    if (!context.mounted) return;
    if (result.failure != null) return showFailure(context, result.failure!);
    final messenger = ScaffoldMessenger.of(context);
    final updated = result.team!;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          updated.hasLeader && updated.leaderId == candidate.studentId
              ? '${candidate.fullName} is now your team leader'
              : 'Vote saved for ${candidate.fullName}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VotingViewModel>();
    final state = vm.state;
    final team = state is Data<Team> ? state.value : null;
    return Scaffold(
      appBar: const AppTopBar(title: 'Vote for Leader'),
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          ViewStateView<Team>(
            state: state,
            onRetry: vm.load,
            empty: const NoTeamState(message: 'Join a team first. Then you can vote for its leader.'),
            builder: (context, t) => _Body(team: t),
          ),
        ],
      ),
      bottomNavigationBar: team == null || team.locked
          ? null
          : SafeArea(
              child: Material(
                elevation: AppElevation.bar,
                color: context.colors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppButton(
                        semanticId: 'btn_submit_vote',
                        label: vm.myVote(team) == null ? 'Submit Vote' : 'Change Vote',
                        icon: Icons.how_to_vote,
                        loading: vm.submitting,
                        onPressed: vm.canSubmit(team) ? () => _submit(context, team) : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: context.colors.surfaceContainerLowest,
                            foregroundColor: context.colors.onSurface,
                            side: BorderSide(color: context.colors.outlineVariant),
                          ),
                          onPressed: () => context.pop(),
                          child: const Text('Cancel and return to My Team'),
                        ),
                      ),
                    ],
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
    final vm = context.watch<VotingViewModel>();
    final showTally = vm.showTally(team);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Figma SCR_06 header: team chip, session chip, heading, rule.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            StatusBadge(
              label: '${team.name} · ${Fmt.count(team.memberCount, 'candidate')}',
              tone: Tone.info,
              icon: Icons.groups,
            ),
            StatusBadge(label: team.locked ? 'Voting closed' : 'Active session', icon: Icons.how_to_reg),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(header: true, child: Text('Elect team leader', style: context.text.headlineMedium)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'The leader submits the final roster. A leader needs ${Fmt.count(team.votesNeeded, 'vote')} '
          '(more than half of ${team.memberCount} members).',
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (showTally) ...[
          AppCard(
            color: context.colors.surfaceContainerHigh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconTile(icon: Icons.how_to_vote, tone: Tone.info, size: 32),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('Voting progress', style: context.text.titleSmall)),
                    Text(
                      '${team.votes.length} of ${team.memberCount} cast',
                      style: context.text.labelLarge?.copyWith(color: context.colors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadius.fullAll,
                  child: LinearProgressIndicator(
                    value: team.memberCount == 0 ? 0 : team.votes.length / team.memberCount,
                    minHeight: AppSize.progress,
                    backgroundColor: context.colors.surfaceContainerLowest,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text('${Fmt.count(team.votes.length, 'ballot')} recorded', style: context.text.bodySmall),
                    ),
                    Text('Majority rule (${team.votesNeeded}+ votes)', style: context.text.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (team.hasLeader)
          InfoBanner(
            semanticId: 'banner_leader_elected',
            tone: Tone.success,
            icon: Icons.star,
            title: '${team.leader!.fullName} is your team leader',
            message: team.locked
                ? 'Voting closed when the roster was locked.'
                : 'Elected with ${Fmt.count(team.votesFor(team.leaderId!), 'vote')}. Votes can still change until the roster is locked.',
            action: AppButton(
              semanticId: 'btn_back_to_team',
              label: 'Back to My Team',
              variant: AppButtonVariant.secondary,
              expand: false,
              onPressed: () => context.pop(),
            ),
          )
        else
          InfoBanner(
            tone: Tone.info,
            icon: Icons.visibility_off_outlined,
            title: showTally ? 'No leader yet' : 'Results appear after you vote',
            message: showTally
                ? '${team.votes.length} of ${team.memberCount} members have voted.'
                : 'Hiding the count keeps early votes from swaying yours.',
          ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Candidates'),
        const SizedBox(height: AppSpacing.md),
        for (final m in team.members) ...[
          SelectableCard(
            semanticId: 'candidate_${m.studentId}',
            semanticLabel:
                '${m.fullName}, ${m.role}'
                '${showTally ? ', ${Fmt.count(team.votesFor(m.studentId), 'vote')}' : ''}',
            selected: vm.selected == m.studentId,
            onTap: team.locked ? null : () => vm.select(m.studentId),
            child: Row(
              children: [
                MemberAvatar(initials: m.initials, avatarUrl: m.avatarUrl),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.studentId == vm.myId ? '${m.fullName} (you)' : m.fullName, style: context.text.titleSmall),
                      Text(m.role, style: context.text.bodyMedium),
                      if (showTally) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _TallyBar(votes: team.votesFor(m.studentId), needed: team.votesNeeded),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (vm.myVote(team) != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your vote: ${team.members.firstWhere((m) => m.studentId == vm.myVote(team)).fullName}',
            style: context.text.labelLarge,
          ),
        ],
      ],
    );
  }
}

class _TallyBar extends StatelessWidget {
  const _TallyBar({required this.votes, required this.needed});

  final int votes;
  final int needed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadius.fullAll,
            child: LinearProgressIndicator(value: (votes / needed).clamp(0, 1).toDouble(), minHeight: AppSize.progress),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('$votes/$needed', style: context.text.labelMedium),
      ],
    );
  }
}
