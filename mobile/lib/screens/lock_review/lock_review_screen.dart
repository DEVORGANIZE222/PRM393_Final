import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/team.dart';
import '../../services/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../viewmodels/lock_review_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/feedback.dart';
import '../shared/team_status.dart';

/// SCR_07 Review & Lock with error recovery (Figma `SCR_07: Group Lock Review & Error Recovery`), Flow 3.
class LockReviewScreen extends StatelessWidget {
  const LockReviewScreen({super.key});

  Future<void> _invite(BuildContext context) async {
    final result = await context.read<LockReviewViewModel>().inviteFromPool();
    if (!context.mounted) return;
    if (result.failure != null) return showFailure(context, result.failure!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invites sent to ${Fmt.count(result.invited ?? 0, 'student')} in the Waiting Pool')),
    );
  }

  Future<void> _share(Team team) => SharePlus.instance.share(
    ShareParams(
      subject: 'Join ${team.name} on EXEMatching',
      text:
          '${team.name} needs ${Fmt.count(team.openSlots, 'more member')} for "${team.topic}". '
          'Open EXEMatching and search for ${team.code}: https://exematching.app/team/${team.code}',
    ),
  );

  Future<void> _lock(BuildContext context, Team team) async {
    final vm = context.read<LockReviewViewModel>();
    final ok = await showAppDialog(
      context,
      semanticId: 'dialog_lock',
      destructive: true,
      icon: Icons.lock,
      title: 'Lock ${team.name}?',
      message: 'The roster goes to the Academic Office. After locking, nobody can join, leave or change the leader.',
      confirmLabel: 'Lock Roster',
    );
    if (!ok || !context.mounted) return;
    final failure = await vm.lock();
    if (!context.mounted) return;
    if (failure != null) showFailure(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LockReviewViewModel>();
    return BlockingOverlay(
      visible: vm.locking,
      message: 'Locking roster…',
      child: Scaffold(
        appBar: const AppTopBar(title: 'Review & Lock'),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: AppSpacing.screen,
            children: [
              ViewStateView<Team>(
                state: vm.state,
                onRetry: vm.load,
                empty: const NoTeamState(message: 'Join a team first. Its leader locks the roster here.'),
                builder: (context, team) => team.locked
                    ? _Locked(team: team)
                    : _Review(
                        team: team,
                        onInvite: () => _invite(context),
                        onShare: () => _share(team),
                        onLock: () => _lock(context, team),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Review extends StatelessWidget {
  const _Review({required this.team, required this.onInvite, required this.onShare, required this.onLock});

  final Team team;
  final VoidCallback onInvite;
  final VoidCallback onShare;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LockReviewViewModel>();
    final checks = vm.checks(team);
    final blocked = vm.blockedReason(team);
    final leader = vm.isLeader(team);
    final issues = checks.where((c) => c.status != CheckStatus.passed).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Figma SCR_07 header.
        const Align(
          alignment: Alignment.centerLeft,
          child: StatusBadge(label: 'Experiential Entrepreneurship Spring 2026', icon: Icons.school_outlined),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(header: true, child: Text('Review & lock team', style: context.text.headlineMedium)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Locking finalises ${team.name} and sends it to the FPT Academic Office for mentor matching.',
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (vm.lastJoinedName != null) ...[
          InfoBanner(
            semanticId: 'banner_pool_joined',
            tone: Tone.success,
            icon: Icons.group_add,
            title: '${vm.lastJoinedName} joined from the Waiting Pool',
            message: '${team.name} now has ${team.memberCount} of ${team.capacity} members.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (!team.meetsSizeRule) ...[
          InfoBanner(
            semanticId: 'banner_lock_error',
            tone: Tone.error,
            title: "Can't lock yet: needs ${Fmt.count(TeamRules.minMembers - team.memberCount, 'more member')}",
            message:
                'Your team has ${team.memberCount} of ${team.capacity} members and FPT rules need at least '
                '${TeamRules.minMembers}. Invite students from the Waiting Pool or share your team link.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppCard(
          semanticId: 'card_lock_checks',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Verification requirements', style: context.text.titleSmall)),
                  if (issues > 0)
                    StatusBadge(label: Fmt.count(issues, 'issue'), tone: Tone.error)
                  else
                    const StatusBadge(label: 'All passed', tone: Tone.primary),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final (i, c) in checks.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _CheckRow(check: c),
              ],
            ],
          ),
        ),
        if (!team.meetsSizeRule) ...[
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Icon(Icons.bolt, color: context.colors.primary),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(child: SectionHeader(title: 'How to resolve this blocker')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            semanticId: 'card_recovery',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconTile(icon: Icons.group_add, tone: Tone.warning, size: 36),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text('Invite from the Waiting Pool', style: context.text.titleSmall)),
                    if (team.invitesSent > 0)
                      StatusBadge(label: '${team.invitesSent} invited', tone: Tone.info, icon: Icons.send),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Students without a team who match your open roles: '
                  '${team.openRoles.isEmpty ? 'any role' : team.openRoles.join(', ')}. '
                  'The first to accept joins automatically.',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  semanticId: 'btn_invite_pool',
                  label: team.invitesSent > 0 ? 'Invite More Students' : 'Invite from Waiting Pool',
                  icon: Icons.person_search,
                  loading: vm.inviting,
                  onPressed: leader ? onInvite : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  semanticId: 'btn_share_invite',
                  label: 'Share Team Link',
                  icon: Icons.share,
                  variant: AppButtonVariant.secondary,
                  onPressed: onShare,
                ),
                if (!leader) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Only the team leader can invite from the Waiting Pool.', style: context.text.bodySmall),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: 'Roster', trailing: '${team.memberCount} of ${team.capacity}'),
        const SizedBox(height: AppSpacing.md),
        for (final m in team.members) ...[
          MemberTile(
            member: m,
            isLeader: team.hasLeader && m.studentId == team.leaderId,
            isMe: m.studentId == vm.myId,
            badges: [
              if (team.hasLeader && m.studentId == team.leaderId)
                const StatusBadge(label: 'Leader', tone: Tone.primary, icon: Icons.star),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (team.locked) ...[
          AppButton(
            semanticId: 'btn_unlock_roster',
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
                try {
                  await context.read<TeamRepository>().unlockTeam(team.id, team.leaderId!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${team.name} unlocked successfully!')),
                    );
                    context.pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              }
            },
          ),
        ] else ...[
          AppButton(
            semanticId: 'btn_lock_roster',
            label: 'Lock Roster',
            icon: Icons.lock,
            onPressed: vm.canLock(team) ? onLock : null,
          ),
          if (blocked != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              identifier: 'lock_blocked_reason',
              child: Text(blocked, style: context.text.bodyMedium, textAlign: TextAlign.center),
            ),
          ],
        ],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final LockCheck check;

  @override
  Widget build(BuildContext context) {
    final (icon, tone, label) = switch (check.status) {
      CheckStatus.passed => (Icons.check, Tone.primary, 'PASSED'),
      CheckStatus.pending => (Icons.priority_high, Tone.warning, 'PENDING'),
      CheckStatus.failed => (Icons.close, Tone.error, 'FAILED'),
    };
    final colors = toneColors(context, tone);
    return Semantics(
      identifier: 'check_${check.id}',
      label: '${check.title}: $label. ${check.detail}',
      excludeSemantics: true,
      // Figma: tinted row, filled status circle, status pill.
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: check.status == CheckStatus.passed ? context.colors.surfaceContainerHigh : colors.bg,
          borderRadius: AppRadius.smAll,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: colors.fg,
              child: Icon(icon, size: 18, color: context.colors.onPrimary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(check.title, style: context.text.titleSmall),
                  Text(check.detail, style: context.text.bodySmall?.copyWith(color: colors.fg)),
                ],
              ),
            ),
            StatusBadge(label: label, tone: tone),
          ],
        ),
      ),
    );
  }
}

class _Locked extends StatelessWidget {
  const _Locked({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'state_locked',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          CircleAvatar(
            radius: AppSize.illustration / 2,
            backgroundColor: context.appColors.successContainer,
            child: Icon(Icons.lock, size: 48, color: context.appColors.success),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Roster locked', style: context.text.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${team.name} was sent to the Academic Office'
            '${team.lockedAt == null ? '' : ' on ${Fmt.dateTime(team.lockedAt!)}'}.',
            style: context.text.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            semanticId: 'card_lock_code',
            child: Column(
              children: [
                Text('Confirmation code', style: context.text.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(team.lockCode ?? '', style: context.text.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Quote this code if you contact the Academic Office.',
                  style: context.text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(semanticId: 'btn_back_to_team', label: 'Back to My Team', onPressed: () => context.pop()),
        ],
      ),
    );
  }
}
