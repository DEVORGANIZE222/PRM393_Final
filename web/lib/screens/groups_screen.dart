import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// EdTech SaaS Groups & Topics — ExeMatching
/// Matches C:\Users\Administrator\Desktop\EXETeamMatching\fe\src\features\groups\GroupsPage.jsx
/// Clean cards, recruitment needs tags, member avatar pills, crown for leader, and filter tabs.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  String _query = '';
  String _filter = 'all'; // 'all' | 'recruiting' | 'full'

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('teams').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Không thể tải danh sách nhóm.', style: TextStyle(color: AdminPalette.danger)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AdminPalette.primary));
          }

          final allDocs = snapshot.data!.docs;

          // Categorize and filter
          final filtered = allDocs.where((doc) {
            final d = doc.data();
            final name = (d['name'] as String? ?? '').toLowerCase();
            final topic = (d['topic'] as String? ?? d['topicTitle'] as String? ?? '').toLowerCase();
            final leader = (d['leaderId'] as String? ?? d['leaderName'] as String? ?? '').toLowerCase();
            final members = d['members'] as List<dynamic>? ?? const [];
            final isLocked = d['locked'] == true;
            final isFull = isLocked || members.length >= 5;

            // Search filter
            final q = _query.toLowerCase().trim();
            final matchesQuery = q.isEmpty || name.contains(q) || topic.contains(q) || leader.contains(q);

            // Tab filter
            final matchesTab = _filter == 'all' ||
                (_filter == 'recruiting' && !isFull) ||
                (_filter == 'full' && isFull);

            return matchesQuery && matchesTab;
          }).toList();

          final countAll = allDocs.length;
          final countRecruiting = allDocs.where((doc) {
            final d = doc.data();
            final members = d['members'] as List<dynamic>? ?? const [];
            return d['locked'] != true && members.length < 5;
          }).length;
          final countFull = countAll - countRecruiting;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
            children: [
              // ── Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nhóm & Đề tài Khởi nghiệp',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AdminPalette.ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Khám phá danh sách các nhóm Khởi nghiệp, tìm đồng đội bù trừ kỹ năng, theo dõi tiến độ và kiểm tra hồ sơ nhóm.',
                          style: TextStyle(fontSize: 14, color: AdminPalette.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminPalette.primaryLight,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AdminPalette.primaryBorder),
                    ),
                    child: Text(
                      '$countAll nhóm trong hệ thống',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AdminPalette.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Filter Tabs & Search Bar ──
              Row(
                children: [
                  // Filter Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AdminPalette.subtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FilterTab(
                          label: 'Tất cả ($countAll)',
                          active: _filter == 'all',
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                        _FilterTab(
                          label: 'Đang tuyển ($countRecruiting)',
                          active: _filter == 'recruiting',
                          onTap: () => setState(() => _filter = 'recruiting'),
                        ),
                        _FilterTab(
                          label: 'Đã chốt / Đủ người ($countFull)',
                          active: _filter == 'full',
                          onTap: () => setState(() => _filter = 'full'),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Search
                  SizedBox(
                    width: 320,
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(fontSize: 13.5),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Tìm theo tên nhóm, đề tài, leader...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Groups Grid ──
              if (filtered.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        const Icon(Icons.layers_clear_outlined, size: 48, color: AdminPalette.slate400),
                        const SizedBox(height: 12),
                        const Text(
                          'Không tìm thấy nhóm phù hợp',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AdminPalette.ink),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Thử thay đổi bộ lọc tìm kiếm hoặc nạp thêm nhóm mới.',
                          style: TextStyle(fontSize: 13, color: AdminPalette.muted),
                        ),
                        if (_query.isNotEmpty || _filter != 'all') ...[
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () => setState(() {
                              _query = '';
                              _filter = 'all';
                            }),
                            child: const Text('Đặt lại bộ lọc'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth < 800
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 20) / 2;
                    return Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: filtered.map((doc) => _GroupCard(data: doc.data(), docId: doc.id, width: cardWidth)).toList(),
                    );
                  },
                ),
            ],
          );
        },
      );
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: active
                ? const [
                    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
                  ]
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.data, required this.docId, required this.width});
  final Map<String, dynamic> data;
  final String docId;
  final double width;

  @override
  Widget build(BuildContext context) {
    final members = data['members'] as List<dynamic>? ?? const [];
    final capacity = data['capacity'] as int? ?? 5;
    final locked = data['locked'] == true;
    final isFull = locked || members.length >= capacity;

    final rawTopic = (data['topic'] as String? ?? data['topicTitle'] as String? ?? '').trim();
    final rawDesc = (data['description'] as String? ?? data['projectDescription'] as String? ?? '').trim();

    final topic = rawTopic.isNotEmpty ? rawTopic : 'Chưa đăng ký đề tài';
    final hasDistinctDesc = rawDesc.isNotEmpty &&
        rawDesc != 'Chưa có mô tả dự án.' &&
        rawDesc.toLowerCase() != rawTopic.toLowerCase();

    final tags = (data['recruitmentNeeds'] as List<dynamic>? ?? data['tags'] as List<dynamic>? ?? const [])
        .map((e) => e is Map ? (e['roleCode']?.toString() ?? '') : e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

    // Resolve real leader's name from members list instead of displaying raw UID
    final leaderId = data['leaderId'] as String?;
    String leaderName = 'Chưa bầu';
    if (leaderId != null && leaderId.isNotEmpty) {
      var leaderMember = members.firstWhere(
        (m) =>
            m is Map &&
            (m['studentId'] == leaderId ||
                m['id'] == leaderId ||
                m['uid'] == leaderId ||
                m['userId'] == leaderId ||
                m['studentCode'] == leaderId ||
                m['email'] == leaderId),
        orElse: () => null,
      );
      if (leaderMember == null) {
        leaderMember = members.firstWhere(
          (m) =>
              m is Map &&
              (m['role'] == 'Team Lead' ||
                  m['role'] == 'Leader' ||
                  m['isLeader'] == true ||
                  m['role'] == 1),
          orElse: () => null,
        );
      }
      if (leaderMember is Map) {
        leaderName = leaderMember['fullName']?.toString() ??
            leaderMember['name']?.toString() ??
            data['leaderName'] as String? ??
            leaderId;
      } else if (data['leaderName'] != null && (data['leaderName'] as String).isNotEmpty) {
        leaderName = data['leaderName'] as String;
      } else {
        leaderName = leaderId;
      }
    }
    final lockCode = data['lockCode'] as String? ?? data['groupCode'] as String?;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AdminPalette.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (locked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AdminPalette.tealLight,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 13, color: AdminPalette.teal),
                      SizedBox(width: 4),
                      Text(
                        'Đã khóa nhóm',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminPalette.teal),
                      ),
                    ],
                  ),
                )
              else if (isFull)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AdminPalette.tealLight,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 13, color: AdminPalette.teal),
                      SizedBox(width: 4),
                      Text(
                        'Đã đủ 5 thành viên',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminPalette.teal),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AdminPalette.warningLight,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline, size: 13, color: AdminPalette.warning),
                      const SizedBox(width: 4),
                      Text(
                        'Cần thêm ${capacity - members.length} thành viên',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminPalette.warning),
                      ),
                    ],
                  ),
                ),
              Text(
                '${members.length}/$capacity thành viên',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AdminPalette.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Title & Topic ──
          Text(
            data['name'] as String? ?? 'Nhóm chưa đặt tên',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdminPalette.ink),
          ),
          if (rawTopic.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              topic,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AdminPalette.primary),
            ),
          ],
          if (hasDistinctDesc) ...[
            const SizedBox(height: 6),
            Text(
              rawDesc,
              style: const TextStyle(fontSize: 13, color: AdminPalette.muted, height: 1.45),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),

          // ── Tags / Roles Needed ──
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminPalette.warningLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminPalette.warning),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          // ── Team Members Avatar Pills ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Đội ngũ:', style: TextStyle(fontSize: 12, color: AdminPalette.muted, fontWeight: FontWeight.w500)),
                if (members.isEmpty)
                  const Text('Chưa có thành viên', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AdminPalette.muted))
                else
                  ...members.map((m) {
                    final memberMap = m is Map ? m : {'name': m.toString()};
                    final name = memberMap['fullName']?.toString() ??
                        memberMap['name']?.toString() ??
                        memberMap['studentName']?.toString() ??
                        'TV';
                    final isLeader = memberMap['role'] == 1 ||
                        memberMap['role'] == 'Leader' ||
                        memberMap['isLeader'] == true ||
                        memberMap['id'] == data['leaderId'] ||
                        memberMap['studentId'] == data['leaderId'];

                    return Container(
                      padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
                      decoration: BoxDecoration(
                        color: AdminPalette.subtle,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AdminPalette.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: AdminPalette.primaryLight,
                            foregroundColor: AdminPalette.primaryDark,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'T',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            name.split(' ').last,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AdminPalette.ink),
                          ),
                          if (isLeader) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.star, size: 12, color: Color(0xFFEAB308)),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Footer ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Trưởng nhóm: ', style: TextStyle(fontSize: 12, color: AdminPalette.muted)),
                  if (leaderName == leaderId && leaderId != null && leaderId.length > 15)
                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance.collection('students').doc(leaderId).get(),
                      builder: (context, snap) {
                        final realName = snap.data?.data()?['fullName'] as String? ??
                            snap.data?.data()?['name'] as String? ??
                            leaderName;
                        return Text(
                          realName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminPalette.ink),
                        );
                      },
                    )
                  else
                    Text(
                      leaderName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminPalette.ink),
                    ),
                ],
              ),
              if (lockCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminPalette.subtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Mã: $lockCode',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, color: AdminPalette.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Details Button
          OutlinedButton(
            onPressed: () => _showGroupDetails(context, data, docId),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(38),
              side: const BorderSide(color: AdminPalette.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xem chi tiết & danh sách thành viên', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showGroupDetails(BuildContext context, Map<String, dynamic> data, String id) {
    final members = data['members'] as List<dynamic>? ?? const [];
    final topic = data['topic'] as String? ?? data['topicTitle'] as String? ?? 'Chưa đăng ký đề tài';
    final desc = data['description'] as String? ?? data['projectDescription'] as String? ?? 'Chưa có mô tả.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.groups_outlined, color: AdminPalette.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data['name'] as String? ?? 'Chi tiết nhóm',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ĐỀ TÀI KHỞI NGHIỆP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminPalette.muted)),
                const SizedBox(height: 4),
                Text(topic, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AdminPalette.primary)),
                if (desc.isNotEmpty && desc.trim().toLowerCase() != topic.trim().toLowerCase() && desc != 'Chưa có mô tả.') ...[
                  const SizedBox(height: 8),
                  Text(desc, style: const TextStyle(fontSize: 13, color: AdminPalette.muted)),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('DANH SÁCH THÀNH VIÊN (${members.length}/5)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminPalette.muted)),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  const Text('Chưa có thông tin thành viên chi tiết.', style: TextStyle(color: AdminPalette.muted))
                else
                  ...members.map((m) {
                    final memberMap = m is Map ? m : {'name': m.toString()};
                    final name = memberMap['fullName'] ?? memberMap['name'] ?? 'Sinh viên';
                    final code = memberMap['studentCode'] ?? memberMap['id'] ?? '';
                    final role = memberMap['role']?.toString() ?? 'Thành viên';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AdminPalette.primaryLight,
                        child: Text(
                          name.toString().isNotEmpty ? name.toString()[0].toUpperCase() : 'S',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      subtitle: Text('$code · $role', style: const TextStyle(fontSize: 12, color: AdminPalette.muted)),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }
}
