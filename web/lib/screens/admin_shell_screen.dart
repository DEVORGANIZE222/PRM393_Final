import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/admin_theme.dart';
import '../viewmodels/admin_session_viewmodel.dart';
import 'dashboard_screen.dart';
import 'review_queue_screen.dart';
import 'groups_screen.dart';
import 'roster_screen.dart';
import 'management_screen.dart';
import 'announcement_screen.dart';
import 'google_access_screen.dart';

/// EdTech SaaS AppLayout — ExeMatching
/// Matches C:\Users\Administrator\Desktop\EXETeamMatching\fe\src\layouts\AppLayout.jsx
/// Sticky 64px white header, 1240px container, growth green indicator, pending badges.
class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _selected = 0;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _pendingStream = FirebaseFirestore.instance
      .collection('teamSubmissions')
      .where('status', isEqualTo: 'pending')
      .snapshots();

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(
          onOpenReview: () => setState(() => _selected = 1),
          onOpenGroups: () => setState(() => _selected = 2),
          onOpenAnnouncements: () => setState(() => _selected = 5),
        );
      case 1:
        return const ReviewQueueScreen();
      case 2:
        return const GroupsScreen();
      case 3:
        return const RosterScreen();
      case 4:
        return const ManagementScreen();
      case 5:
        return const AnnouncementScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSessionViewModel>();
    final profileName = session.firebaseUser?.displayName ?? session.profile?.displayName;
    final name = profileName == null || profileName.isEmpty
        ? (session.firebaseUser?.email?.split('@').first ?? 'Quản trị viên')
        : profileName;
    final photoUrl =
        session.firebaseUser?.photoURL ??
        (session.firebaseUser?.providerData.isNotEmpty == true
            ? session.firebaseUser!.providerData.first.photoURL
            : null);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingStream,
      builder: (context, snapshot) {
        final pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        final items = [
          const _NavItem('Tổng quan', Icons.dashboard_outlined),
          _NavItem('Duyệt nhóm & Đề tài', Icons.inbox_outlined, badge: pendingCount > 0 ? '$pendingCount' : null),
          const _NavItem('Nhóm & Đề tài', Icons.layers_outlined),
          const _NavItem('Sinh viên', Icons.people_outline),
          const _NavItem('Học kỳ', Icons.calendar_month_outlined),
          const _NavItem('Phát thông báo', Icons.campaign_outlined),
        ];

        return Scaffold(
          backgroundColor: AdminPalette.page,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              height: 64,
              decoration: const BoxDecoration(
                color: AdminPalette.surface,
                border: Border(bottom: BorderSide(color: AdminPalette.border)),
              ),
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 1050;
                          return Row(
                            children: [
                              const _Brand(),
                              if (!compact) ...[
                                const SizedBox(width: 16),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(
                                        items.length,
                                        (index) => _HeaderNav(
                                          item: items[index],
                                          active: index == _selected,
                                          onTap: () => setState(() => _selected = index),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (compact) const Spacer(),
                              const SizedBox(width: 8),
                              _ProfileBadge(name: name, photoUrl: photoUrl),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Đăng xuất',
                                onPressed: session.signOut,
                                icon: const Icon(Icons.logout_outlined, size: 18, color: AdminPalette.muted),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth >= 1050
                    ? const SizedBox.shrink()
                    : Container(
                        color: AdminPalette.surface,
                        height: 48,
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AdminPalette.border)),
                        ),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: List.generate(
                            items.length,
                            (index) => _HeaderNav(
                              item: items[index],
                              active: index == _selected,
                              onTap: () => setState(() => _selected = index),
                            ),
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: _buildPage(_selected),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, {this.badge});
  final String label;
  final IconData icon;
  final String? badge;
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/exematching_logo.png',
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        semanticLabel: 'ExeMatching',
      ),
      const SizedBox(width: 8),
      const Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.5),
          children: [
            TextSpan(
              text: 'Exe',
              style: TextStyle(color: AdminPalette.ink),
            ),
            TextSpan(
              text: 'Matching',
              style: TextStyle(color: AdminPalette.primary),
            ),
          ],
        ),
      ),
    ],
  );
}

class _HeaderNav extends StatelessWidget {
  const _HeaderNav({required this.item, required this.active, required this.onTap});
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: active ? AdminPalette.primary : Colors.transparent, width: 2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 16, color: active ? AdminPalette.primary : AdminPalette.muted),
          const SizedBox(width: 6),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? AdminPalette.primary : AdminPalette.muted,
            ),
          ),
          if (item.badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AdminPalette.warningLight,
                border: Border.all(color: const Color(0xFFFDE68A)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.badge!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AdminPalette.warning,
                  height: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AdminPalette.hover,
      border: Border.all(color: AdminPalette.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: photoUrl != null && photoUrl!.isNotEmpty
              ? Image.network(
                  photoUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => CircleAvatar(
                    radius: 16,
                    backgroundColor: AdminPalette.primaryLight,
                    foregroundColor: AdminPalette.primaryDark,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              : CircleAvatar(
                  radius: 16,
                  backgroundColor: AdminPalette.primaryLight,
                  foregroundColor: AdminPalette.primaryDark,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'A',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminPalette.ink),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AdminPalette.subtle,
                border: Border.all(color: AdminPalette.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Quản trị viên',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AdminPalette.muted),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
