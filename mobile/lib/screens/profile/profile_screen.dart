import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/status.dart';

/// Profile (screen added in Lab 3, DV-08): account, team summary export and
/// upload, Remote Config values, crash reporting checks, sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final ok = await showAppDialog(
      context,
      semanticId: 'dialog_sign_out',
      icon: Icons.logout,
      destructive: true,
      title: 'Sign out?',
      message: 'Your team and votes stay saved. Sign in again with your @fpt.edu.vn account.',
      confirmLabel: 'Sign Out',
    );
    if (ok && context.mounted) await context.read<SessionViewModel>().signOut();
  }

  Future<void> _refreshConfig(BuildContext context) async {
    final changed = await context.read<ProfileViewModel>().refreshConfig();
    if (!context.mounted) return;
    final failure = context.read<ProfileViewModel>().configRefreshFailure;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure != null
              ? 'Could not update settings. Using the saved settings instead.'
              : changed == true
              ? 'Settings updated from the server'
              : 'Settings are already up to date',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final s = vm.student;
    return Scaffold(
      appBar: const AppTopBar(title: 'Profile'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: AppSpacing.screen,
          children: [
            AppCard(
              semanticId: 'card_account',
              child: Row(
                children: [
                  MemberAvatar(initials: s.initials, avatarUrl: s.avatarUrl, size: 56),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.fullName, style: context.text.titleMedium),
                        Text(s.email, style: context.text.bodyMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text('${s.studentCode} · ${s.major} · ${s.cohort}', style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Team summary'),
            const SizedBox(height: AppSpacing.md),
            _ExportCard(state: vm.export, onExport: vm.exportAndUpload),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'App settings'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              semanticId: 'card_remote_config',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Values the server can change without an app update.', style: context.text.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  for (final e in vm.configValues.entries)
                    Semantics(
                      identifier: 'config_${e.key}',
                      label: '${e.key}: ${e.value}',
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(child: Text(e.key, style: context.text.bodyMedium)),
                            StatusBadge(label: e.value),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    semanticId: 'btn_refresh_config',
                    label: 'Check for Updates',
                    icon: Icons.sync,
                    variant: AppButtonVariant.secondary,
                    loading: vm.refreshingConfig,
                    onPressed: () => _refreshConfig(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Diagnostics'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              semanticId: 'card_diagnostics',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Send test reports to check that crash reporting works.', style: context.text.bodyMedium),
                  if (vm.crashMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    InfoBanner(semanticId: 'crash_message', tone: Tone.success, title: vm.crashMessage!),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    semanticId: 'btn_send_non_fatal',
                    label: 'Send Test Error',
                    variant: AppButtonVariant.secondary,
                    onPressed: vm.sendNonFatal,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    semanticId: 'btn_test_crash',
                    label: 'Force Test Crash',
                    icon: Icons.error_outline,
                    backgroundColor: const Color(0xFFFEE2E2),
                    foregroundColor: const Color(0xFFDC2626),
                    borderColor: const Color(0xFFFCA5A5),
                    onPressed: () async {
                      final ok = await showAppDialog(
                        context,
                        semanticId: 'dialog_test_crash',
                        destructive: true,
                        title: 'Close the app with a test crash?',
                        message: 'The app closes now. Open it again to send the crash report.',
                        confirmLabel: 'Crash App',
                      );
                      if (ok) await vm.testCrash();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              semanticId: 'btn_sign_out',
              label: 'Sign Out',
              icon: Icons.logout,
              variant: AppButtonVariant.destructive,
              onPressed: () => _signOut(context),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.state, required this.onExport});

  final ExportState state;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final busy = state is ExportGenerating || state is ExportUploading;
    return AppCard(
      semanticId: 'card_export',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create a PDF of your team, its status and roster, then save it to your account.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          switch (state) {
            ExportIdle() => const SizedBox.shrink(),
            ExportGenerating() => const AppProgressBar(value: 0, label: 'Creating PDF…'),
            ExportUploading(:final fraction, :final fileName, :final sizeKb) => Semantics(
              identifier: 'export_progress',
              child: AppProgressBar(
                value: fraction,
                label: 'Uploading $fileName · $sizeKb KB · ${(fraction * 100).round()}%',
              ),
            ),
            ExportDone(:final url, :final fileName, :final sizeKb) => InfoBanner(
              semanticId: 'export_done',
              tone: Tone.success,
              title: 'Uploaded $fileName · $sizeKb KB',
              message: 'Saved to your account. Download link:',
              action: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 16, color: Color(0xFF047857)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: const Color(0xFF047857),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: const Color(0xFF047857),
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Download link copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ExportFailed(:final failure) => InfoBanner(
              semanticId: 'export_failed',
              tone: Tone.error,
              title: failure.title,
              message: failure.cause,
            ),
          },
          if (state is! ExportIdle) const SizedBox(height: AppSpacing.md),
          AppButton(
            semanticId: 'btn_export_upload',
            label: state is ExportDone ? 'Export Again' : 'Export & Upload PDF',
            icon: Icons.picture_as_pdf,
            loading: busy,
            onPressed: onExport,
          ),
        ],
      ),
    );
  }
}
