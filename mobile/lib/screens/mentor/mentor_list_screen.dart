import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/mentor.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../viewmodels/mentor_list_viewmodel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/profile_action.dart';

class MentorListScreen extends StatefulWidget {
  const MentorListScreen({super.key});

  @override
  State<MentorListScreen> createState() => _MentorListScreenState();
}

class _MentorListScreenState extends State<MentorListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MentorListViewModel>();
    return Scaffold(
      appBar: const AppTopBar(
        title: 'Choose a Mentor',
        showBack: true,
        actions: [ProfileAction()],
      ),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          padding: AppSpacing.screen,
          children: [
            AppSearchField(
              hint: 'Search by name, department or skill…',
              controller: _search,
              onSubmitted: vm.search,
              onClear: () {
                _search.clear();
                vm.search('');
              },
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AppChip(
                    label: 'Available only',
                    selected: vm.availableOnly,
                    onSelected: (_) => vm.toggleAvailableOnly(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  for (final exp in MentorListViewModel.expertiseFilters) ...[
                    AppChip(
                      label: exp,
                      selected: vm.expertise == exp,
                      onSelected: (_) => vm.toggleExpertise(exp),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ViewStateView<List<Mentor>>(
              state: vm.state,
              onRetry: vm.load,
              loading: const SkeletonList(count: 4),
              empty: EmptyState(
                icon: Icons.person_search_outlined,
                title: 'No mentors found',
                message: 'No mentor matches your search and filters. Try another topic or reset them.',
                actionLabel: 'Reset Filters',
                onAction: () {
                  _search.clear();
                  vm.reset();
                },
              ),
              builder: (context, mentors) => Column(
                children: [
                  for (final mentor in mentors) ...[
                    _MentorCard(mentor: mentor),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MentorCard extends StatelessWidget {
  const _MentorCard({required this.mentor});

  final Mentor mentor;

  @override
  Widget build(BuildContext context) {
    final available = mentor.isAvailable;
    return AppCard(
      semanticId: 'card_mentor_${mentor.id}',
      onTap: () => context.push('/mentors/${mentor.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: context.colors.primaryContainer,
                child: Text(
                  mentor.initials,
                  style: context.text.titleMedium?.copyWith(
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
                    Text(
                      mentor.fullName,
                      style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      mentor.title,
                      style: context.text.bodySmall?.copyWith(color: context.colors.primary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      mentor.department,
                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: available ? Fmt.count(mentor.remainingSlots, 'slot') : 'Full',
                tone: available ? Tone.success : Tone.neutral,
                icon: available ? Icons.check_circle_outline : Icons.block,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            mentor.bio,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final skill in mentor.expertise)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHigh,
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Text(
                    skill,
                    style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Supervising ${mentor.currentAssigned}/${mentor.maxQuota} teams',
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ),
              Text(
                'View profile →',
                style: context.text.labelLarge?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
