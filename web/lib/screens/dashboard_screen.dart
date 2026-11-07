import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onOpenReview, this.onOpenAnnouncements});
  final VoidCallback? onOpenReview;
  final VoidCallback? onOpenAnnouncements;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _data = _DashboardData.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<_DashboardData>(
    future: _data,
    builder: (context, snapshot) {
      final data = snapshot.data;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tổng quan học kỳ', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text(
                        'Theo dõi dữ liệu ghép nhóm và các thao tác quản trị theo thời gian thực.',
                        style: TextStyle(color: AdminPalette.muted),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onOpenAnnouncements,
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Thông báo'),
                    ),
                    FilledButton.icon(
                      onPressed: widget.onOpenReview,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Duyệt đội'),
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
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _Metric(
                    'Tổng sinh viên',
                    '${data.students}',
                    'Danh sách roster đã cấp quyền',
                    Icons.people_outline,
                    AdminPalette.primary,
                  ),
                  _Metric(
                    'Nhóm đang hoạt động',
                    '${data.teams}',
                    '${data.lockedTeams} đội đã khóa roster',
                    Icons.layers_outlined,
                    const Color(0xFF2563EB),
                  ),
                  _Metric(
                    'Chờ duyệt',
                    '${data.pendingReviews}',
                    'Đội đã khóa gửi Phòng đào tạo',
                    Icons.fact_check_outlined,
                    AdminPalette.warning,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tình trạng ghép đội', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text(
                        'Biểu đồ được tổng hợp từ collection teams.',
                        style: TextStyle(color: AdminPalette.muted),
                      ),
                      const SizedBox(height: 24),
                      _Bar(
                        label: 'Đang ghép thành viên',
                        value: data.formingTeams,
                        total: data.teams,
                        color: AdminPalette.warning,
                      ),
                      _Bar(
                        label: 'Sẵn sàng khóa',
                        value: data.readyTeams,
                        total: data.teams,
                        color: const Color(0xFF2563EB),
                      ),
                      _Bar(
                        label: 'Đã khóa roster',
                        value: data.lockedTeams,
                        total: data.teams,
                        color: AdminPalette.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AdminPalette.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          data.activeSemester == null
                              ? 'Chưa có học kỳ kích hoạt. Vào Học kỳ để thiết lập thời gian đăng ký cho mobile.'
                              : 'Học kỳ đang áp dụng: ${data.activeSemester}. Thời gian này được mobile đọc từ configuration/registration.',
                        ),
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

class _DashboardData {
  const _DashboardData({
    required this.students,
    required this.teams,
    required this.lockedTeams,
    required this.pendingReviews,
    required this.formingTeams,
    required this.readyTeams,
    this.activeSemester,
  });
  final int students, teams, lockedTeams, pendingReviews, formingTeams, readyTeams;
  final String? activeSemester;
  static Future<_DashboardData> load() async {
    final db = FirebaseFirestore.instance;
    final values = await Future.wait([
      db.collection('students').count().get(),
      db.collection('teams').count().get(),
      db.collection('teamSubmissions').where('status', isEqualTo: 'pending').count().get(),
      db.collection('teams').get(),
      db.collection('configuration').doc('registration').get(),
    ]);
    final teams = values[3] as QuerySnapshot<Map<String, dynamic>>;
    var locked = 0;
    var ready = 0;
    for (final team in teams.docs) {
      final data = team.data();
      if (data['locked'] == true) {
        locked++;
      } else if ((data['memberIds'] as List<dynamic>? ?? const []).length >= 4 && data['leaderId'] != null) {
        ready++;
      }
    }
    final config = values[4] as DocumentSnapshot<Map<String, dynamic>>;
    return _DashboardData(
      students: (values[0] as AggregateQuerySnapshot).count ?? 0,
      teams: (values[1] as AggregateQuerySnapshot).count ?? 0,
      pendingReviews: (values[2] as AggregateQuerySnapshot).count ?? 0,
      lockedTeams: locked,
      readyTeams: ready,
      formingTeams: teams.size - locked - ready,
      activeSemester: config.data()?['semester'] as String?,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.title, this.value, this.hint, this.icon, this.color);
  final String title, value, hint;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AdminPalette.muted)),
                  Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                  Text(hint, style: const TextStyle(fontSize: 12, color: AdminPalette.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text('$value / $total'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: fraction,
            color: color,
            backgroundColor: AdminPalette.subtle,
            minHeight: 10,
            borderRadius: const BorderRadius.all(Radius.circular(99)),
          ),
        ],
      ),
    );
  }
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
          const Icon(Icons.cloud_off_outlined, color: AdminPalette.danger),
          const SizedBox(height: 12),
          const Text('Không thể tải số liệu Firestore. Kiểm tra quyền Admin rồi thử lại.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
