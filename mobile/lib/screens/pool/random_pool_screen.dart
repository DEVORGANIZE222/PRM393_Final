import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/registration.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../viewmodels/pool_status_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';

/// SCR_08 Random Pool status (Figma `SCR_08: Random Pool Status`).
class RandomPoolScreen extends StatelessWidget {
  const RandomPoolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PoolStatusViewModel>();
    return Scaffold(
      appBar: const AppTopBar(title: 'Matching Status'),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => vm.load(userRefresh: true),
          child: ListView(
            padding: AppSpacing.screen,
            children: [
              ViewStateView<PoolStatus>(
                state: vm.state,
                onRetry: vm.load,
                builder: (context, p) => _Body(status: p, refreshing: vm.refreshing, onRefresh: vm.load),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.status, required this.refreshing, required this.onRefresh});

  final PoolStatus status;
  final bool refreshing;
  final Future<void> Function({bool userRefresh}) onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Figma SCR_08 hero: blue panel, engine icon, centred status.
        Semantics(
          identifier: 'banner_pool',
          container: true,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: context.appColors.infoContainer,
              borderRadius: AppRadius.cardAll,
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: context.appColors.info.withValues(alpha: 0.15),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: context.appColors.info,
                    child: Icon(Icons.hub, color: context.colors.onPrimary),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const StatusBadge(label: 'Pool engine active', tone: Tone.primary),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "You're in the Random Pool",
                  textAlign: TextAlign.center,
                  style: context.text.titleLarge?.copyWith(color: context.appColors.info),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Registration closed before you joined a team. '
                  'The system is matching you with students who need your role.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          semanticId: 'card_pool_progress',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sync, color: context.appColors.info),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('System matching status', style: context.text.titleSmall)),
                  Text(
                    Fmt.percent(status.progress),
                    style: context.text.labelLarge?.copyWith(color: context.appColors.info),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppProgressBar(value: status.progress, tone: Tone.info, label: status.stage),
              const SizedBox(height: AppSpacing.md),
              InfoRow(icon: Icons.tag, label: 'Assigned queue', value: status.queueId),
              InfoRow(icon: Icons.groups_outlined, label: 'Students in pool', value: '${status.studentsInPool}'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          color: context.appColors.warningContainer,
          child: Row(
            children: [
              Icon(Icons.hourglass_top, color: context.appColors.warning),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXPECTED RESOLUTION',
                      style: context.text.labelSmall?.copyWith(color: context.appColors.warning, letterSpacing: 0.6),
                    ),
                    Text(Fmt.dateTime(status.expectedResult), style: context.text.titleSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Your matching profile'),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preferred roles', style: context.text.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [for (final r in status.preferredRoles) StatusBadge(label: r, tone: Tone.warning)],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Skills', style: context.text.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [for (final s in status.skills) StatusBadge(label: s)],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          identifier: 'pool_last_checked',
          liveRegion: true,
          child: Text(
            'Last checked ${Fmt.ago(status.lastChecked, DateTime.now()).toLowerCase()}',
            style: context.text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          semanticId: 'btn_refresh_pool',
          label: refreshing ? 'Checking…' : 'Check Again',
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          loading: refreshing,
          onPressed: () => onRefresh(userRefresh: true),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Questions about matching? Email ${status.contactEmail}.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
