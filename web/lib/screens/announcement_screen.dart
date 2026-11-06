import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/admin_theme.dart';

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
      .limit(5)
      .snapshots();

  void _publishAnnouncement() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter both title and announcement body.')));
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
          content: Text('Đã phát thông báo đến ứng dụng sinh viên.'),
          backgroundColor: AdminPalette.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phát thông báo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Thông báo đã phát sẽ xuất hiện ngay trong hộp thư của ứng dụng sinh viên.',
            style: TextStyle(color: AdminPalette.muted),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Tiêu đề thông báo',
                      hintText: 'Ví dụ: Gia hạn thời gian đăng ký nhóm',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bodyController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Nội dung',
                      hintText: 'Nhập nội dung gửi tới sinh viên...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isPublishing ? null : _publishAnnouncement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminPalette.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isPublishing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Phát thông báo'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Thông báo gần đây', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final items = snapshot.data!.docs;
              if (items.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa có thông báo nào được phát trong học kỳ này.',
                      style: TextStyle(color: AdminPalette.muted),
                    ),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: items.map((item) {
                    final data = item.data();
                    return ListTile(
                      leading: const Icon(Icons.campaign_outlined, color: AdminPalette.primary),
                      title: Text(data['title'] as String? ?? 'Không có tiêu đề'),
                      subtitle: Text(data['body'] as String? ?? ''),
                      trailing: const Text('Đã phát', style: TextStyle(color: AdminPalette.primary)),
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
