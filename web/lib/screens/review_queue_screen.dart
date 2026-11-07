import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/admin_theme.dart';
import '../viewmodels/admin_session_viewmodel.dart';

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  final _service = TeamSubmissionService();
  String _query = '';
  String _filter = 'pending';

  Future<void> _decide(TeamSubmission item, bool approved) async {
    String reason = '';
    if (!approved) {
      final controller = TextEditingController();
      final submitted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Yêu cầu chỉnh sửa đội'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Lý do *',
              hintText: 'Ví dụ: Thiếu thông tin đề tài hoặc thành viên chưa hợp lệ.',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) Navigator.pop(dialogContext, true);
              },
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        ),
      );
      if (submitted != true) return;
      reason = controller.text;
    }

    try {
      await _service.decide(
        submission: item,
        adminId: context.read<AdminSessionViewModel>().firebaseUser!.uid,
        approved: approved,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(approved ? 'Đã duyệt ${item.teamName}.' : 'Đã gửi yêu cầu chỉnh sửa.')));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể lưu quyết định: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TeamSubmission>>(
    stream: _service.watchAll(),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const _ErrorState(message: 'Không thể tải hàng đợi. Kiểm tra quyền Admin Firestore.');
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final all = snapshot.data!;
      final query = _query.trim().toLowerCase();
      final items = all
          .where((item) {
            final matchesFilter = _filter == 'all' || item.status == _filter;
            final matchesQuery =
                query.isEmpty || '${item.teamName} ${item.lockCode} ${item.leaderId}'.toLowerCase().contains(query);
            return matchesFilter && matchesQuery;
          })
          .toList(growable: false);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 38, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Duyệt đội đã khóa', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Duyệt hoặc yêu cầu chỉnh sửa roster mà trưởng nhóm gửi từ ứng dụng sinh viên.',
              style: TextStyle(color: AdminPalette.muted),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QueueMetric(
                  label: 'Chờ duyệt',
                  value: all.where((item) => item.status == 'pending').length.toString(),
                  tone: AdminPalette.warning,
                ),
                _QueueMetric(
                  label: 'Đã duyệt',
                  value: all.where((item) => item.status == 'approved').length.toString(),
                  tone: AdminPalette.primary,
                ),
                _QueueMetric(
                  label: 'Cần chỉnh sửa',
                  value: all.where((item) => item.status == 'rejected').length.toString(),
                  tone: AdminPalette.danger,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (value) => setState(() => _query = value),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Tìm theo tên đội, mã khóa hoặc trưởng nhóm',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _filter,
                          onChanged: (value) => setState(() => _filter = value ?? 'pending'),
                          items: const [
                            DropdownMenuItem(value: 'pending', child: Text('Chờ duyệt')),
                            DropdownMenuItem(value: 'approved', child: Text('Đã duyệt')),
                            DropdownMenuItem(value: 'rejected', child: Text('Cần chỉnh sửa')),
                            DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(36),
                        child: Text(
                          'Không có đội nào trong trạng thái này.',
                          style: TextStyle(color: AdminPalette.muted),
                        ),
                      )
                    else
                      ...items.map(
                        (item) => _SubmissionRow(
                          item: item,
                          onApprove: item.isPending ? () => _decide(item, true) : null,
                          onReject: item.isPending ? () => _decide(item, false) : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _QueueMetric extends StatelessWidget {
  const _QueueMetric({required this.label, required this.value, required this.tone});
  final String label;
  final String value;
  final Color tone;
  @override
  Widget build(BuildContext context) => Container(
    width: 180,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AdminPalette.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AdminPalette.muted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: tone),
        ),
      ],
    ),
  );
}

class _SubmissionRow extends StatelessWidget {
  const _SubmissionRow({required this.item, this.onApprove, this.onReject});
  final TeamSubmission item;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final approved = item.status == 'approved';
    final rejected = item.status == 'rejected';
    final tone = approved
        ? AdminPalette.primary
        : rejected
        ? AdminPalette.danger
        : AdminPalette.warning;
    final label = approved
        ? 'Đã duyệt'
        : rejected
        ? 'Cần chỉnh sửa'
        : 'Chờ duyệt';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminPalette.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: tone.withValues(alpha: .13),
            foregroundColor: tone,
            child: Icon(
              approved
                  ? Icons.verified_outlined
                  : rejected
                  ? Icons.edit_note_outlined
                  : Icons.hourglass_top_outlined,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(item.teamName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    _StatusPill(label: label, tone: tone),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.memberSnapshot.length} thành viên · ${item.lockCode.isEmpty ? 'Không có mã khóa' : item.lockCode}',
                  style: const TextStyle(color: AdminPalette.muted),
                ),
                if (rejected && item.reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Lý do: ${item.reason}', style: const TextStyle(color: AdminPalette.danger)),
                  ),
              ],
            ),
          ),
          if (onReject != null) ...[
            OutlinedButton(
              onPressed: onReject,
              style: OutlinedButton.styleFrom(foregroundColor: AdminPalette.danger),
              child: const Text('Yêu cầu sửa'),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: onApprove, child: const Text('Duyệt')),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone});
  final String label;
  final Color tone;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: tone.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
    child: Text(
      label,
      style: TextStyle(color: tone, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, style: const TextStyle(color: AdminPalette.danger)),
    ),
  );
}
