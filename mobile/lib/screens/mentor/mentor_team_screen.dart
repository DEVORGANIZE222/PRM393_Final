import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/team.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../viewmodels/mentor_team_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/team_status.dart';

/// Opened from the Mentor Portal: one supervised team and how to reach it.
class MentorTeamScreen extends StatelessWidget {
  const MentorTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MentorTeamViewModel>();
    return Scaffold(
      appBar: const AppTopBar(title: 'Team', showBack: true),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          padding: AppSpacing.screen,
          children: [
            ViewStateView<Team>(
              state: vm.state,
              onRetry: vm.load,
              builder: (context, team) => vm.supervises(team)
                  ? _Body(team: team, emails: vm.emails(team))
                  : const EmptyState(
                      icon: Icons.lock_outline,
                      title: 'You do not supervise this team',
                      message: 'Only the lecturer who accepted a team can see its members and contacts.',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.team, required this.emails});

  final Team team;
  final List<String> emails;

  /// Opens the mail app with every member as a recipient. Without one, the
  /// addresses are copied so the lecturer can paste them anywhere.
  Future<void> _emailTeam(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: emails.join(','),
      query: 'subject=${Uri.encodeComponent('[${team.code}] ${team.name}')}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {}
    if (opened || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: emails.join(', ')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No mail app found. The team\'s addresses were copied instead.')),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: emails.join(', ')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${emails.length} email ${emails.length == 1 ? 'address' : 'addresses'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leader = team.members.where((m) => m.studentId == team.leaderId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          semanticId: 'card_mentor_team_header',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(team.name, style: context.text.headlineSmall)),
                  StatusBadge(
                    label: team.locked ? 'Locked' : 'In formation',
                    tone: team.locked ? Tone.success : Tone.warning,
                    icon: team.locked ? Icons.lock : Icons.group_add,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              StatusBadge(label: team.code, icon: Icons.tag),
              const SizedBox(height: AppSpacing.sm),
              Text(team.topic, style: context.text.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              InfoRow(icon: Icons.groups_outlined, label: 'Members', value: '${team.memberCount} of ${team.capacity}'),
              InfoRow(icon: Icons.star_outline, label: 'Leader', value: leader?.fullName ?? 'Not elected yet'),
              if (team.lockCode != null)
                InfoRow(icon: Icons.verified_outlined, label: 'Lock code', value: team.lockCode!),
              if (team.lockedAt != null)
                InfoRow(icon: Icons.event_outlined, label: 'Locked on', value: Fmt.dateTime(team.lockedAt!)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          semanticId: 'btn_email_team',
          label: 'Email the Team',
          icon: Icons.email_outlined,
          onPressed: emails.isEmpty ? null : () => _emailTeam(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          semanticId: 'btn_copy_emails',
          label: 'Copy Email Addresses',
          icon: Icons.copy,
          variant: AppButtonVariant.secondary,
          onPressed: emails.isEmpty ? null : () => _copy(context),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: 'Members', trailing: '${team.memberCount} of ${team.capacity}'),
        const SizedBox(height: AppSpacing.md),
        for (final m in team.members) ...[
          MemberTile(
            member: m,
            isLeader: m.studentId == team.leaderId,
            badges: [
              if (m.studentId == team.leaderId) const StatusBadge(label: 'Leader', tone: Tone.primary, icon: Icons.star),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
