import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mentor.dart';
import '../../models/team.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../viewmodels/mentor_portal_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/feedback.dart';

class MentorPortalScreen extends StatefulWidget {
  const MentorPortalScreen({super.key});

  @override
  State<MentorPortalScreen> createState() => _MentorPortalScreenState();
}

class _MentorPortalScreenState extends State<MentorPortalScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showAppDialog(
      context,
      destructive: true,
      title: 'Sign out?',
      message: 'You will return to the sign-in screen.',
      confirmLabel: 'Sign Out',
    );
    if (confirmed && context.mounted) {
      await context.read<SessionViewModel>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MentorPortalViewModel>();
    return BlockingOverlay(
      visible: vm.processing,
      message: 'Updating request…',
      child: Scaffold(
        appBar: AppTopBar(
          title: 'Mentor Portal',
          showBack: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () => _signOut(context),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: vm.load,
          child: ViewStateView<Mentor>(
            state: vm.state,
            onRetry: vm.load,
            builder: (context, mentor) => ListView(
              padding: AppSpacing.screen,
              children: [
                _MentorProfileCard(mentor: mentor),
                const SizedBox(height: AppSpacing.md),
                _QuotaStatsRow(mentor: mentor, pendingCount: vm.pendingCount),
                const SizedBox(height: AppSpacing.lg),
                TabBar(
                  controller: _tabController,
                  onTap: (_) => setState(() {}),
                  labelColor: context.colors.primary,
                  indicatorColor: context.colors.primary,
                  unselectedLabelColor: context.colors.onSurfaceVariant,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Requests'),
                          if (vm.pendingCount > 0) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Badge(label: Text('${vm.pendingCount}')),
                          ],
                        ],
                      ),
                    ),
                    Tab(text: 'My Teams (${vm.teams.length})'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_tabController.index == 0) ...[
                  if (vm.requests.isEmpty)
                    const EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No requests yet',
                      message: 'When a team leader asks you to supervise their team, the request appears here.',
                    )
                  else
                    for (final req in vm.requests) ...[
                      _RequestCard(request: req),
                      const SizedBox(height: AppSpacing.md),
                    ],
                ] else ...[
                  if (vm.teams.isEmpty)
                    const EmptyState(
                      icon: Icons.group_off_outlined,
                      title: 'No teams yet',
                      message: 'Teams you accept appear here.',
                    )
                  else
                    for (final team in vm.teams) ...[
                      _TeamCard(team: team),
                      const SizedBox(height: AppSpacing.md),
                    ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MentorProfileCard extends StatelessWidget {
  const _MentorProfileCard({required this.mentor});

  final Mentor mentor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticId: 'card_mentor_profile',
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: context.colors.primaryContainer,
            child: Text(
              mentor.initials,
              style: context.text.titleLarge?.copyWith(
                color: context.colors.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mentor.fullName,
                        style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const StatusBadge(label: 'Faculty', tone: Tone.primary, icon: Icons.school),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  mentor.title,
                  style: context.text.bodySmall?.copyWith(color: context.colors.primary),
                ),
                Text(
                  mentor.department,
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                if (mentor.office.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: context.colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          mentor.office,
                          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotaStatsRow extends StatelessWidget {
  const _QuotaStatsRow({required this.mentor, required this.pendingCount});

  final Mentor mentor;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'Assigned',
            value: '${mentor.currentAssigned}/${mentor.maxQuota}',
            tone: mentor.isAvailable ? Tone.success : Tone.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatBox(
            label: 'Slots Left',
            value: '${mentor.remainingSlots}',
            tone: mentor.remainingSlots > 0 ? Tone.info : Tone.neutral,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatBox(
            label: 'Pending',
            value: '$pendingCount',
            tone: pendingCount > 0 ? Tone.warning : Tone.neutral,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: AppRadius.smAll,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final MentorRequest request;

  Future<void> _handleAccept(BuildContext context, MentorRequest req) async {
    final confirmed = await showAppDialog(
      context,
      title: 'Accept ${req.teamName}?',
      message: 'You become this team\'s supervisor, which takes one of your quota slots.',
      confirmLabel: 'Accept',
    );
    if (confirmed && context.mounted) {
      final failure = await context.read<MentorPortalViewModel>().respond(req, accept: true);
      if (context.mounted && failure != null) {
        showFailure(context, failure);
      }
    }
  }

  Future<void> _handleDecline(BuildContext context, MentorRequest req) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Decline Request', style: ctx.text.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide a brief reason to ${req.teamName}:', style: ctx.text.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              semanticId: 'input_decline_reason',
              controller: controller,
              label: 'Reason for declining',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            expand: false,
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            semanticId: 'btn_confirm_decline',
            label: 'Decline',
            expand: false,
            variant: AppButtonVariant.destructive,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed == true && context.mounted) {
      final failure = await context.read<MentorPortalViewModel>().respond(req, accept: false, reason: reason);
      if (context.mounted && failure != null) {
        showFailure(context, failure);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = request.isPending;
    final isApproved = request.status == MentorRequestStatus.approved;

    return AppCard(
      semanticId: 'card_request_${request.teamId}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups, size: 20, color: context.colors.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  request.teamName,
                  style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              StatusBadge(
                label: request.status.label,
                tone: isPending ? Tone.warning : (isApproved ? Tone.success : Tone.neutral),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'From: ${request.senderName}',
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              request.message.isNotEmpty ? request.message : 'No message attached.',
              style: context.text.bodyMedium,
            ),
          ),
          if (request.decisionReason != null && request.decisionReason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reason: ${request.decisionReason}',
              style: context.text.bodySmall?.copyWith(color: context.colors.error),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    semanticId: 'btn_decline_${request.teamId}',
                    label: 'Decline',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _handleDecline(context, request),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    semanticId: 'btn_accept_${request.teamId}',
                    label: 'Accept',
                    icon: Icons.check,
                    onPressed: () => _handleAccept(context, request),
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

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticId: 'card_team_${team.id}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  team.name,
                  style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              StatusBadge(label: team.code),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(team.topic, style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.person, size: 16, color: context.colors.primary),
              const SizedBox(width: 4),
              Text(
                '${team.memberCount}/${team.capacity} members formed',
                style: context.text.bodySmall,
              ),
              const Spacer(),
              StatusBadge(
                label: team.locked ? 'Locked' : 'In Formation',
                tone: team.locked ? Tone.success : Tone.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
