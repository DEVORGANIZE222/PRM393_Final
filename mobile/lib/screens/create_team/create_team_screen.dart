import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../services/ai_topic_advisor_service.dart';
import '../../services/services.dart';
import '../../viewmodels/create_team_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../shared/feedback.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _topicController = TextEditingController();
  final _descController = TextEditingController();
  final _customRoleController = TextEditingController();
  final _customTagController = TextEditingController();

  String _selectedCategory = CreateTeamViewModel.defaultCategories.first;
  final Set<String> _selectedRoles = {'Frontend Dev', 'Backend Dev'};
  final Set<String> _selectedTags = {'Flutter', 'Firebase'};
  bool _isGeneratingAi = false;
  bool _aiDraftApplied = false;

  Future<void> _generateAiSuggestion() async {
    final config = context.read<ConfigService>();
    final analytics = context.read<AnalyticsService>();

    setState(() => _isGeneratingAi = true);

    final advisor = AiTopicAdvisorService(
      remoteConfig: config,
      analytics: analytics,
    );

    try {
      final proposal = await advisor.adviseTopic(
        rawTitle: _nameController.text.trim(),
        rawDescription: _topicController.text.trim(),
        category: _selectedCategory,
      );

      if (!mounted) return;
      setState(() {
        if (proposal.refinedTitle.isNotEmpty) {
          _nameController.text = proposal.refinedTitle;
        }
        if (proposal.description.isNotEmpty) {
          _topicController.text = proposal.description;
          _descController.text = proposal.description;
        }
        if (proposal.suggestedTags.isNotEmpty) {
          _selectedTags.clear();
          _selectedTags.addAll(proposal.suggestedTags);
        }
        if (proposal.suggestedRoles.isNotEmpty) {
          _selectedRoles.clear();
          _selectedRoles.addAll(proposal.suggestedRoles);
        }
        _aiDraftApplied = true;
      });

      await analytics.logAiResultAccepted(feature: 'topic_advisor');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ AI draft generated! You can edit any field before submitting.'),
          backgroundColor: Color(0xFF107C41),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Helper: $e'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    _descController.dispose();
    _customRoleController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<CreateTeamViewModel>();
    final team = await vm.createTeam(
      name: _nameController.text.trim(),
      topic: _topicController.text.trim(),
      category: _selectedCategory,
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : _topicController.text.trim(),
      tags: _selectedTags.toList(),
      openRoles: _selectedRoles.toList(),
    );
    if (!mounted) return;
    if (team != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Team "${team.name}" created successfully!')));
      context.go('/team');
    } else if (vm.failure != null) {
      showFailure(context, vm.failure!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateTeamViewModel>();
    final student = context.watch<SessionViewModel>().student;

    return BlockingOverlay(
      visible: vm.creating,
      message: 'Creating startup team…',
      child: Scaffold(
        appBar: const AppTopBar(title: 'Create Team'),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: AppSpacing.screen,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(label: '', tone: Tone.warning, icon: Icons.rocket_launch),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Launch a new startup team', style: context.text.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Set up your project idea and start recruiting teammates.',
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Founder info card
                if (student != null)
                  AppCard(
                    color: const Color(0xFFF0FDF4),
                    borderColor: const Color(0xFF86EFAC),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        MemberAvatar(
                          initials: student.initials,
                          avatarUrl: student.avatarUrl,
                          size: AppSize.avatar,
                          verified: true,
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
                                      student.fullName,
                                      style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const StatusBadge(label: 'Founder · Leader', tone: Tone.primary),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('${student.studentCode} · ${student.email}', style: context.text.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),

                // Gemini AI Advisor Card (Section 8: Level 2 Structured Draft)
                AppCard(
                  color: const Color(0xFFF0FDF4),
                  borderColor: const Color(0xFF86EFAC),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFF107C41), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Gemini Topic Advisor (AI Level 2)',
                            style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Generate structured topic summary, tags, and open roles without sending personal data. Fallback active.',
                        style: context.text.bodySmall?.copyWith(color: const Color(0xFF15803D)),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        key: const Key('btn_suggest_gemini_ai'),
                        onPressed: _isGeneratingAi ? null : _generateAiSuggestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF107C41),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: _isGeneratingAi
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(_isGeneratingAi ? 'Drafting proposal…' : '✨ Suggest with Gemini AI'),
                      ),
                      if (_aiDraftApplied) ...[
                        const SizedBox(height: 8),
                        const StatusBadge(label: 'AI Generated Draft · Editable', tone: Tone.neutral),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Team Name
                Text('Team Name *', style: context.text.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. EcoCharge, GreenRoute, EduSmart',
                    prefixIcon: const Icon(Icons.groups_outlined),
                    border: OutlineInputBorder(borderRadius: AppRadius.cardAll),
                    filled: true,
                    fillColor: context.colors.surfaceContainerLowest,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter a team name';
                    if (v.trim().length < 3) return 'Team name must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Topic / Elevator Pitch
                Text('Project Topic / Pitch *', style: context.text.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _topicController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Brief summary of the startup product or problem solving...',
                    prefixIcon: const Icon(Icons.lightbulb_outline),
                    border: OutlineInputBorder(borderRadius: AppRadius.cardAll),
                    filled: true,
                    fillColor: context.colors.surfaceContainerLowest,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please describe your project topic';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Detailed Description (Optional)
                Text('Detailed Description (Optional)', style: context.text.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Detailed project scope, architecture, or deliverables...',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(borderRadius: AppRadius.cardAll),
                    filled: true,
                    fillColor: context.colors.surfaceContainerLowest,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Category
                Text('Category / Track *', style: context.text.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final cat in CreateTeamViewModel.defaultCategories)
                      ChoiceChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedCategory = cat);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Open Roles Needed
                Row(
                  children: [
                    Expanded(child: Text('Looking for Roles', style: context.text.labelLarge)),
                    Text('${_selectedRoles.length} selected', style: context.text.bodySmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final role in CreateTeamViewModel.suggestedRoles)
                      FilterChip(
                        label: Text(role),
                        selected: _selectedRoles.contains(role),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedRoles.add(role);
                            } else {
                              _selectedRoles.remove(role);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Tech Stack / Tags
                Row(
                  children: [
                    Expanded(child: Text('Tech Stack & Skills', style: context.text.labelLarge)),
                    Text('${_selectedTags.length} tags', style: context.text.bodySmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final tag in CreateTeamViewModel.suggestedTags)
                      FilterChip(
                        label: Text(tag),
                        selected: _selectedTags.contains(tag),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Submit button
                AppButton(
                  semanticId: 'btn_submit_create_team',
                  label: 'Create Team & Recruit',
                  icon: Icons.rocket_launch,
                  loading: vm.creating,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
