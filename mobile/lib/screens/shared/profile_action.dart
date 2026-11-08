import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/notifications_viewmodel.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../../widgets/status.dart';

/// App-bar avatar that opens Profile (the only entry to Profile, DV-08).
class ProfileAction extends StatelessWidget {
  const ProfileAction({super.key});

  @override
  Widget build(BuildContext context) {
    final student = context.watch<SessionViewModel>().student;
    final unread = context.watch<NotificationsViewModel>().unread;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'btn_open_alerts',
          button: true,
          label: 'Alerts',
          child: IconButton(
            tooltip: 'Alerts',
            onPressed: () => context.push('/alerts'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(
                '$unread',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              backgroundColor: const Color(0xFFEF4444),
              child: const Icon(Icons.notifications_outlined, size: 22),
            ),
          ),
        ),
        Semantics(
          identifier: 'btn_open_profile',
          child: IconButton(
            tooltip: 'Profile',
            onPressed: () => context.go('/profile'),
            icon: MemberAvatar(
              initials: student?.initials ?? '?',
              avatarUrl: student?.avatarUrl,
              size: 34,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
