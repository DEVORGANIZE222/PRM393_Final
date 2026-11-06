import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/admin_theme.dart';
import '../viewmodels/admin_session_viewmodel.dart';
import 'google_access_screen.dart';
import 'dashboard_screen.dart';
import 'groups_screen.dart';
import 'roster_screen.dart';
import 'management_screen.dart';
import 'review_queue_screen.dart';
import 'announcement_screen.dart';

/// Mirrors the reference EXEMatching shell: 64px white header, a centred
/// 1240px container and a green underline for the active navigation item.
class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});
  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _selected = 0;
  static const _items = [
    _NavItem('Tổng quan', Icons.dashboard_outlined),
    _NavItem('Sinh viên', Icons.people_outline),
    _NavItem('Học kỳ', Icons.calendar_month_outlined),
    _NavItem('Nhóm & Đề tài', Icons.layers_outlined),
    _NavItem('Google Access', Icons.shield_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSessionViewModel>();
    final profileName = session.firebaseUser?.displayName ?? session.profile?.displayName;
    final name = profileName == null || profileName.isEmpty
        ? (session.firebaseUser?.email?.split('@').first ?? 'Quản trị viên')
        : profileName;
    final photoUrl = session.firebaseUser?.photoURL;
    final pages = [
      DashboardScreen(
        onOpenReview: () => setState(() => _selected = 5),
        onOpenAnnouncements: () => setState(() => _selected = 6),
      ),
      const RosterScreen(),
      const ManagementScreen(),
      const GroupsScreen(),
      const GoogleAccessScreen(),
      const ReviewQueueScreen(),
      const AnnouncementScreen(),
    ];
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(77),
        child: Container(
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
                      final compact = constraints.maxWidth < 860;
                      return Row(
                        children: [
                          const _Brand(),
                          if (!compact) ...[
                            const SizedBox(width: 34),
                            Expanded(
                              child: Row(
                                children: List.generate(
                                  _items.length,
                                  (index) => _HeaderNav(
                                    item: _items[index],
                                    active: index == _selected,
                                    onTap: () => setState(() => _selected = index),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (compact) const Spacer(),
                          if (!compact) _ProfileBadge(name: name, photoUrl: photoUrl),
                          if (!compact) const SizedBox(width: 10),
                          IconButton(
                            tooltip: 'Đăng xuất',
                            onPressed: session.signOut,
                            icon: const Icon(Icons.logout_outlined, size: 20),
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
            builder: (context, constraints) => constraints.maxWidth >= 900
                ? const SizedBox.shrink()
                : Container(
                    color: AdminPalette.surface,
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: List.generate(
                        _items.length,
                        (index) => _HeaderNav(
                          item: _items[index],
                          active: index == _selected,
                          onTap: () => setState(() => _selected = index),
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1240), child: pages[_selected]),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
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
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      border: Border.all(color: AdminPalette.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AdminPalette.primaryLight,
          foregroundColor: AdminPalette.primaryDark,
          backgroundImage: photoUrl == null || photoUrl!.isEmpty ? null : NetworkImage(photoUrl!),
          child: photoUrl == null || photoUrl!.isEmpty
              ? Text(name.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700))
              : null,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Text('Quản trị viên', style: TextStyle(fontSize: 11, color: AdminPalette.muted)),
          ],
        ),
      ],
    ),
  );
}
