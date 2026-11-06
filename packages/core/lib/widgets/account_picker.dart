import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'status.dart';

/// "Choose an account" sheet used by the local auth service to mirror the
/// Google account picker. Returns the chosen e-mail, or null when dismissed.
Future<String?> showAccountPicker(BuildContext context, List<({String email, String name})> accounts) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Image.asset('assets/brand/logo.png', width: 48, height: 48)),
            const SizedBox(height: AppSpacing.md),
            Semantics(header: true, child: Text('Choose an account', style: context.text.titleLarge)),
            const SizedBox(height: AppSpacing.xs),
            Text('to continue to EXEMatching', style: context.text.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            for (final a in accounts)
              Semantics(
                identifier: 'account_${a.email}',
                button: true,
                label: '${a.name}, ${a.email}',
                excludeSemantics: true,
                child: ListTile(
                  minTileHeight: 64,
                  contentPadding: EdgeInsets.zero,
                  leading: MemberAvatar(initials: a.name.substring(0, 1)),
                  title: Text(a.name),
                  subtitle: Text(a.email),
                  onTap: () => Navigator.of(context).pop(a.email),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
