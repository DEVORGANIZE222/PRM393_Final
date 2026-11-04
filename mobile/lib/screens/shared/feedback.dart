import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/view_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_button.dart';

/// One snackbar format for every failed action: what happened, then what to do.
void showFailure(BuildContext context, AppFailure failure) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${failure.title}. ${failure.cause}')));
}

/// Empty state for team screens opened by a student who has no team.
class NoTeamState extends StatelessWidget {
  const NoTeamState({super.key, this.message = 'Browse teams with open slots or create your own startup team before the deadline.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: AppSize.illustration / 2,
            backgroundColor: context.colors.primaryContainer,
            child: Icon(Icons.group_off_outlined, size: 48, color: context.colors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text("You're not in a team yet", style: context.text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Browse Teams', icon: Icons.search, onPressed: () => context.go('/browse'), semanticId: 'empty_action'),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Create a Team',
            icon: Icons.group_add,
            backgroundColor: const Color(0xFFFFF7ED),
            foregroundColor: const Color(0xFFC2410C),
            borderColor: const Color(0xFFF97316),
            onPressed: () => context.push('/create-team'),
            semanticId: 'btn_create_team_empty',
          ),
        ],
      ),
    );
  }
}
