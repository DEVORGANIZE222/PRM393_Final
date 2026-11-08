import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/admin_theme.dart';
import '../viewmodels/admin_session_viewmodel.dart';

/// EdTech SaaS Review Queue — ExeMatching
/// Matches C:\Users\Administrator\Desktop\EXETeamMatching\fe\src\features\mentors\MentorRequestsPage.jsx
/// Reviews locked teams, capstone topic proposals, approval with quota tracking, and revision feedback.
class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  final _service = TeamSubmissionService();
  String _query = '';
  String _filter = 'pending'; // 'pending' | 'approved' | 'rejected' | 'all'

  Future<void> _decide(TeamSubmission item, bool approved) async {
    String reason = '';
    if (!approved) {
      final controller = TextEditingController();
      final submitted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.edit_note, color: AdminPalette.danger),
              SizedBox(width: 8),
              Text('Yêu cầu chỉnh sửa đề tài & đội'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhập lý do hoặc hướng dẫn để nhóm "${item.teamName}" chỉnh sửa trên ứng dụng mobile:',
                style: const TextStyle(fontSize: 13, color: AdminPalette.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Lý do / Hướng dẫn chỉnh sửa *',
                  hintText: 'Ví dụ: Đề tài quá rộng, cần thu hẹp phạm vi hoặc bổ sung thành viên Backend.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AdminPalette.danger),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) Navigator.pop(dialogContext, true);
              },
              child: const Text('Gửi yêu cầu chỉnh sửa'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approved
                  ? 'Đã duyệt đề tài & danh sách nhóm ${item.teamName}. Trạng thái trên mobile đã cập nhật thành Approved.'
                  : 'Đã gửi yêu cầu chỉnh sửa cho nhóm ${item.teamName}.',
            ),
            backgroundColor: approved ? AdminPalette.primary : AdminPalette.danger,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lưu quyết định: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TeamSubmission>>(
        stream: _service.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _ErrorState(message: 'Không thể tải hàng đợi duyệt. Kiểm tra quyền Admin Firestore.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AdminPalette.primary));
          }

          final all = snapshot.data!;
          final countPending = all.where((item) => item.status == 'pending').length;
          final countApproved = all.where((item) => item.status == 'approved').length;
          final countRejected = all.where((item) => item.status == 'rejected').length;

          final query = _query.trim().toLowerCase();
          final items = all.where((item) {
            final matchesFilter = _filter == 'all' || item.status == _filter;
            final matchesQuery = query.isEmpty ||
                '${item.teamName} ${item.lockCode} ${item.leaderId}'.toLowerCase().contains(query);
            return matchesFilter && matchesQuery;
          }).toList(growable: false);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Page Header & Quota Box ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hồ sơ Đề tài & Duyệt nhóm đã khóa',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AdminPalette.ink,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Xem xét các ý tưởng khởi nghiệp sinh viên gửi tới, đánh giá tính khả thi và quyết định phê duyệt theo quy chuẩn học kỳ.',
                            style: TextStyle(fontSize: 14, color: AdminPalette.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Quota Mini Indicator Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AdminPalette.border),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'KHỐI LƯỢNG CHỜ DUYỆT',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AdminPalette.muted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$countPending nhóm',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminPalette.ink),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: countPending == 0 ? AdminPalette.primaryLight : AdminPalette.warningLight,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: countPending == 0 ? AdminPalette.primaryBorder : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Text(
                              countPending == 0 ? 'Đã duyệt hết' : 'Cần xử lý',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: countPending == 0 ? AdminPalette.primary : AdminPalette.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Filter Tabs & Search Bar ──
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AdminPalette.subtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FilterPill(
                            label: 'Chờ duyệt',
                            count: countPending,
                            active: _filter == 'pending',
                            badgeColor: AdminPalette.warning,
                            badgeBg: AdminPalette.warningLight,
                            onTap: () => setState(() => _filter = 'pending'),
                          ),
                          _FilterPill(
                            label: 'Đã chấp thuận',
                            count: countApproved,
                            active: _filter == 'approved',
                            badgeColor: AdminPalette.primary,
                            badgeBg: AdminPalette.primaryLight,
                            onTap: () => setState(() => _filter = 'approved'),
                          ),
                          _FilterPill(
                            label: 'Cần chỉnh sửa',
                            count: countRejected,
                            active: _filter == 'rejected',
                            badgeColor: AdminPalette.danger,
                            badgeBg: AdminPalette.dangerLight,
                            onTap: () => setState(() => _filter = 'rejected'),
                          ),
                          _FilterPill(
                            label: 'Tất cả',
                            count: all.length,
                            active: _filter == 'all',
                            badgeColor: AdminPalette.muted,
                            badgeBg: AdminPalette.subtle,
                            onTap: () => setState(() => _filter = 'all'),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        onChanged: (value) => setState(() => _query = value),
                        style: const TextStyle(fontSize: 13.5),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search, size: 20),
                          hintText: 'Tìm theo tên đội, mã khóa, trưởng nhóm...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Submissions List / Cards ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(48),
                            child: Center(
                              child: Column(
                                children: const [
                                  Icon(Icons.inbox_outlined, size: 40, color: AdminPalette.slate400),
                                  SizedBox(height: 12),
                                  Text(
                                    'Không có nhóm nào trong danh mục này.',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: AdminPalette.muted),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...items.map(
                            (item) => _SubmissionCard(
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.active,
    required this.badgeColor,
    required this.badgeBg,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final Color badgeColor, badgeBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: active
                ? const [
                    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AdminPalette.ink : AdminPalette.muted,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.item, this.onApprove, this.onReject});

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
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminPalette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Circle
              CircleAvatar(
                radius: 18,
                backgroundColor: tone.withValues(alpha: .12),
                foregroundColor: tone,
                child: Icon(
                  approved
                      ? Icons.check_circle_outline
                      : rejected
                          ? Icons.highlight_off_outlined
                          : Icons.hourglass_top_outlined,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.teamName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AdminPalette.ink),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tone.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(color: tone, fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (item.lockCode.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AdminPalette.subtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Mã khóa: ${item.lockCode}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AdminPalette.muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        final leaderMember = item.memberSnapshot.where((m) {
                          final mid = m['studentId'] ?? m['id'] ?? m['userId'] ?? m['uid'] ?? m['studentCode'] ?? m['email'];
                          return mid == item.leaderId || m['role'] == 'Team Lead' || m['role'] == 'Leader' || m['isLeader'] == true;
                        }).firstOrNull;
                        final leaderName = leaderMember?['fullName']?.toString() ??
                            leaderMember?['name']?.toString() ??
                            (item.leaderId.isNotEmpty ? item.leaderId : 'Chưa bầu');
                        return Text(
                          'Trưởng nhóm: $leaderName · Thành viên: ${item.memberSnapshot.length}/5 sinh viên',
                          style: const TextStyle(fontSize: 13, color: AdminPalette.muted),
                        );
                      },
                    ),
                    // Roster Chips
                    if (item.memberSnapshot.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: item.memberSnapshot.map((m) {
                          final name = m['name']?.toString() ?? m['fullName']?.toString() ?? 'TV';
                          final role = m['role']?.toString() ?? 'Thành viên';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AdminPalette.hover,
                              border: Border.all(color: AdminPalette.border),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$name ($role)',
                              style: const TextStyle(fontSize: 11.5, color: AdminPalette.ink),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    // Feedback note if rejected
                    if (rejected && item.reason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AdminPalette.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AdminPalette.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lý do yêu cầu sửa: ${item.reason}',
                                style: const TextStyle(fontSize: 12.5, color: AdminPalette.danger, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Action Buttons
              if (onApprove != null || onReject != null) ...[
                OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminPalette.danger,
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: const Text('Yêu cầu sửa'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Chấp thuận'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminPalette.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message, style: const TextStyle(color: AdminPalette.danger, fontWeight: FontWeight.w600)),
        ),
      );
}
