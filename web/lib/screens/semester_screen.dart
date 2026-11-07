import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

class SemesterScreen extends StatefulWidget {
  const SemesterScreen({super.key});
  @override
  State<SemesterScreen> createState() => _SemesterScreenState();
}

class _SemesterScreenState extends State<SemesterScreen> {
  final _service = SemesterService();
  String _filter = 'all';
  String _query = '';
  int _retry = 0;

  Future<void> _edit([Semester? current]) async {
    final result = await showDialog<Semester>(
      context: context,
      builder: (_) => _SemesterDialog(initial: current),
    );
    if (result == null) return;
    try {
      await _service.save(result);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu học kỳ.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể lưu học kỳ: $error')));
    }
  }

  Future<void> _activate(Semester semester) async {
    try {
      await _service.activate(semester);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${semester.name} đang là học kỳ áp dụng cho mobile.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể kích hoạt: $error')));
    }
  }

  Future<void> _archive(Semester semester) async {
    try {
      await _service.archive(semester);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu trữ học kỳ.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể lưu trữ học kỳ: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Semester>>(
    key: ValueKey(_retry),
    stream: _service.watchAll(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, color: AdminPalette.danger, size: 30),
                  const SizedBox(height: 12),
                  const Text('Không thể tải học kỳ. Kiểm tra Firestore Rules.'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () => setState(() => _retry++), child: const Text('Thử lại')),
                ],
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final all = snapshot.data!;
      final countAll = all.length;
      final countActive = all.where((item) => item.isActive).length;
      final countArchived = all.where((item) => item.status == 'archived').length;
      final query = _query.trim().toLowerCase();
      final items = all
          .where(
            (semester) =>
                (_filter == 'all' || (_filter == 'active' ? semester.isActive : semester.status == 'archived')) &&
                (query.isEmpty || semester.name.toLowerCase().contains(query)),
          )
          .toList();
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quản lý Học kỳ',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AdminPalette.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Khởi tạo mốc ghép nhóm và mở đăng ký cho ứng dụng sinh viên.',
                        style: TextStyle(fontSize: 14, color: AdminPalette.muted),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo học kỳ mới'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminPalette.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 320,
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Tìm kiếm học kỳ...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AdminPalette.subtle,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TabPill(
                    label: 'Tất cả ($countAll)',
                    active: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  _TabPill(
                    label: 'Đang diễn ra ($countActive)',
                    active: _filter == 'active',
                    onTap: () => setState(() => _filter = 'active'),
                  ),
                  _TabPill(
                    label: 'Đã kết thúc ($countArchived)',
                    active: _filter == 'archived',
                    onTap: () => setState(() => _filter = 'archived'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Chưa có học kỳ nào. Tạo học kỳ đầu tiên để đồng bộ thời gian đăng ký cho mobile.'),
                ),
              )
            else
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: items
                    .map(
                      (semester) => _SemesterCard(
                        semester: semester,
                        onEdit: () => _edit(semester),
                        onActivate: semester.isActive || semester.status == 'archived'
                            ? null
                            : () => _activate(semester),
                        onArchive: semester.isActive || semester.status == 'archived' ? null : () => _archive(semester),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      );
    },
  );
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.label, required this.active, required this.onTap});
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

class _SemesterCard extends StatelessWidget {
  const _SemesterCard({required this.semester, this.onEdit, this.onActivate, this.onArchive});
  final Semester semester;
  final VoidCallback? onEdit, onActivate, onArchive;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 480,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(semester.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                ),
                _Chip(
                  text: semester.isActive
                      ? 'Đang kích hoạt'
                      : semester.status == 'archived'
                      ? 'Đã lưu trữ'
                      : 'Bản nháp',
                  tone: semester.isActive ? AdminPalette.primary : AdminPalette.muted,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${_date(semester.startsAt)} — ${_date(semester.endsAt)}',
              style: const TextStyle(color: AdminPalette.muted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AdminPalette.subtle, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mở đăng ký: ${_date(semester.registrationOpensAt)}'),
                  const SizedBox(height: 6),
                  Text('Đóng đăng ký: ${_date(semester.registrationClosesAt)}'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: onEdit, child: const Text('Chỉnh sửa')),
                if (onActivate != null) FilledButton(onPressed: onActivate, child: const Text('Kích hoạt')),
                if (onArchive != null)
                  TextButton(
                    onPressed: onArchive,
                    style: TextButton.styleFrom(foregroundColor: AdminPalette.danger),
                    child: const Text('Lưu trữ'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.tone});
  final String text;
  final Color tone;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: tone.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tone),
    ),
  );
}

class _SemesterDialog extends StatefulWidget {
  const _SemesterDialog({this.initial});
  final Semester? initial;
  @override
  State<_SemesterDialog> createState() => _SemesterDialogState();
}

class _SemesterDialogState extends State<_SemesterDialog> {
  late final TextEditingController _name;
  late DateTime _start, _end, _opens, _closes;
  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    final now = DateTime.now();
    _name = TextEditingController(text: item?.name ?? '');
    _start = item?.startsAt ?? now;
    _end = item?.endsAt ?? now.add(const Duration(days: 90));
    _opens = item?.registrationOpensAt ?? now;
    _closes = item?.registrationClosesAt ?? now.add(const Duration(days: 30));
  }

  Future<void> _pick(void Function(DateTime) set, DateTime current) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: current,
    );
    if (value != null) setState(() => set(value));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Tạo học kỳ' : 'Chỉnh sửa học kỳ'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tên học kỳ *'),
          ),
          const SizedBox(height: 12),
          _DateRow(label: 'Bắt đầu', value: _start, onTap: () => _pick((v) => _start = v, _start)),
          _DateRow(label: 'Kết thúc', value: _end, onTap: () => _pick((v) => _end = v, _end)),
          _DateRow(label: 'Mở đăng ký', value: _opens, onTap: () => _pick((v) => _opens = v, _opens)),
          _DateRow(label: 'Đóng đăng ký', value: _closes, onTap: () => _pick((v) => _closes = v, _closes)),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
      FilledButton(
        onPressed: () {
          if (_name.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            Semester(
              id: widget.initial?.id ?? '',
              name: _name.text,
              startsAt: _start,
              endsAt: _end,
              registrationOpensAt: _opens,
              registrationClosesAt: _closes,
              status: widget.initial?.status ?? 'draft',
            ),
          );
        },
        child: const Text('Lưu'),
      ),
    ],
  );
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text(_SemesterCard._date(value)),
    ),
  );
}
