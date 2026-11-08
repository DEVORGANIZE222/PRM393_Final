import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../models/team.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status.dart';

/// One status vocabulary for a team everywhere it appears (UI consistency:
/// "each concept has one name"; status colours only for status). Same order
/// as `MyTeamViewModel.phaseOf`.
({String label, Tone tone, IconData icon}) teamPhase(Team t) {
  if (t.locked) return (label: 'Locked', tone: Tone.success, icon: Icons.lock);
  if (!t.hasLeader) return (label: 'Leader not elected', tone: Tone.warning, icon: Icons.how_to_vote);
  if (!t.meetsSizeRule) {
    return (label: 'Needs members · ${t.memberCount}/${t.capacity}', tone: Tone.warning, icon: Icons.group_add);
  }
  return (label: 'Ready to lock', tone: Tone.success, icon: Icons.check_circle);
}

String teamPhaseLabel(Team t) => teamPhase(t).label;

IconData notificationIcon(NotificationKind k) => switch (k) {
  NotificationKind.invite => Icons.group_add,
  NotificationKind.vote => Icons.how_to_vote,
  NotificationKind.system => Icons.campaign,
  NotificationKind.application => Icons.verified,
};

/// Team summary card used on Dashboard (Figma "Current team status").
class TeamStatusCard extends StatelessWidget {
  const TeamStatusCard({super.key, required this.team, this.onTap});

  final Team team;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = teamPhase(team);
    final needs = <String>[
      if (team.memberCount < TeamRules.minMembers) Fmt.count(TeamRules.minMembers - team.memberCount, 'more member'),
      if (!team.hasLeader) 'a leader',
    ];
    return AppCard(
      semanticId: 'card_team_status',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CURRENT TEAM STATUS',
                  style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant, letterSpacing: 0.6),
                ),
              ),
              StatusBadge(label: p.label, tone: p.tone, icon: p.icon),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(team.name, style: context.text.titleLarge),
              StatusBadge(label: team.code),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(team.topic, style: context.text.bodyLarge),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.groups, size: AppSize.iconSmall, color: context.colors.primary),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${team.memberCount}/${team.capacity} members formed ',
                        style: context.text.labelLarge?.copyWith(color: context.colors.primary),
                      ),
                      TextSpan(text: '(minimum ${TeamRules.minMembers} required)', style: context.text.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SlotRow(
            memberInitials: [for (final m in team.members) m.initials],
            avatarUrls: [for (final m in team.members) m.avatarUrl],
            capacity: team.capacity,
          ),
          if (needs.isNotEmpty && !team.locked) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: context.colors.surfaceContainerHigh, borderRadius: AppRadius.smAll),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: context.appColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Needs ${needs.join(' and ')} before locking.', style: context.text.bodyMedium),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.insights, size: 16, color: context.colors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Formation Health', style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                '${((team.memberCount / team.capacity) * 100).round()}% Complete',
                style: context.text.labelSmall?.copyWith(color: context.colors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _Stat(value: '${team.memberCount}/${team.capacity}', label: 'Team Size', ok: team.meetsSizeRule),
              const SizedBox(width: AppSpacing.sm),
              _Stat(value: team.hasLeader ? 'Passed' : 'Pending', label: 'Leader Vote', ok: team.hasLeader),
              const SizedBox(width: AppSpacing.sm),
              _Stat(value: team.hasMentor ? 'Assigned' : 'Not yet', label: 'Supervisor', ok: team.hasMentor),
            ],
          ),
        ],
      ),
    );
  }
}

/// Figma "Formation Health" tile: grey panel, coloured value, caption.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.ok});

  final String value;
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? context.colors.primary : context.appColors.warning;
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
          decoration: BoxDecoration(color: context.colors.surfaceContainerHigh, borderRadius: AppRadius.smAll),
          child: Column(
            children: [
              Text(value, style: context.text.titleMedium?.copyWith(color: color), maxLines: 1),
              const SizedBox(height: 2),
              Text(label, style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Roster row (Team Detail, My Team, Lock Review).
class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.member,
    this.badges = const [],
    this.isLeader = false,
    this.isMe = false,
    this.trailing,
  });

  final TeamMember member;
  final List<Widget> badges;
  final bool isLeader;
  final bool isMe;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final effectiveLeader = isLeader;
    final effectiveIsMe = isMe ||
        badges.any((b) => b is StatusBadge && b.label.toLowerCase() == 'you');

    final otherBadges = badges.where((b) {
      if (b is StatusBadge) {
        final l = b.label.toLowerCase();
        if (l.contains('lead') || l == 'you') return false;
      }
      return true;
    }).toList();

    return AppCard(
      semanticId: 'member_${member.studentId}',
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberAvatar(
            initials: member.initials,
            avatarUrl: member.avatarUrl,
            verified: true,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        member.fullName,
                        style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (effectiveIsMe) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBAE6FD), width: 0.8),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (trailing != null)
                      trailing!
                    else if (effectiveLeader)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                            SizedBox(width: 2.5),
                            Text(
                              'Leader',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (member.role.isNotEmpty &&
                        member.role.toLowerCase() != 'member' &&
                        !member.role.toLowerCase().contains('lead'))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                        ),
                        child: Text(
                          member.role,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.mail_outline_rounded,
                      size: 13,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        member.contactEmail,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (otherBadges.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: otherBadges),
                ],
                if (member.skills.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final skill in member.skills.take(3))
                        StatusBadge(label: skill, tone: Tone.neutral),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Dashed/tinted card for an open slot ("Looking for: …").
class OpenSlotTile extends StatelessWidget {
  const OpenSlotTile({super.key, required this.slot, required this.lookingFor});

  final int slot;
  final String lookingFor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFFFFF7ED),
      borderColor: const Color(0xFFFDBA74),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: AppSize.avatar,
            height: AppSize.avatar,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFED7AA),
              border: Border.all(color: const Color(0xFFF97316), width: 1.5),
            ),
            child: const Icon(Icons.add, size: 20, color: Color(0xFFC2410C)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Open slot $slot', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
                    const StatusBadge(label: 'Waiting for applicant', tone: Tone.warning),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.person_search, size: AppSize.iconSmall, color: context.colors.secondary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Looking for: $lookingFor',
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            trailing!,
          ],
        ],
      ),
    );
  }
}
