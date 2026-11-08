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
            const SectionHeader(title: 'Vai trò & Kỹ năng Capstone'),
            const SizedBox(height: AppSpacing.md),
            _RoleSkillsCard(student: s),
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

class _RoleSkillsCard extends StatelessWidget {
  const _RoleSkillsCard({required this.student});
  final dynamic student;

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditRoleSkillsSheet(student: student),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = student.role as String;
    final skills = (student.skills as List<dynamic>).map((e) => e.toString()).toList();
    final major = student.major as String;

    return AppCard(
      semanticId: 'card_role_skills',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chuyên ngành: ${major.isNotEmpty ? major : "Chưa chọn"}',
                        style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      'Vai trò và ngôn ngữ thế mạnh giúp nhóm và mentor ghép đội hiệu quả hơn.',
                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Chỉnh sửa vai trò & kỹ năng',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _openEditSheet(context),
              ),
            ],
          ),
          const Divider(height: 24),
          Text('VAI TRÒ TRONG NHÓM', style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
          const SizedBox(height: 6),
          if (role.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF93C5FD), width: 1),
              ),
              child: Text(
                role,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
              ),
            )
          else
            const Text('Chưa chọn vai trò mục tiêu', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8))),
          const SizedBox(height: 14),
          Text('NGÔN NGỮ & KỸ NĂNG THẾ MẠNH', style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
          const SizedBox(height: 6),
          if (skills.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in skills)
                  StatusBadge(label: s, tone: Tone.neutral),
              ],
            )
          else
            const Text('Chưa chọn kỹ năng/ngôn ngữ', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8))),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _openEditSheet(context),
            icon: const Icon(Icons.tune_outlined, size: 16),
            label: const Text('Cập nhật vai trò & ngôn ngữ thế mạnh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.primary,
              side: BorderSide(color: context.colors.primary),
              minimumSize: const Size(double.infinity, 38),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditRoleSkillsSheet extends StatefulWidget {
  const _EditRoleSkillsSheet({required this.student});
  final dynamic student;

  @override
  State<_EditRoleSkillsSheet> createState() => _EditRoleSkillsSheetState();
}

class _EditRoleSkillsSheetState extends State<_EditRoleSkillsSheet> {
  late String _selectedMajor;
  late String _selectedRole;
  late List<String> _selectedSkills;
  bool _saving = false;

  static const _majorConfig = <String, ({List<String> roles, List<String> skills})>{
    'Kỹ thuật phần mềm (SE)': (
      roles: ['Fullstack Dev', 'Backend Dev', 'Frontend Dev', 'Mobile Dev', 'DevOps Engineer', 'QA / Tester'],
      skills: [
        'Flutter', 'React', 'React Native', 'TypeScript', 'Java', 'Spring Boot',
        'C#', '.NET Core', 'Python', 'Node.js', 'Go', 'PostgreSQL', 'MongoDB', 'Docker',
      ],
    ),
    'Trí tuệ nhân tạo (AI)': (
      roles: ['AI Engineer', 'Machine Learning Engineer', 'Data Scientist', 'Data Analyst', 'Computer Vision'],
      skills: [
        'Python', 'PyTorch', 'TensorFlow', 'OpenCV', 'Scikit-learn', 'LangChain',
        'Pandas', 'FastAPI', 'Hugging Face', 'SQL',
      ],
    ),
    'An toàn thông tin (IA)': (
      roles: ['Security Engineer', 'Penetration Tester', 'SOC Analyst', 'Network Security', 'Cloud Security'],
      skills: [
        'Python', 'Linux', 'Bash', 'C/C++', 'Wireshark', 'Cryptography',
        'Metasploit', 'OWASP', 'Docker', 'Network Security',
      ],
    ),
    'Thiết kế mỹ thuật số (GD)': (
      roles: ['UI/UX Designer', 'Product Designer', 'Graphic Designer', '3D / Motion Designer'],
      skills: [
        'Figma', 'Adobe XD', 'Photoshop', 'Illustrator', 'After Effects', 'Blender', 'Design Systems',
      ],
    ),
    'Quản trị kinh doanh & Marketing (IB/MKT)': (
      roles: ['Team Leader / PO', 'Business Analyst (BA)', 'Project Manager (PM)', 'Digital Marketer', 'Content Creator'],
      skills: [
        'Business Analysis', 'Agile/Scrum', 'Jira/Trello', 'Market Research', 'SEO/SEM', 'Google Analytics', 'Financial Modeling',
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    final currentMajor = widget.student.major as String? ?? '';
    _selectedMajor = _majorConfig.keys.firstWhere(
      (m) => currentMajor.isNotEmpty && m.toLowerCase().contains(currentMajor.toLowerCase().split(' ').first),
      orElse: () => _majorConfig.keys.first,
    );
    _selectedRole = (widget.student.role as String? ?? '').isNotEmpty
        ? widget.student.role as String
        : (_majorConfig[_selectedMajor]?.roles.first ?? 'Fullstack Dev');
    _selectedSkills = List<String>.from((widget.student.skills as List<dynamic>? ?? []).map((e) => e.toString()));
  }

  void _onMajorChanged(String major) {
    setState(() {
      _selectedMajor = major;
      final config = _majorConfig[major];
      if (config != null && !config.roles.contains(_selectedRole)) {
        _selectedRole = config.roles.first;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<SessionViewModel>().updateStudentProfile(
            major: _selectedMajor,
            role: _selectedRole,
            skills: _selectedSkills,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật vai trò & ngôn ngữ thành công!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _majorConfig[_selectedMajor] ?? _majorConfig.values.first;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chọn Vai trò & Kỹ năng theo ngành', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Tùy biến hồ sơ năng lực của bạn trong dự án khởi nghiệp',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Text('1. CHỌN CHUYÊN NGÀNH ĐÀO TẠO',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final major in _majorConfig.keys)
                      ChoiceChip(
                        label: Text(major, style: TextStyle(fontSize: 12, fontWeight: _selectedMajor == major ? FontWeight.bold : FontWeight.normal)),
                        selected: _selectedMajor == major,
                        onSelected: (_) => _onMajorChanged(major),
                        selectedColor: const Color(0xFFDCFCE7),
                        side: BorderSide(color: _selectedMajor == major ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('2. CHỌN VAI TRÒ MỤC TIÊU TRONG NHÓM',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in config.roles)
                      ChoiceChip(
                        label: Text(r, style: TextStyle(fontSize: 12.5, fontWeight: _selectedRole == r ? FontWeight.bold : FontWeight.normal)),
                        selected: _selectedRole == r,
                        onSelected: (_) => setState(() => _selectedRole = r),
                        selectedColor: const Color(0xFFDBEAFE),
                        side: BorderSide(color: _selectedRole == r ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('3. CHỌN NGÔN NGỮ & KỸ NĂNG THẾ MẠNH (Chọn nhiều)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in config.skills)
                      FilterChip(
                        label: Text(skill, style: TextStyle(fontSize: 12, fontWeight: _selectedSkills.contains(skill) ? FontWeight.bold : FontWeight.normal)),
                        selected: _selectedSkills.contains(skill),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSkills.add(skill);
                            } else {
                              _selectedSkills.remove(skill);
                            }
                          });
                        },
                        selectedColor: const Color(0xFFDCFCE7),
                        checkmarkColor: const Color(0xFF16A34A),
                        side: BorderSide(color: _selectedSkills.contains(skill) ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Lưu thông tin hồ sơ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
