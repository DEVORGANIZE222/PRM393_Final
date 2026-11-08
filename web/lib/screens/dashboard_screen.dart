import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// EdTech SaaS Dashboard — ExeMatching
/// Matches C:\Users\Administrator\Desktop\EXETeamMatching\fe\src\features\dashboard\DashboardPage.jsx
/// Includes 4 Macro Metrics, 3 Milestone Countdowns, and Team Status Distribution.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onOpenReview, this.onOpenGroups, this.onOpenAnnouncements});

  final VoidCallback? onOpenReview;
  final VoidCallback? onOpenGroups;
  final VoidCallback? onOpenAnnouncements;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _data = _DashboardData.load();
  StreamSubscription? _semestersSub;
  StreamSubscription? _configSub;

  @override
  void initState() {
    super.initState();
    _semestersSub = FirebaseFirestore.instance.collection('semesters').snapshots().listen((_) {
      if (mounted) setState(() => _data = _DashboardData.load());
    });
    _configSub = FirebaseFirestore.instance.collection('configuration').doc('registration').snapshots().listen((_) {
      if (mounted) setState(() => _data = _DashboardData.load());
    });
  }

  @override
  void dispose() {
    _semestersSub?.cancel();
    _configSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_DashboardData>(
    future: _data,
    builder: (context, snapshot) {
      final data = snapshot.data;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header & Action Buttons ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tổng quan học kỳ',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AdminPalette.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data?.activeSemester != null
                            ? 'Chào Quản trị viên, theo dõi tiến độ ghép nhóm, phê duyệt đề tài và lịch trình học kỳ ${data!.activeSemester}.'
                            : 'Theo dõi dữ liệu ghép nhóm và các thao tác quản trị theo thời gian thực.',
                        style: const TextStyle(fontSize: 14, color: AdminPalette.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onOpenAnnouncements,
                      icon: const Icon(Icons.campaign_outlined, size: 18),
                      label: const Text('Phát thông báo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminPalette.ink,
                        side: const BorderSide(color: AdminPalette.border),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenGroups,
                      icon: const Icon(Icons.layers_outlined, size: 18),
                      label: const Text('Tất cả nhóm'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminPalette.ink,
                        side: const BorderSide(color: AdminPalette.border),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: widget.onOpenReview,
                      icon: const Icon(Icons.inbox_outlined, size: 18),
                      label: Text(
                        data != null && data.pendingReviews > 0
                            ? 'Duyệt nhóm (${data.pendingReviews})'
                            : 'Duyệt nhóm & Đề tài',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminPalette.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (snapshot.hasError)
              _LoadError(onRetry: () => setState(() => _data = _DashboardData.load()))
            else if (data == null)
              const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator(color: AdminPalette.primary)),
              )
            else ...[
              // ── 4 Macro Metric Cards ──
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth < 650
                      ? constraints.maxWidth
                      : (constraints.maxWidth < 1000
                            ? (constraints.maxWidth - 16) / 2
                            : (constraints.maxWidth - 48) / 4);
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _MacroMetricCard(
                        title: 'Tổng sinh viên',
                        value: '${data.students}',
                        subtext: '${data.matchedStudents} đã có nhóm · ${data.unmatchedStudents} chờ ghép',
                        icon: Icons.people_outline,
                        width: itemWidth,
                      ),
                      _MacroMetricCard(
                        title: 'Nhóm đã lập',
                        value: '${data.teams}',
                        subtext: '${data.lockedTeams} nhóm đã khóa hoặc đủ 5 người',
                        icon: Icons.layers_outlined,
                        width: itemWidth,
                      ),
                      _MacroMetricCard(
                        title: 'Đề tài đã đăng ký',
                        value: '${data.topicCount}',
                        subtext: 'Đề tài khởi nghiệp đã chốt',
                        icon: Icons.description_outlined,
                        width: itemWidth,
                      ),
                      _MacroMetricCard(
                        title: 'Hạn ghép tự do',
                        value: data.regDaysLeftText,
                        subtext: data.regDeadlineSubtext,
                        icon: Icons.calendar_today_outlined,
                        width: itemWidth,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── 3 Key Milestone Countdowns & Timeline Progress ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AdminPalette.tealLight,
                                  border: Border.all(color: const Color(0xFF99F6E4)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  data.activeSemester ?? 'Học kỳ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AdminPalette.teal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                '3 Mốc Thời Hạn & Đếm Ngược Học Kỳ Khởi Nghiệp',
                                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: AdminPalette.ink),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AdminPalette.primaryLight,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: AdminPalette.primaryBorder),
                            ),
                            child: const Text(
                              'Học kỳ đang kích hoạt',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AdminPalette.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3 Milestone Cards Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = constraints.maxWidth < 750
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 24) / 3;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _MilestoneCard(
                                number: '1',
                                title: 'Hạn ghép nhóm tự do',
                                daysText: data.regDaysLeftText,
                                subtext: data.regDeadlineSubtext,
                                statusBadge: data.regBadge,
                                bg: const Color(0xFFECFDF5),
                                border: const Color(0xFFA7F3D0),
                                titleColor: const Color(0xFF065F46),
                                numColor: const Color(0xFF047857),
                                subColor: const Color(0xFF059669),
                                badgeBg: AdminPalette.primaryLight,
                                badgeBorder: AdminPalette.primaryBorder,
                                badgeText: AdminPalette.primary,
                                width: cardWidth,
                              ),
                              _MilestoneCard(
                                number: '2',
                                title: 'Hạn chốt nộp đề tài',
                                daysText: data.topicDaysLeftText,
                                subtext: data.topicDeadlineSubtext,
                                statusBadge: data.topicBadge,
                                bg: const Color(0xFFFFFBEB),
                                border: const Color(0xFFFDE68A),
                                titleColor: const Color(0xFF92400E),
                                numColor: const Color(0xFFB45309),
                                subColor: const Color(0xFFD97706),
                                badgeBg: AdminPalette.warningLight,
                                badgeBorder: const Color(0xFFFDE68A),
                                badgeText: AdminPalette.warning,
                                width: cardWidth,
                              ),
                              _MilestoneCard(
                                number: '3',
                                title: 'Hạn kết nối Mentor',
                                daysText: data.mentorDaysLeftText,
                                subtext: data.mentorDeadlineSubtext,
                                statusBadge: data.mentorBadge,
                                bg: const Color(0xFFF0FDFA),
                                border: const Color(0xFF99F6E4),
                                titleColor: const Color(0xFF115E59),
                                numColor: const Color(0xFF0F766E),
                                subColor: const Color(0xFF0D9488),
                                badgeBg: AdminPalette.tealLight,
                                badgeBorder: const Color(0xFF99F6E4),
                                badgeText: AdminPalette.teal,
                                width: cardWidth,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Team Formation Distribution Bar ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tình trạng ghép đội',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AdminPalette.ink),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Biểu đồ thống kê theo thời gian thực tổng hợp từ Firestore collection teams.',
                        style: TextStyle(fontSize: 13.5, color: AdminPalette.muted),
                      ),
                      const SizedBox(height: 24),
                      _Bar(
                        label: 'Đang ghép thành viên (chưa đủ 5 người)',
                        value: data.formingTeams,
                        total: data.teams,
                        color: AdminPalette.warning,
                      ),
                      _Bar(
                        label: 'Sẵn sàng khóa (đủ 5 thành viên hoặc đã chốt đề tài)',
                        value: data.readyTeams,
                        total: data.teams,
                        color: const Color(0xFF2563EB),
                      ),
                      _Bar(
                        label: 'Đã khóa roster & gửi duyệt',
                        value: data.lockedTeams,
                        total: data.teams,
                        color: AdminPalette.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _MacroMetricCard extends StatelessWidget {
  const _MacroMetricCard({
    required this.title,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.width,
  });

  final String title, value, subtext;
  final IconData icon;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AdminPalette.surface,
      border: Border.all(color: AdminPalette.border),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1))],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: AdminPalette.subtle, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AdminPalette.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AdminPalette.muted),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AdminPalette.ink,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtext,
                style: const TextStyle(fontSize: 12, color: AdminPalette.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.number,
    required this.title,
    required this.daysText,
    required this.subtext,
    required this.statusBadge,
    required this.bg,
    required this.border,
    required this.titleColor,
    required this.numColor,
    required this.subColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeText,
    required this.width,
  });

  final String number, title, daysText, subtext, statusBadge;
  final Color bg, border, titleColor, numColor, subColor, badgeBg, badgeBorder, badgeText;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bg,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$number. $title',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: titleColor),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                border: Border.all(color: badgeBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusBadge,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          daysText,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: numColor, height: 1.1),
        ),
        const SizedBox(height: 4),
        Text(subtext, style: TextStyle(fontSize: 11.5, color: subColor)),
      ],
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.total, required this.color});
  final String label;
  final int value, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : value / total;
    final percent = (fraction * 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AdminPalette.ink),
                ),
              ),
              Text(
                '$value / $total ($percent%)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminPalette.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: fraction,
            color: color,
            backgroundColor: AdminPalette.subtle,
            minHeight: 8,
            borderRadius: const BorderRadius.all(Radius.circular(99)),
          ),
        ],
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.students,
    required this.matchedStudents,
    required this.unmatchedStudents,
    required this.teams,
    required this.lockedTeams,
    required this.readyTeams,
    required this.formingTeams,
    required this.topicCount,
    required this.pendingReviews,
    required this.activeSemester,
    required this.regDaysLeftText,
    required this.regDeadlineSubtext,
    required this.regBadge,
    required this.topicDaysLeftText,
    required this.topicDeadlineSubtext,
    required this.topicBadge,
    required this.mentorDaysLeftText,
    required this.mentorDeadlineSubtext,
    required this.mentorBadge,
  });

  final int students, matchedStudents, unmatchedStudents;
  final int teams, lockedTeams, readyTeams, formingTeams;
  final int topicCount, pendingReviews;
  final String? activeSemester;
  final String regDaysLeftText, regDeadlineSubtext, regBadge;
  final String topicDaysLeftText, topicDeadlineSubtext, topicBadge;
  final String mentorDaysLeftText, mentorDeadlineSubtext, mentorBadge;

  static Future<_DashboardData> load() async {
    final db = FirebaseFirestore.instance;
    final values = await Future.wait([
      db.collection('allowedEmails').count().get().timeout(const Duration(seconds: 4)).catchError((_) => null),
      db.collection('teamSubmissions').where('status', isEqualTo: 'pending').count().get().timeout(const Duration(seconds: 4)).catchError((_) => null),
      db.collection('teams').get().timeout(const Duration(seconds: 4)).catchError((_) => null),
      db.collection('configuration').doc('registration').get().timeout(const Duration(seconds: 4)).catchError((_) => null),
      db.collection('semesters').where('status', isEqualTo: 'active').limit(1).get().timeout(const Duration(seconds: 4)).catchError((_) => null),
    ]);

    final totalStudents = values[0] is AggregateQuerySnapshot ? (values[0] as AggregateQuerySnapshot).count ?? 0 : 0;
    final pendingCount = values[1] is AggregateQuerySnapshot ? (values[1] as AggregateQuerySnapshot).count ?? 0 : 0;
    final teamsSnapshot = values[2] as QuerySnapshot<Map<String, dynamic>>?;
    final configSnapshot = values[3] as DocumentSnapshot<Map<String, dynamic>>?;
    final activeSemSnapshot = values[4] as QuerySnapshot<Map<String, dynamic>>?;

    var totalTeams = 0;
    var locked = 0;
    var ready = 0;
    var topicCount = 0;

    if (teamsSnapshot != null) {
      totalTeams = teamsSnapshot.size;
      for (final doc in teamsSnapshot.docs) {
        final data = doc.data();
        final members = data['members'] as List<dynamic>? ?? const [];
        final hasTopic =
            (data['topic'] as String?)?.isNotEmpty == true || (data['topicTitle'] as String?)?.isNotEmpty == true;

        if (hasTopic) topicCount++;

        if (data['locked'] == true) {
          locked++;
        } else if (members.length >= 5 || hasTopic) {
          ready++;
        }
      }
    }

    final matchedCount = (locked * 5).clamp(0, totalStudents);
    final unmatched = (totalStudents - matchedCount).clamp(0, totalStudents);

    final config = configSnapshot?.data() ?? {};
    final activeSemData = activeSemSnapshot != null && activeSemSnapshot.docs.isNotEmpty
        ? activeSemSnapshot.docs.first.data()
        : null;

    final semesterName = (activeSemData?['name'] as String?) ??
        (config['semester'] as String?) ??
        'FA26';

    // Parse milestone countdowns from active semester or configuration
    final now = DateTime.now();
    DateTime regDeadline = now.add(const Duration(days: 7));

    if (activeSemData != null && activeSemData['registrationClosesAt'] is Timestamp) {
      regDeadline = (activeSemData['registrationClosesAt'] as Timestamp).toDate();
    } else if (config['closesAt'] is Timestamp) {
      regDeadline = (config['closesAt'] as Timestamp).toDate();
    } else if (config['registrationDeadline'] is Timestamp) {
      regDeadline = (config['registrationDeadline'] as Timestamp).toDate();
    }

    DateTime topicDeadline = regDeadline.add(const Duration(days: 7));
    if (activeSemData != null && activeSemData['topicDeadline'] is Timestamp) {
      topicDeadline = (activeSemData['topicDeadline'] as Timestamp).toDate();
    } else if (config['topicDeadline'] is Timestamp) {
      topicDeadline = (config['topicDeadline'] as Timestamp).toDate();
    }

    DateTime mentorDeadline = regDeadline.add(const Duration(days: 14));
    if (activeSemData != null && activeSemData['mentorDeadline'] is Timestamp) {
      mentorDeadline = (activeSemData['mentorDeadline'] as Timestamp).toDate();
    } else if (config['mentorDeadline'] is Timestamp) {
      mentorDeadline = (config['mentorDeadline'] as Timestamp).toDate();
    }

    _Countdown _computeCountdown(DateTime deadline) {
      // Calculate remaining full days considering day boundaries
      final targetDate = DateTime(deadline.year, deadline.month, deadline.day);
      final today = DateTime(now.year, now.month, now.day);
      final diffDays = targetDate.difference(today).inDays;
      final formatted =
          '${deadline.day.toString().padLeft(2, '0')}/${deadline.month.toString().padLeft(2, '0')}/${deadline.year}';
      if (diffDays > 0) {
        return _Countdown(
          text: 'Còn $diffDays ngày',
          subtext: 'Hạn chót: $formatted',
          badge: diffDays <= 3 ? 'Sắp hết hạn' : 'Đang diễn ra',
        );
      } else if (diffDays == 0) {
        return _Countdown(text: 'Hạn hôm nay', subtext: 'Hạn chót: $formatted', badge: 'Hôm nay');
      } else {
        return _Countdown(text: 'Đã hết hạn', subtext: 'Đã đóng ngày $formatted', badge: 'Đã đóng');
      }
    }

    final reg = _computeCountdown(regDeadline);
    final top = _computeCountdown(topicDeadline);
    final men = _computeCountdown(mentorDeadline);

    return _DashboardData(
      students: totalStudents,
      matchedStudents: matchedCount,
      unmatchedStudents: unmatched,
      teams: totalTeams,
      lockedTeams: locked,
      readyTeams: ready,
      formingTeams: (totalTeams - locked - ready).clamp(0, totalTeams),
      topicCount: topicCount,
      pendingReviews: pendingCount,
      activeSemester: semesterName,
      regDaysLeftText: reg.text,
      regDeadlineSubtext: reg.subtext,
      regBadge: reg.badge,
      topicDaysLeftText: top.text,
      topicDeadlineSubtext: top.subtext,
      topicBadge: top.badge,
      mentorDaysLeftText: men.text,
      mentorDeadlineSubtext: men.subtext,
      mentorBadge: men.badge,
    );
  }
}

class _Countdown {
  const _Countdown({required this.text, required this.subtext, required this.badge});
  final String text, subtext, badge;
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AdminPalette.danger, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Không thể tải số liệu Firestore. Kiểm tra quyền Admin rồi thử lại.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
