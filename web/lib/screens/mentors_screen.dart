import 'package:core/core.dart' hide Tone;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../theme/admin_theme.dart';
import '../viewmodels/admin_mentor_viewmodel.dart';

/// Admin page for lecturers: who students can choose, each quota, and every
/// request teams have sent. Lecturers answer those requests on mobile.
class MentorsScreen extends StatelessWidget {
  const MentorsScreen({super.key, this.service});

  /// Replaced in tests; defaults to Firestore.
  final MentorAdminService? service;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AdminMentorViewModel(service ?? MentorAdminService())..load(),
    child: const MentorsView(),
  );
}

class MentorsView extends StatelessWidget {
  const MentorsView({super.key});

  Future<void> _edit(BuildContext context, [Mentor? mentor]) async {
    final vm = context.read<AdminMentorViewModel>();
    final result = await showDialog<Mentor>(context: context, builder: (_) => _MentorDialog(mentor: mentor));
    if (result == null) return;
    if (mentor == null) {
      await vm.create(result);
    } else {
      await vm.update(mentor, result);
    }
  }

  Future<void> _archive(BuildContext context, Mentor mentor) async {
    final vm = context.read<AdminMentorViewModel>();
    if (mentor.archived) {
      await vm.setArchived(mentor, false);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lưu trữ ${mentor.fullName}?'),
        content: const Text(
          'Sinh viên sẽ không còn thấy giảng viên này và tài khoản không vào được cổng giảng viên. '
          'Các nhóm đang hướng dẫn vẫn giữ nguyên.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu trữ')),
        ],
      ),
    );
    if (ok == true) await vm.setArchived(mentor, true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminMentorViewModel>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 38, 24, 48),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Giảng viên hướng dẫn', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text(
                    'Quản lý hồ sơ, quota và theo dõi yêu cầu từ các nhóm.',
                    style: TextStyle(color: AdminPalette.muted),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: vm.saving ? null : () => _edit(context),
              icon: const Icon(Icons.add),
              label: const Text('Thêm giảng viên'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (vm.error != null) _Message(text: vm.error!, color: AdminPalette.danger),
        if (vm.success != null) _Message(text: vm.success!, color: AdminPalette.primary),
        if (vm.loading)
          const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
        else if (vm.error != null && vm.mentors.isEmpty)
          Center(child: TextButton(onPressed: vm.load, child: const Text('Thử lại')))
        else ...[
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _Figure(label: 'Đang hoạt động', value: vm.activeCount),
              _Figure(label: 'Chỗ còn trống', value: vm.openSlots),
              _Figure(label: 'Yêu cầu đang chờ', value: vm.pendingCount),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  onChanged: vm.setQuery,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tìm theo tên, email, bộ môn, chuyên môn...',
                  ),
                ),
              ),
              FilterChip(
                label: const Text('Đã lưu trữ'),
                selected: vm.showArchived,
                onSelected: vm.setShowArchived,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (vm.visibleMentors.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Text(
                  vm.mentors.isEmpty
                      ? 'Chưa có giảng viên nào. Bấm "Thêm giảng viên" để bắt đầu.'
                      : 'Không có giảng viên phù hợp.',
                ),
              ),
            )
          else
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                for (final mentor in vm.visibleMentors)
                  _MentorCard(
                    mentor: mentor,
                    onEdit: vm.saving ? null : () => _edit(context, mentor),
                    onArchive: vm.saving ? null : () => _archive(context, mentor),
                  ),
              ],
            ),
          const SizedBox(height: 36),
          const Text('Yêu cầu từ các nhóm', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (vm.requests.isEmpty)
            const Card(
              child: Padding(padding: EdgeInsets.all(28), child: Text('Chưa có nhóm nào gửi yêu cầu.')),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final (i, request) in vm.requests.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    _RequestRow(request: request),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AdminPalette.muted)),
          ],
        ),
      ),
    ),
  );
}

class _MentorCard extends StatelessWidget {
  const _MentorCard({required this.mentor, required this.onEdit, required this.onArchive});
  final Mentor mentor;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 440,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mentor.archived ? 'Đã lưu trữ' : (mentor.isAvailable ? 'Còn nhận nhóm' : 'Đã đủ quota'),
              style: TextStyle(
                color: mentor.archived
                    ? AdminPalette.muted
                    : (mentor.isAvailable ? AdminPalette.primary : AdminPalette.warning),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(mentor.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(mentor.title, style: const TextStyle(color: AdminPalette.muted)),
            Text(mentor.email, style: const TextStyle(color: AdminPalette.muted)),
            const Divider(height: 28),
            Text('Bộ môn: ${mentor.department}'),
            Text('Chuyên môn: ${mentor.expertise.join(', ')}'),
            Text('Đang hướng dẫn ${mentor.currentAssigned}/${mentor.maxQuota} nhóm'),
            if (mentor.mentoredTeamNames.isNotEmpty) Text('Nhóm: ${mentor.mentoredTeamNames.join(', ')}'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onArchive, child: Text(mentor.archived ? 'Khôi phục' : 'Lưu trữ')),
                const SizedBox(width: 8),
                TextButton(onPressed: onEdit, child: const Text('Sửa')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});
  final MentorRequest request;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (request.status) {
      MentorRequestStatus.pending => ('Đang chờ', AdminPalette.warning),
      MentorRequestStatus.approved => ('Đã nhận', AdminPalette.primary),
      MentorRequestStatus.rejected => ('Từ chối', AdminPalette.danger),
    };
    final reason = request.decisionReason ?? '';
    return ListTile(
      title: Text('${request.teamName} → ${request.mentorName}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        'Gửi bởi ${request.senderName} · ${DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt)}'
        '${reason.isEmpty ? '' : '\nLý do: $reason'}',
      ),
      trailing: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

/// Returns the edited profile, or null when cancelled.
class _MentorDialog extends StatefulWidget {
  const _MentorDialog({this.mentor});
  final Mentor? mentor;

  @override
  State<_MentorDialog> createState() => _MentorDialogState();
}

class _MentorDialogState extends State<_MentorDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.mentor?.fullName);
  late final _email = TextEditingController(text: widget.mentor?.email);
  late final _title = TextEditingController(text: widget.mentor?.title);
  late final _department = TextEditingController(text: widget.mentor?.department);
  late final _expertise = TextEditingController(text: widget.mentor?.expertise.join(', '));
  late final _office = TextEditingController(text: widget.mentor?.office);
  late final _bio = TextEditingController(text: widget.mentor?.bio);
  late final _quota = TextEditingController(text: '${widget.mentor?.maxQuota ?? 5}');

  @override
  void dispose() {
    for (final c in [_name, _email, _title, _department, _expertise, _office, _bio, _quota]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) => (value ?? '').trim().isEmpty ? 'Không được để trống' : null;

  String? _validEmail(String? value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((value ?? '').trim()) ? null : 'Email không hợp lệ';

  String? _validQuota(String? value) {
    final quota = int.tryParse((value ?? '').trim());
    return quota == null || quota < 1 ? 'Quota phải là số từ 1 trở lên' : null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      Mentor(
        id: widget.mentor?.id ?? '',
        fullName: _name.text.trim(),
        email: _email.text.trim().toLowerCase(),
        title: _title.text.trim(),
        department: _department.text.trim(),
        expertise: _expertise.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        bio: _bio.text.trim(),
        office: _office.text.trim(),
        maxQuota: int.parse(_quota.text.trim()),
        currentAssigned: widget.mentor?.currentAssigned ?? 0,
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {String? Function(String?)? check, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          validator: check,
          maxLines: lines,
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.mentor == null ? 'Thêm giảng viên' : 'Sửa giảng viên'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_name, 'Họ tên', check: _required),
              _field(_email, 'Email đăng nhập Google', check: _validEmail),
              _field(_title, 'Chức danh', check: _required),
              _field(_department, 'Bộ môn', check: _required),
              _field(_expertise, 'Chuyên môn (cách nhau bằng dấu phẩy)', check: _required),
              _field(_office, 'Phòng làm việc'),
              _field(_bio, 'Giới thiệu', lines: 3),
              _field(_quota, 'Quota (số nhóm tối đa)', check: _validQuota),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
      FilledButton(onPressed: _save, child: const Text('Lưu')),
    ],
  );
}
