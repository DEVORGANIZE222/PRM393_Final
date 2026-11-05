import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/mentor_requests_viewmodel.dart';

/// Web admin screen for lecturers: answer the requests teams send from the
/// mobile app. The team sees the answer in real time on My Team.
class MentorRequestsScreen extends StatelessWidget {
  const MentorRequestsScreen({super.key});

  static Future<String?> _signedInMentorId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return (await SharedFirestoreService().getUserProfile(uid))?.mentorId;
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Firebase is not configured',
        message: 'Run the web admin with the FIREBASE_WEB_* values from the README.',
      );
    }
    return Theme(
      data: buildAppTheme(),
      child: ChangeNotifierProvider(
        create: (_) => MentorRequestsViewModel(FirestoreMentorRepository(), _signedInMentorId)..load(),
        child: const MentorRequestsView(),
      ),
    );
  }
}

class MentorRequestsView extends StatelessWidget {
  const MentorRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MentorRequestsViewModel>();
    return BlockingOverlay(
      visible: vm.processing,
      message: 'Saving your answer…',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ViewStateView<Mentor>(
          state: vm.state,
          onRetry: vm.load,
          empty: const EmptyState(
            icon: Icons.person_off_outlined,
            title: 'No mentor profile on this account',
            message: 'Ask an admin to set mentorId on your users document.',
          ),
          builder: (context, mentor) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _Requests(requests: vm.requests)),
              const SizedBox(width: AppSpacing.xl),
              SizedBox(width: 320, child: _Summary(mentor: mentor, teams: vm.teams, pending: vm.pendingCount)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Requests extends StatelessWidget {
  const _Requests({required this.requests});

  final List<MentorRequest> requests;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Mentor Requests', style: context.text.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Team leaders ask you from the mobile app. Your answer reaches them in real time.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: requests.isEmpty
              ? const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No requests yet',
                  message: 'When a team leader asks you to supervise their team, the request appears here.',
                )
              : ListView.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) => _RequestCard(request: requests[i]),
                ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final MentorRequest request;

  Future<void> _accept(BuildContext context) async {
    final vm = context.read<MentorRequestsViewModel>();
    final ok = await showAppDialog(
      context,
      title: 'Accept ${request.teamName}?',
      message: 'You become this team\'s supervisor, which takes one of your quota slots.',
      confirmLabel: 'Accept',
    );
    if (!ok || !context.mounted) return;
    final failure = await vm.respond(request, accept: true);
    if (context.mounted) _report(context, failure);
  }

  Future<void> _decline(BuildContext context) async {
    final vm = context.read<MentorRequestsViewModel>();
    final reason = await showDialog<String>(context: context, builder: (_) => _DeclineDialog(team: request.teamName));
    if (reason == null || !context.mounted) return;
    final failure = await vm.respond(request, accept: false, reason: reason);
    if (context.mounted) _report(context, failure);
  }

  void _report(BuildContext context, AppFailure? failure) {
    if (failure == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${failure.title}. ${failure.cause}')));
  }

  @override
  Widget build(BuildContext context) {
    final tone = switch (request.status) {
      MentorRequestStatus.pending => Tone.warning,
      MentorRequestStatus.approved => Tone.success,
      MentorRequestStatus.rejected => Tone.neutral,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(request.teamName, style: context.text.titleMedium)),
              StatusBadge(label: request.status.label, tone: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'From ${request.senderName}',
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(request.message.isEmpty ? 'No message attached.' : request.message, style: context.text.bodyMedium),
          if ((request.decisionReason ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Reason: ${request.decisionReason}', style: context.text.bodySmall),
          ],
          if (request.isPending) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Decline',
                  expand: false,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _decline(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(label: 'Accept', expand: false, icon: Icons.check, onPressed: () => _accept(context)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Returns the reason, or null when cancelled. A refusal needs a reason so the
/// team knows what to change.
class _DeclineDialog extends StatefulWidget {
  const _DeclineDialog({required this.team});

  final String team;

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Decline ${widget.team}?'),
      content: SizedBox(
        width: 420,
        child: AppTextField(
          controller: _reason,
          label: 'Reason shown to the team',
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          expand: false,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Decline',
          expand: false,
          variant: AppButtonVariant.destructive,
          onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_reason.text.trim()),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.mentor, required this.teams, required this.pending});

  final Mentor mentor;
  final List<Team> teams;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mentor.fullName, style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(mentor.title, style: context.text.bodySmall?.copyWith(color: context.colors.primary)),
              const SizedBox(height: AppSpacing.md),
              Text('Supervising ${mentor.currentAssigned} of ${mentor.maxQuota} teams', style: context.text.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: AppRadius.fullAll,
                child: LinearProgressIndicator(
                  value: mentor.maxQuota == 0 ? 1 : mentor.currentAssigned / mentor.maxQuota,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('$pending waiting for your answer', style: context.text.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('My Teams', style: context.text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (teams.isEmpty)
          Text('Teams you accept appear here.', style: context.text.bodySmall)
        else
          for (final team in teams) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team.name, style: context.text.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(team.topic, style: context.text.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${team.memberCount} of ${team.capacity} members', style: context.text.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}
