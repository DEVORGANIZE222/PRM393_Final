import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

class MentorManagementScreen extends StatefulWidget {
  const MentorManagementScreen({super.key});

  @override
  State<MentorManagementScreen> createState() => _MentorManagementScreenState();
}

class _MentorManagementScreenState extends State<MentorManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _filterStatus = 'all'; // 'all' | 'available' | 'full'
  String _search = '';

  String? _message;
  bool _messageIsError = false;

  void _showMessage(String text, {bool isError = false}) {
    setState(() {
      _message = text;
      _messageIsError = isError;
    });
  }

  Future<void> _openEditQuota(Mentor mentor) async {
    final newQuota = await showDialog<int>(
      context: context,
      builder: (ctx) => _EditQuotaDialog(mentor: mentor),
    );
    if (newQuota == null) return;

    try {
      await _db.collection('mentors').doc(mentor.id).update({
        'maxQuota': newQuota,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showMessage('Đã cập nhật hạn ngạch của ${mentor.fullName} thành $newQuota nhóm.');
    } catch (e) {
      _showMessage('Không thể cập nhật hạn ngạch: $e', isError: true);
    }
  }

  Future<void> _openAddMentor() async {
    final mentorData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const _AddMentorDialog(),
    );
    if (mentorData == null) return;

    try {
      final docRef = _db.collection('mentors').doc();
      final batch = _db.batch();

      batch.set(docRef, {
        ...mentorData,
        'currentAssigned': 0,
        'mentoredTeamNames': <String>[],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Synchronize into allowedEmails so this mentor can immediately log into the mobile app
      final email = (mentorData['email'] as String).trim().toLowerCase();
      if (email.isNotEmpty) {
        batch.set(_db.collection('allowedEmails').doc(email), {
          'email': email,
          'enabled': true,
          'mentorId': docRef.id,
          'fullName': mentorData['fullName'],
          'role': 'mentor',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      _showMessage('Đã thêm giảng viên "${mentorData['fullName']}" vào danh sách học kỳ thành công!');
    } catch (e) {
      _showMessage('Không thể thêm giảng viên: $e', isError: true);
    }
  }

  Future<void> _archiveMentor(Mentor mentor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận lưu trữ giảng viên'),
        content: Text('Bạn có chắc muốn lưu trữ giảng viên "${mentor.fullName}"? Giảng viên này sẽ không xuất hiện trong danh sách chọn của sinh viên nữa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AdminPalette.danger),
            child: const Text('Lưu trữ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _db.collection('mentors').doc(mentor.id).update({
        'status': mentor.archived ? 'active' : 'archived',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showMessage('Đã cập nhật trạng thái giảng viên ${mentor.fullName}.');
    } catch (e) {
      _showMessage('Thao tác thất bại: $e', isError: true);
    }
  }

  Future<void> _deleteMentor(Mentor mentor) async {
    final hasTeams = mentor.currentAssigned > 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa giảng viên', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          hasTeams
              ? 'CẢNH BÁO: Giảng viên "${mentor.fullName}" hiện đang hướng dẫn ${mentor.currentAssigned} nhóm (${mentor.mentoredTeamNames.join(", ")}).\n\nBạn có chắc chắn muốn xóa vĩnh viễn giảng viên này khỏi hệ thống học kỳ?'
              : 'Bạn có chắc chắn muốn xóa vĩnh viễn giảng viên "${mentor.fullName}" khỏi danh sách? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy bỏ')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AdminPalette.danger),
            child: const Text('Xóa giảng viên'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final batch = _db.batch();
      batch.delete(_db.collection('mentors').doc(mentor.id));
      if (mentor.email.isNotEmpty) {
        batch.delete(_db.collection('allowedEmails').doc(mentor.email.trim().toLowerCase()));
      }
      await batch.commit();
      _showMessage('Đã xóa vĩnh viễn giảng viên "${mentor.fullName}" khỏi hệ thống.');
    } catch (e) {
      _showMessage('Không thể xóa giảng viên: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('mentors').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Lỗi tải danh sách giảng viên: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        final mentors = docs.map((doc) => Mentor.fromJson({...doc.data(), 'id': doc.id})).toList();

        // Summary metrics
        final totalMentors = mentors.length;
        final totalMaxQuota = mentors.fold<int>(0, (sum, m) => sum + m.maxQuota);
        final totalAssigned = mentors.fold<int>(0, (sum, m) => sum + m.currentAssigned);
        final totalRemaining = (totalMaxQuota - totalAssigned).clamp(0, totalMaxQuota);
        final overallPercentage = totalMaxQuota > 0 ? ((totalAssigned / totalMaxQuota) * 100).round() : 0;

        // Filter & Search
        final q = _search.trim().toLowerCase();
        final filteredMentors = mentors.where((m) {
          final isFull = m.currentAssigned >= m.maxQuota;
          final matchesStatus = switch (_filterStatus) {
            'available' => !isFull,
            'full' => isFull,
            _ => true,
          };
          final matchesSearch = q.isEmpty ||
              m.fullName.toLowerCase().contains(q) ||
              m.email.toLowerCase().contains(q) ||
              m.department.toLowerCase().contains(q) ||
              m.expertise.any((e) => e.toLowerCase().contains(q));
          return matchesStatus && matchesSearch;
        }).toList();

        final countAvailable = mentors.where((m) => m.currentAssigned < m.maxQuota).length;
        final countFull = mentors.where((m) => m.currentAssigned >= m.maxQuota).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification Banner
              if (_message != null) ...[
                _TopBanner(
                  message: _message!,
                  isError: _messageIsError,
                  onClose: () => setState(() => _message = null),
                ),
                const SizedBox(height: 20),
              ],

              // Page Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quản lý Giảng viên Mentor & Quota',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AdminPalette.ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Điều phối danh sách cố vấn khởi nghiệp, cấu hình hạn ngạch tối đa và giám sát tỷ lệ nhận nhóm trong học kỳ Khởi nghiệp EXE.',
                          style: TextStyle(fontSize: 14, color: AdminPalette.muted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openAddMentor,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm Mentor mới'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminPalette.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Metrics Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth > 900
                      ? (constraints.maxWidth - 3 * 16) / 4
                      : (constraints.maxWidth - 16) / 2;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.school_outlined,
                        iconColor: AdminPalette.primary,
                        iconBg: AdminPalette.primaryLight,
                        label: 'Tổng số Mentor',
                        value: '$totalMentors giảng viên',
                        subtext: 'Đã phân bổ cho học kỳ',
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.groups_outlined,
                        iconColor: const Color(0xFF0F766E),
                        iconBg: const Color(0xFFCCFBF1),
                        label: 'Tổng hạn ngạch (Max Quota)',
                        value: '$totalMaxQuota nhóm',
                        subtext: 'Hạn mức toàn trường',
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.check_circle_outline,
                        iconColor: const Color(0xFFB26A00),
                        iconBg: const Color(0xFFFEF3C7),
                        label: 'Đã được nhận',
                        value: '$totalAssigned nhóm',
                        subtext: '$overallPercentage% tỷ lệ lấp đầy',
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.auto_awesome_outlined,
                        iconColor: const Color(0xFF475569),
                        iconBg: const Color(0xFFF1F5F9),
                        label: 'Suất trống toàn trường',
                        value: '$totalRemaining suất',
                        subtext: 'Sẵn sàng ghép thêm nhóm',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // Filter Tabs & Search Bar
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AdminPalette.subtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminPalette.border),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FilterTabPill(
                          label: 'Tất cả ($totalMentors)',
                          active: _filterStatus == 'all',
                          onTap: () => setState(() => _filterStatus = 'all'),
                        ),
                        _FilterTabPill(
                          label: 'Còn nhận nhóm ($countAvailable)',
                          active: _filterStatus == 'available',
                          badgeColor: const Color(0xFFDCFCE7),
                          badgeTextColor: const Color(0xFF15803D),
                          onTap: () => setState(() => _filterStatus = 'available'),
                        ),
                        _FilterTabPill(
                          label: 'Đã đủ Quota ($countFull)',
                          active: _filterStatus == 'full',
                          badgeColor: const Color(0xFFF1F5F9),
                          badgeTextColor: const Color(0xFF64748B),
                          onTap: () => setState(() => _filterStatus = 'full'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    height: 40,
                    child: TextField(
                      onChanged: (val) => setState(() => _search = val),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 18, color: AdminPalette.muted),
                        hintText: 'Tìm theo tên, email, chuyên môn...',
                        hintStyle: const TextStyle(fontSize: 13, color: AdminPalette.muted),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminPalette.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminPalette.border),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Mentors Grid
              if (filteredMentors.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminPalette.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.school_outlined, size: 42, color: AdminPalette.muted),
                      SizedBox(height: 12),
                      Text(
                        'Không tìm thấy giảng viên nào',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AdminPalette.ink),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Thử thay đổi từ khóa tìm kiếm hoặc bộ lọc trạng thái.',
                        style: TextStyle(fontSize: 13, color: AdminPalette.muted),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: filteredMentors.map((mentor) {
                    return _MentorCard(
                      mentor: mentor,
                      onEditQuota: () => _openEditQuota(mentor),
                      onArchive: () => _archiveMentor(mentor),
                      onDelete: () => _deleteMentor(mentor),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.subtext,
  });

  final double width;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminPalette.border),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminPalette.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AdminPalette.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTabPill extends StatelessWidget {
  const _FilterTabPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeColor,
    this.badgeTextColor,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? badgeColor;
  final Color? badgeTextColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? const [BoxShadow(color: Color(0x0E000000), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AdminPalette.ink : AdminPalette.muted,
          ),
        ),
      ),
    );
  }
}

class _MentorCard extends StatelessWidget {
  const _MentorCard({
    required this.mentor,
    required this.onEditQuota,
    required this.onArchive,
    required this.onDelete,
  });

  final Mentor mentor;
  final VoidCallback onEditQuota;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isFull = mentor.currentAssigned >= mentor.maxQuota;
    final percent = mentor.maxQuota > 0
        ? ((mentor.currentAssigned / mentor.maxQuota) * 100).round().clamp(0, 100)
        : 0;
    final openSlots = (mentor.maxQuota - mentor.currentAssigned).clamp(0, mentor.maxQuota);

    final progressColor = isFull
        ? const Color(0xFF94A3B8)
        : (percent >= 75 ? const Color(0xFFF59E0B) : AdminPalette.primary);

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminPalette.border),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Avatar + Name + Dept + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AdminPalette.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Center(
                  child: Text(
                    mentor.initials,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AdminPalette.primaryDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mentor.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AdminPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mentor.department,
                      style: const TextStyle(fontSize: 12, color: AdminPalette.muted),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.mail_outline, size: 13, color: AdminPalette.muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            mentor.email,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isFull ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: isFull ? const Color(0xFFE2E8F0) : const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  isFull ? 'Đã đủ' : 'Còn $openSlots suất',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isFull ? const Color(0xFF64748B) : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Expertise
          const Text(
            'Chuyên môn cố vấn:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminPalette.muted),
          ),
          const SizedBox(height: 4),
          Text(
            mentor.expertise.isNotEmpty ? mentor.expertise.join(', ') : mentor.bio,
            style: const TextStyle(fontSize: 12.5, color: AdminPalette.ink, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Quota Mini Stat Widget
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminPalette.subtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hạn ngạch nhận nhóm:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${mentor.currentAssigned}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isFull ? const Color(0xFF64748B) : AdminPalette.primary,
                            ),
                          ),
                          TextSpan(
                            text: ' / ${mentor.maxQuota} nhóm',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AdminPalette.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percent / 100.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tỷ lệ: $percent%', style: const TextStyle(fontSize: 11, color: AdminPalette.muted)),
                    Text('Hạn mức tối đa: ${mentor.maxQuota}', style: const TextStyle(fontSize: 11, color: AdminPalette.muted)),
                  ],
                ),
              ],
            ),
          ),

          // Mentored teams list if any
          if (mentor.mentoredTeamNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Nhóm đang hướng dẫn: ${mentor.mentoredTeamNames.join(", ")}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F766E), fontStyle: FontStyle.italic),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onArchive,
                    icon: Icon(
                      mentor.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                      size: 18,
                      color: AdminPalette.muted,
                    ),
                    tooltip: mentor.archived ? 'Bỏ lưu trữ' : 'Lưu trữ giảng viên',
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                    tooltip: 'Xóa giảng viên',
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: onEditQuota,
                icon: const Icon(Icons.tune, size: 14),
                label: const Text('Điều chỉnh Quota', style: TextStyle(fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditQuotaDialog extends StatefulWidget {
  const _EditQuotaDialog({required this.mentor});
  final Mentor mentor;

  @override
  State<_EditQuotaDialog> createState() => _EditQuotaDialogState();
}

class _EditQuotaDialogState extends State<_EditQuotaDialog> {
  late int _quota;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _quota = widget.mentor.maxQuota;
    _controller = TextEditingController(text: '$_quota');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minVal = widget.mentor.currentAssigned > 0 ? widget.mentor.currentAssigned : 1;

    return AlertDialog(
      title: const Text('Điều chỉnh Hạn ngạch Quota', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Giảng viên: ', style: TextStyle(color: AdminPalette.muted)),
                  TextSpan(text: widget.mentor.fullName, style: const TextStyle(fontWeight: FontWeight.w700, color: AdminPalette.ink)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Số nhóm đang hướng dẫn hiện tại: ${widget.mentor.currentAssigned} nhóm',
              style: const TextStyle(fontSize: 13, color: AdminPalette.muted),
            ),
            const SizedBox(height: 20),
            const Text(
              'Hạn mức số nhóm tối đa (Max Quota) *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _quota > minVal
                      ? () {
                          setState(() {
                            _quota--;
                            _controller.text = '$_quota';
                          });
                        }
                      : null,
                  icon: const Icon(Icons.remove, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AdminPalette.ink,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminPalette.primary, width: 2),
                      ),
                      suffixText: 'nhóm',
                      suffixStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminPalette.muted),
                    ),
                    onChanged: (val) {
                      final digitsOnly = val.replaceAll(RegExp(r'\D'), '');
                      final parsed = int.tryParse(digitsOnly);
                      if (parsed != null) {
                        setState(() {
                          _quota = parsed.clamp(minVal, 30);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: _quota < 30
                      ? () {
                          setState(() {
                            _quota++;
                            _controller.text = '$_quota';
                          });
                        }
                      : null,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Nhập số trực tiếp hoặc dùng nút +/-. Hạn ngạch tối thiểu là ${widget.mentor.currentAssigned} nhóm.',
              style: const TextStyle(fontSize: 11.5, color: AdminPalette.muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy bỏ')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _quota),
          style: FilledButton.styleFrom(backgroundColor: AdminPalette.primary),
          child: const Text('Lưu hạn ngạch'),
        ),
      ],
    );
  }
}

class _AddMentorDialog extends StatefulWidget {
  const _AddMentorDialog();

  @override
  State<_AddMentorDialog> createState() => _AddMentorDialogState();
}

class _AddMentorDialogState extends State<_AddMentorDialog> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _office = TextEditingController();
  final _expertise = TextEditingController();
  String _department = 'Khoa Công nghệ thông tin';
  int _maxQuota = 4;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _office.dispose();
    _expertise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm Giảng viên Mentor vào Học kỳ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _fullName,
                decoration: const InputDecoration(
                  labelText: 'Họ tên & Học hàm/Học vị *',
                  hintText: 'VD: TS. Nguyễn Văn A hoặc ThS. Lê Thị B',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email FPT (@fpt.edu.vn) *',
                        hintText: 'email@fpt.edu.vn',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        hintText: '0912 xxx xxx',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _department,
                      decoration: const InputDecoration(labelText: 'Khoa / Bộ môn *'),
                      items: const [
                        DropdownMenuItem(value: 'Khoa Công nghệ thông tin', child: Text('Khoa Công nghệ thông tin')),
                        DropdownMenuItem(value: 'Viện Quản trị Kinh doanh', child: Text('Viện Quản trị Kinh doanh')),
                        DropdownMenuItem(value: 'Khoa Hệ thống thông tin', child: Text('Khoa Hệ thống thông tin')),
                        DropdownMenuItem(value: 'Khoa Digital Marketing & Truyền thông', child: Text('Khoa Digital Marketing')),
                        DropdownMenuItem(value: 'Khoa Thiết kế mỹ thuật số', child: Text('Khoa Thiết kế mỹ thuật số')),
                        DropdownMenuItem(value: 'Khoa An toàn thông tin', child: Text('Khoa An toàn thông tin')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _department = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: '$_maxQuota',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quota tối đa'),
                      onChanged: (val) => _maxQuota = int.tryParse(val) ?? 4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _office,
                decoration: const InputDecoration(
                  labelText: 'Văn phòng / Phòng làm việc',
                  hintText: 'VD: Phòng 201, Tòa Beta, ĐH FPT',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _expertise,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Chuyên môn & Lĩnh vực hướng dẫn *',
                  hintText: 'VD: AI/ML, Big Data, Khởi nghiệp ứng dụng công nghệ, Cloud...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy bỏ')),
        FilledButton(
          onPressed: () {
            if (_fullName.text.trim().isEmpty || _email.text.trim().isEmpty) return;
            final expertiseList = _expertise.text
                .split(RegExp(r'[,;]'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();

            Navigator.pop(context, {
              'fullName': _fullName.text.trim(),
              'email': _email.text.trim().toLowerCase(),
              'title': _fullName.text.trim().split(' ').first,
              'department': _department,
              'phone': _phone.text.trim(),
              'office': _office.text.trim(),
              'expertise': expertiseList.isNotEmpty ? expertiseList : [_expertise.text.trim()],
              'bio': _expertise.text.trim(),
              'maxQuota': _maxQuota,
            });
          },
          style: FilledButton.styleFrom(backgroundColor: AdminPalette.primary),
          child: const Text('Xác nhận thêm Mentor'),
        ),
      ],
    );
  }
}

class _TopBanner extends StatelessWidget {
  const _TopBanner({required this.message, required this.isError, required this.onClose});

  final String message;
  final bool isError;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bg = isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
    final border = isError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);
    final iconColor = isError ? AdminPalette.danger : AdminPalette.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: iconColor),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 16),
            color: AdminPalette.muted,
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

