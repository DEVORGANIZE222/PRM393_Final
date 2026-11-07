import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('teams').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const Center(
          child: Text('Không thể tải danh sách nhóm.', style: TextStyle(color: AdminPalette.danger)),
        );
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final teams = snapshot.data!.docs.where((doc) {
        final d = doc.data();
        return "${d['name']} ${d['topic']}".toLowerCase().contains(_query.toLowerCase());
      }).toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 38, 24, 48),
        children: [
          const Text('Nhóm & Đề tài Khởi nghiệp', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Theo dõi nhóm và roster từ ứng dụng sinh viên.', style: TextStyle(color: AdminPalette.muted)),
          const SizedBox(height: 24),
          SizedBox(
            width: 360,
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm theo tên nhóm, đề tài...',
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (teams.isEmpty)
            const Card(
              child: Padding(padding: EdgeInsets.all(36), child: Text('Chưa có nhóm phù hợp.')),
            )
          else
            Wrap(spacing: 20, runSpacing: 20, children: teams.map((doc) => _GroupCard(data: doc.data())).toList()),
        ],
      );
    },
  );
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final members = data['members'] as List<dynamic>? ?? const [];
    final capacity = data['capacity'] as int? ?? 5;
    final locked = data['locked'] == true;
    return SizedBox(
      width: 440,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locked ? 'Đã khóa roster' : 'Đang ghép thành viên',
                style: TextStyle(
                  color: locked ? AdminPalette.primary : AdminPalette.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                data['name'] as String? ?? 'Nhóm chưa đặt tên',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                data['topic'] as String? ?? 'Chưa đăng ký đề tài',
                style: const TextStyle(color: AdminPalette.muted),
              ),
              const Divider(height: 30),
              Text('${members.length}/$capacity thành viên'),
              Text('Trưởng nhóm: ${data['leaderId'] ?? 'Chưa bầu'}'),
              Text('Giảng viên: ${data['mentorId'] == null ? 'Chưa có' : data['supervisor']}'),
              if (data['lockCode'] != null) Text('Mã khóa: ${data['lockCode']}'),
            ],
          ),
        ),
      ),
    );
  }
}
