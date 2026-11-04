import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/team.dart';
import '../../models/view_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../viewmodels/browse_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/profile_action.dart';

/// SCR_03 Browse Teams (Figma `SCR_03: Browse Groups`, renamed per DV-01).
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BrowseViewModel>();
    final state = vm.state;
    return Scaffold(
      appBar: const AppTopBar(title: 'Browse Teams', showBack: false, actions: [ProfileAction()]),
      body: RefreshIndicator(
        onRefresh: vm.search,
        child: ListView(
          padding: AppSpacing.screen,
          children: [
            AppSearchField(
              controller: _search,
              onSubmitted: vm.search,
              onChanged: vm.queryChanged,
              onClear: () {
                _search.clear();
                vm.search('');
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              identifier: 'browse_filters',
              container: true,
              // One scrollable row of chips, as in the Figma filter bar.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in TeamFilter.values) ...[
                      AppChip(
                        label: f.label,
                        selected: vm.filters.contains(f),
                        onSelected: (on) => vm.toggleFilter(f, on),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Quick action banner to create team without having to scroll down
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: AppRadius.cardAll,
                border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.rocket_launch, color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Want to lead a startup?',
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF14532D),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Pitch your idea and recruit your dream team.',
                          style: context.text.bodySmall?.copyWith(
                            color: const Color(0xFF166534),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => context.push('/create-team'),
                    icon: const Icon(Icons.group_add, size: 18),
                    label: const Text('Create'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: context.text.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (state is Data<List<Team>>) ...[
              Semantics(
                identifier: 'browse_result_count',
                liveRegion: true,
                child: Text(
                  '${state.value.length} ${state.value.length == 1 ? 'team' : 'teams'}'
                  '${vm.filters.contains(TeamFilter.openSlots) ? ' with open slots' : ''}',
                  style: context.text.labelMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            ViewStateView<List<Team>>(
              state: state,
              onRetry: vm.search,
              empty: EmptyState(
                icon: Icons.search_off,
                title: 'No teams match your search',
                message: vm.hasCriteria
                    ? 'Try a different keyword or clear the filters to see every team with open slots.'
                    : 'Every team is full right now. Check again later or wait for the Random Pool.',
                actionLabel: vm.hasCriteria ? 'Clear Filters' : null,
                onAction: vm.hasCriteria
                    ? () {
                        _search.clear();
                        vm.clearCriteria();
                      }
                    : null,
              ),
              builder: (context, teams) => Column(
                children: [
                  for (final t in teams) ...[_TeamCard(team: t), const SizedBox(height: AppSpacing.md)],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              color: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.groups, color: Color(0xFFD97706), size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Can't find the right fit?",
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Create your own startup team or join the Random Pool before the deadline.',
                              style: context.text.bodySmall?.copyWith(
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    semanticId: 'btn_create_team_browse',
                    label: 'Create a Team',
                    icon: Icons.group_add,
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    onPressed: () => context.push('/create-team'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final open = team.openSlots;
    void openDetail() => context.push('/browse/team/${team.id}');

    // Figma SCR_03 card: green top stripe, member/open badge, category, tags,
    // a grey "seeking roles" panel and a full-width green action.
    return AppCard(
      semanticId: 'team_card_${team.code}',
      onTap: openDetail,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: open == 0 ? context.colors.outlineVariant : context.colors.primary),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(team.name, style: context.text.titleLarge)),
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge(
                      label: open == 0 ? 'Full' : '${team.memberCount}/${team.capacity} · $open open',
                      tone: open == 0 ? Tone.neutral : Tone.primary,
                      icon: open == 0 ? Icons.block : Icons.group_add,
                    ),
                  ],
                ),
                if (team.category.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      StatusBadge(label: team.category, tone: Tone.warning, icon: Icons.school),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text('', style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(team.topic, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (team.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [for (final tag in team.tags.take(4)) StatusBadge(label: tag)],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: context.colors.surfaceContainerHigh, borderRadius: AppRadius.smAll),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                for (var i = 0; i < team.members.length; i++) ...[
                                  MemberAvatar(
                                    initials: team.members[i].initials,
                                    avatarUrl: team.members[i].avatarUrl,
                                    size: AppSize.avatarSmall,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                ],
                                for (var k = 0; k < open; k++) ...[
                                  const MemberAvatar(size: AppSize.avatarSmall),
                                  if (k < open - 1) const SizedBox(width: AppSpacing.xs),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            open == 0 ? 'Full' : '$open open',
                            style: context.text.bodySmall?.copyWith(
                              color: open == 0 ? context.colors.outline : context.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (team.openRoles.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Icon(Icons.person_search, size: 16, color: context.colors.secondary),
                            const SizedBox(width: 6),
                            Text('Looking for: ', style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                            Expanded(
                              child: Text(
                                team.openRoles.join(' · '),
                                style: context.text.bodySmall?.copyWith(
                                  color: context.colors.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  semanticId: 'btn_view_${team.code}',
                  label: open == 0 ? 'View Details' : 'View Details & Join',
                  icon: Icons.arrow_forward,
                  variant: open == 0 ? AppButtonVariant.secondary : AppButtonVariant.primary,
                  onPressed: openDetail,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
