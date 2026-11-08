import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/mentor.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../viewmodels/mentor_detail_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/feedback.dart';
import '../shared/profile_action.dart';

class MentorDetailScreen extends StatelessWidget {
  const MentorDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MentorDetailViewModel>();
    return BlockingOverlay(
      visible: vm.sending || vm.withdrawing,
      message: vm.sending ? 'Sending request…' : 'Withdrawing request…',
      child: Scaffold(
        appBar: const AppTopBar(
          title: 'Mentor Profile',
          showBack: true,
          actions: [ProfileAction()],
        ),
        body: RefreshIndicator(
          onRefresh: vm.load,
          child: ListView(
            padding: AppSpacing.screen,
            children: [
              ViewStateView<Mentor>(
                state: vm.state,
                onRetry: vm.load,
                builder: (context, mentor) => _MentorDetailBody(mentor: mentor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MentorDetailBody extends StatelessWidget {
  const _MentorDetailBody({required this.mentor});

  final Mentor mentor;

  Future<void> _showRequestDialog(BuildContext context) async {
    final vm = context.read<MentorDetailViewModel>();
    final team = vm.team!;
    final defaultMessage = 'Dear ${mentor.fullName},\n\nOur team ${team.name} is working on "${team.topic}". '
        'We would be honored to have your guidance as our Capstone supervisor.';

    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => _MentorRequestDialog(
        mentorName: mentor.fullName,
        initialMessage: defaultMessage,
      ),
    );

    if (message == null || message.trim().isEmpty) return;

    // Await dialog exit animation to avoid unmount assertion conflicts
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!context.mounted) return;

    final failure = await vm.sendRequest(message.trim());
    if (!context.mounted) return;
    if (failure != null) return showFailure(context, failure);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request sent to ${mentor.fullName}')));
  }

  Future<void> _withdraw(BuildContext context) async {
    final vm = context.read<MentorDetailViewModel>();
    final confirmed = await showAppDialog(
      context,
      semanticId: 'dialog_withdraw_mentor_request',
      destructive: true,
      title: 'Withdraw request?',
      message: '${mentor.fullName} will no longer see your request, and you can ask another mentor.',
      confirmLabel: 'Withdraw',
    );
    if (!confirmed) return;

    // Await dialog exit animation
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!context.mounted) return;

    final failure = await vm.withdraw();
    if (!context.mounted) return;
    if (failure != null) return showFailure(context, failure);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request withdrawn')));
  }

  Widget _action(BuildContext context, MentorDetailViewModel vm) => switch (vm.actionFor(mentor)) {
    MentorAction.assigned => InfoBanner(
      semanticId: 'banner_assigned_mentor',
      tone: Tone.success,
      title: 'Your team\'s mentor',
      message: '${mentor.fullName} supervises ${vm.team!.name}.',
    ),
    MentorAction.otherMentor => InfoBanner(
      semanticId: 'banner_has_mentor',
      title: 'Your team already has a mentor',
      message: '${vm.team!.supervisor} supervises ${vm.team!.name}.',
    ),
    MentorAction.noTeam => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(
          semanticId: 'banner_no_team_mentor',
          title: 'Join a team first',
          message: 'A team leader chooses the mentor for the whole team.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          semanticId: 'btn_browse_teams_for_mentor',
          label: 'Browse Teams',
          icon: Icons.search,
          onPressed: () => context.go('/browse'),
        ),
      ],
    ),
    MentorAction.pendingHere => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBanner(
          semanticId: 'banner_request_pending',
          tone: Tone.warning,
          icon: Icons.hourglass_top,
          title: 'Waiting for a reply',
          message: '${vm.request!.senderName} asked ${mentor.fullName} to supervise ${vm.team!.name}.',
        ),
        if (vm.isLeader) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            semanticId: 'btn_withdraw_mentor_request',
            label: 'Withdraw Request',
            icon: Icons.cancel_outlined,
            variant: AppButtonVariant.destructive,
            onPressed: () => _withdraw(context),
          ),
        ],
      ],
    ),
    MentorAction.pendingElsewhere => InfoBanner(
      semanticId: 'banner_request_elsewhere',
      tone: Tone.warning,
      title: 'Your team is waiting on ${vm.request!.mentorName}',
      message: 'A team asks one mentor at a time. Withdraw that request to ask someone else.',
    ),
    MentorAction.notLeader => const InfoBanner(
      semanticId: 'banner_leader_only',
      title: 'Only your team leader can send a request',
      message: 'Ask your leader to open this profile, or elect a leader first.',
    ),
    MentorAction.quotaFull => InfoBanner(
      semanticId: 'banner_mentor_full',
      tone: Tone.warning,
      title: 'This mentor is full',
      message: '${mentor.fullName} cannot take more teams this semester. Choose another mentor.',
    ),
    MentorAction.canRequest => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vm.declinedHere) ...[
          InfoBanner(
            semanticId: 'banner_request_declined',
            tone: Tone.warning,
            title: '${mentor.fullName} declined your last request',
            message: vm.request!.decisionReason,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppButton(
          semanticId: 'btn_request_mentor',
          label: 'Request as Mentor',
          icon: Icons.send,
          onPressed: () => _showRequestDialog(context),
        ),
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MentorDetailViewModel>();
    final available = mentor.isAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Card
        AppCard(
          semanticId: 'card_mentor_header',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: context.colors.primaryContainer,
                child: Text(
                  mentor.initials,
                  style: context.text.headlineMedium?.copyWith(
                    color: context.colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                mentor.fullName,
                style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                mentor.title,
                style: context.text.titleSmall?.copyWith(color: context.colors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                mentor.department,
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              StatusBadge(
                label: available ? Fmt.count(mentor.remainingSlots, 'slot') : 'Full',
                tone: available ? Tone.success : Tone.neutral,
                icon: available ? Icons.check_circle : Icons.block,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Contact & Office Information
        AppCard(
          semanticId: 'card_mentor_contact',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contact & Office', style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 20, color: context.colors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(mentor.email, style: context.text.bodyMedium),
                  ),
                ],
              ),
              if (mentor.office.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 20, color: context.colors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(mentor.office, style: context.text.bodyMedium),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Capacity and Load
        AppCard(
          semanticId: 'card_mentor_quota',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('Mentorship Capacity', style: context.text.titleMedium)),
                  Text(
                    '${mentor.currentAssigned} / ${mentor.maxQuota} Teams',
                    style: context.text.titleSmall?.copyWith(
                      color: available ? context.colors.primary : context.colors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadius.fullAll,
                child: LinearProgressIndicator(
                  value: (mentor.currentAssigned / mentor.maxQuota).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: context.colors.surfaceContainerHighest,
                  color: available ? context.colors.primary : context.colors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                available
                    ? 'Can supervise ${Fmt.count(mentor.remainingSlots, 'more team')}.'
                    : 'Maximum supervision quota reached for this semester.',
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              if (mentor.mentoredTeamNames.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Currently Supervising:', style: context.text.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final t in mentor.mentoredTeamNames)
                      StatusBadge(label: t, tone: Tone.info, icon: Icons.groups),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Areas of Expertise
        AppCard(
          semanticId: 'card_mentor_expertise',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Areas of Expertise & Research', style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final exp in mentor.expertise)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: context.colors.primaryContainer,
                        borderRadius: AppRadius.fullAll,
                      ),
                      child: Text(
                        exp,
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Bio & Introduction
        AppCard(
          semanticId: 'card_mentor_bio',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About & Research Focus', style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                mentor.bio,
                style: context.text.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        _action(context, vm),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _MentorRequestDialog extends StatefulWidget {
  const _MentorRequestDialog({required this.mentorName, required this.initialMessage});
  final String mentorName;
  final String initialMessage;

  @override
  State<_MentorRequestDialog> createState() => _MentorRequestDialogState();
}

class _MentorRequestDialogState extends State<_MentorRequestDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Request ${widget.mentorName}', style: Theme.of(context).textTheme.titleLarge),
      content: SingleChildScrollView(
        child: AppTextField(
          semanticId: 'input_mentor_message',
          controller: _controller,
          label: 'Message to the mentor',
          maxLines: 6,
        ),
      ),
      actions: [
        AppButton(
          semanticId: 'btn_cancel_request_dialog',
          label: 'Cancel',
          expand: false,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        AppButton(
          semanticId: 'btn_send_mentor_request',
          label: 'Send Request',
          expand: false,
          icon: Icons.send,
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}
