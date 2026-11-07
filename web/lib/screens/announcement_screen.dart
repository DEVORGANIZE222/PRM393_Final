import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/admin_theme.dart';

/// EdTech SaaS Announcement Broadcast — ExeMatching
/// Broadcasts semester-wide notifications to student and mentor mobile apps.
class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isPublishing = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _recentAnnouncements => FirebaseFirestore.instance
      .collection('announcements')
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots();

  void _publishAnnouncement() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vui lòng nhập cả tiêu đề và nội dung thông báo.')));
      return;
    }

    setState(() => _isPublishing = true);

    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': title,
        'body': body,
        'status': 'published',
        'authorId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'authorName': FirebaseAuth.instance.currentUser?.displayName ?? 'Quản trị viên',
        'createdAt': FieldValue.serverTimestamp(),
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (mounted) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể phát thông báo: $error')));
      }
      return;
    }

    if (mounted) {
      setState(() => _isPublishing = false);
      _titleController.clear();
      _bodyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã phát thông báo thành công đến toàn bộ ứng dụng sinh viên & giảng viên.'),
          backgroundColor: AdminPalette.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phát thông báo học kỳ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AdminPalette.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Thông báo đã phát sẽ xuất hiện ngay lập tức trong hộp thư thông báo của ứng dụng sinh viên và giảng viên.',
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign, size: 16, color: AdminPalette.primary),
                    SizedBox(width: 6),
                    Text(
                      'Broadcast Kênh Toàn Trường',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminPalette.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Compose Card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Soạn nội dung thông báo',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AdminPalette.ink),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Đăng tải các chỉ thị về hạn chốt đề tài, kết nối mentor hoặc điều chỉnh tiến độ học kỳ.',
                    style: TextStyle(fontSize: 13, color: AdminPalette.muted),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề thông báo *',
                      hintText: 'Ví dụ: Gia hạn thời gian đăng ký đề tài & ghép nhóm tự do',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bodyController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung chi tiết *',
                      hintText: 'Nhập nội dung thông báo gửi tới các bạn sinh viên và giảng viên cố vấn...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton.icon(
                        onPressed: _isPublishing ? null : _publishAnnouncement,
                        icon: _isPublishing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_outlined, size: 16),
                        label: Text(_isPublishing ? 'Đang gửi...' : 'Phát thông báo ngay'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminPalette.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Recent Announcements ──
          const Text(
            'Lịch sử thông báo đã phát',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdminPalette.ink),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _recentAnnouncements,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Không thể tải lịch sử thông báo. Kiểm tra Firestore Rules.',
                      style: TextStyle(color: AdminPalette.danger),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator(color: AdminPalette.primary)),
                  ),
                );
              }

              final items = snapshot.data!.docs;
              if (items.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Chưa có thông báo nào được phát trong học kỳ này.',
                        style: TextStyle(color: AdminPalette.muted),
                      ),
                    ),
                  ),
                );
              }

              return Card(
                child: Column(
                  children: items.map((item) {
                    final data = item.data();
                    final title = data['title'] as String? ?? 'Không có tiêu đề';
                    final body = data['body'] as String? ?? '';
                    final author = data['authorName'] as String? ?? 'Quản trị viên';
                    final time = (data['createdAt'] as Timestamp?)?.toDate();
                    final timeStr = time != null
                        ? '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                        : 'Vừa xong';

                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AdminPalette.border)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AdminPalette.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.campaign_outlined, color: AdminPalette.primary, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AdminPalette.ink,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AdminPalette.primaryLight,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: const Text(
                                        'Đã phát',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AdminPalette.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  body,
                                  style: const TextStyle(fontSize: 13, color: AdminPalette.muted, height: 1.4),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Người phát: $author · $timeStr',
                                  style: const TextStyle(fontSize: 11.5, color: AdminPalette.slate400),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}
