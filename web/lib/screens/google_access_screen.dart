import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_roster_service.dart';
import '../theme/admin_theme.dart';
import '../viewmodels/admin_roster_viewmodel.dart';

class GoogleAccessScreen extends StatelessWidget {
  const GoogleAccessScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AdminRosterViewModel(AdminRosterService())..load(),
    child: const _GoogleAccessBody(),
  );
}

class _GoogleAccessBody extends StatelessWidget {
  const _GoogleAccessBody();
  @override
  Widget build(BuildContext context) {
    final model = context.watch<AdminRosterViewModel>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 38, 24, 48),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quản lý Google Access Whitelist', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text(
                    'Chỉ email FPT trong whitelist mới có thể đăng nhập ứng dụng sinh viên.',
                    style: TextStyle(color: AdminPalette.muted),
                  ),
                ],
              ),
            ),
            Text(
              '${model.enabledCount} email được phép',
              style: const TextStyle(color: AdminPalette.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Nhập roster CSV ở tab Sinh viên để đồng bộ email hợp lệ vào whitelist mà không ghi đè hồ sơ mobile.',
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (model.error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(model.error!, style: const TextStyle(color: AdminPalette.danger)),
            ),
          ),
        if (model.error != null) const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: model.setQuery,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tìm kiếm địa chỉ email...',
                  ),
                ),
                const SizedBox(height: 12),
                if (model.loading)
                  const Center(
                    child: Padding(padding: EdgeInsets.all(36), child: CircularProgressIndicator()),
                  )
                else if (model.visibleEntries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(child: Text('Chưa có email trong whitelist.')),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 480),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: model.visibleEntries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final entry = model.visibleEntries[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.email, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(entry.fullName.isEmpty ? 'Chưa có thông tin roster' : entry.fullName),
                          trailing: Switch(
                            value: entry.enabled,
                            onChanged: model.updatingEmail == entry.email
                                ? null
                                : (value) => model.setEnabled(entry, value),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
