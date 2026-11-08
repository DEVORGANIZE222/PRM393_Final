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

  String? _message;
  bool _messageIsError = false;

  void _showMessage(String text, {bool isError = false}) {
    setState(() {
      _message = text;
      _messageIsError = isError;
    });
  }

  Future<void> _edit([Semester? current]) async {
    final result = await showDialog<Semester>(
      context: context,
      builder: (_) => _SemesterDialog(initial: current),
    );
    if (result == null) return;
    try {
      await _service.save(result);
      _showMessage('Đã lưu học kỳ ${result.name} thành công!');
    } catch (error) {
      _showMessage('Không thể lưu học kỳ: $error', isError: true);
    }
  }

  Future<void> _activate(Semester semester) async {
    try {
      await _service.activate(semester);
      _showMessage('${semester.name} đang là học kỳ kích hoạt chính thức cho toàn hệ thống.');
    } catch (error) {
      _showMessage('Không thể kích hoạt: $error', isError: true);
    }
  }

  Future<void> _archive(Semester semester) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận lưu trữ học kỳ'),
        content: Text('Bạn có chắc muốn lưu trữ học kỳ "${semester.name}"? Sinh viên sẽ không thể đăng ký trong học kỳ này nữa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AdminPalette.danger),
            child: const Text('Lưu trữ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.archive(semester);
      _showMessage('Đã lưu trữ học kỳ ${semester.name}.');
    } catch (error) {
      _showMessage('Không thể lưu trữ học kỳ: $error', isError: true);
    }
  }

  Future<void> _delete(Semester semester) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa học kỳ'),
        content: Text('Bạn có chắc muốn xóa vĩnh viễn học kỳ "${semester.name}"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AdminPalette.danger),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.delete(semester);
      _showMessage('Đã xóa học kỳ ${semester.name}.');
    } catch (error) {
      _showMessage('Không thể xóa học kỳ: $error', isError: true);
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
                  const Text('Không thể tải học kỳ. Vui lòng kiểm tra Firestore Rules.'),
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
      final now = DateTime.now();
      final countAll = all.length;
      final countActive = all.where((item) => item.isActive).length;
      final countEnded = all.where((item) => item.endsAt.isBefore(now) || item.status == 'archived').length;
      final query = _query.trim().toLowerCase();

      final items = all.where((semester) {
        final matchesFilter = switch (_filter) {
          'active' => semester.isActive,
          'ended' => semester.endsAt.isBefore(now) || semester.status == 'archived',
          _ => true,
        };
        final matchesQuery = query.isEmpty ||
            semester.name.toLowerCase().contains(query) ||
            semester.displayCode.toLowerCase().contains(query);
        return matchesFilter && matchesQuery;
      }).toList();

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top notification banner
            if (_message != null) ...[
              _TopBanner(
                message: _message!,
                isError: _messageIsError,
                onClose: () => setState(() => _message = null),
              ),
              const SizedBox(height: 20),
            ],

            // Page Header
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
                        'Khởi tạo các mốc thời gian ghép nhóm, gia hạn deadline và phân công mentor cho học kỳ.',
                        style: TextStyle(fontSize: 14, color: AdminPalette.muted),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tạo học kỳ mới'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminPalette.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tab Filter Bar & Search Input
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AdminPalette.subtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminPalette.border),
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
                        label: 'Đã kết thúc ($countEnded)',
                        active: _filter == 'ended',
                        onTap: () => setState(() => _filter = 'ended'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 300,
                  height: 40,
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18, color: AdminPalette.muted),
                      hintText: 'Tìm kiếm học kỳ...',
                      hintStyle: const TextStyle(fontSize: 13, color: AdminPalette.muted),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminPalette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminPalette.border),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Semesters Grid / List
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminPalette.border),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 42, color: AdminPalette.muted),
                    SizedBox(height: 12),
                    Text(
                      'Không tìm thấy học kỳ nào',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AdminPalette.ink),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Nhấn "Tạo học kỳ mới" để bắt đầu thiết lập mốc thời gian.',
                      style: TextStyle(fontSize: 13, color: AdminPalette.muted),
                    ),
                  ],
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
                        onActivate: semester.isActive ? null : () => _activate(semester),
                        onArchive: semester.status == 'archived' ? null : () => _archive(semester),
                        onDelete: () => _delete(semester),
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

class _TopBanner extends StatelessWidget {
  const _TopBanner({required this.message, required this.isError, required this.onClose});

  final String message;
  final bool isError;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bg = isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
    final border = isError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);
    final iconColor = isError ? AdminPalette.danger : AdminPalette.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 16),
            color: AdminPalette.muted,
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
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
                    BoxShadow(color: Color(0x0E000000), blurRadius: 4, offset: Offset(0, 1)),
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
  const _SemesterCard({
    required this.semester,
    required this.onEdit,
    this.onActivate,
    this.onArchive,
    required this.onDelete,
  });

  final Semester semester;
  final VoidCallback onEdit;
  final VoidCallback? onActivate;
  final VoidCallback? onArchive;
  final VoidCallback onDelete;

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isEnded = semester.endsAt.isBefore(now) || semester.status == 'archived';

    // Milestones
    final regCloses = semester.registrationClosesAt;
    final topicDeadline = semester.topicDeadline ?? regCloses;
    final mentorDeadline = semester.mentorDeadline ?? regCloses.add(const Duration(days: 7));

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminPalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Code Tag + Title & Status Badge + Action Icons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminPalette.subtle,
                        border: Border.all(color: AdminPalette.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        semester.displayCode,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      semester.name.trim().toUpperCase() == semester.displayCode.trim().toUpperCase()
                          ? 'Học kỳ ${semester.displayCode}'
                          : semester.name,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: AdminPalette.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (semester.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Text(
                        'Đang kích hoạt',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    )
                  else if (isEnded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Đã kết thúc',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Đã đóng',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_calendar_outlined, size: 17),
                        tooltip: 'Chỉnh sửa & Gia hạn deadline',
                        color: AdminPalette.muted,
                        splashRadius: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 17),
                        tooltip: 'Xóa học kỳ',
                        color: AdminPalette.muted,
                        splashRadius: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date row with Clock icon
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AdminPalette.muted),
              const SizedBox(width: 6),
              Text(
                '${_date(semester.startsAt)} — ${_date(semester.endsAt)}',
                style: const TextStyle(fontSize: 12.5, color: AdminPalette.muted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Milestones box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AdminPalette.subtle,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                _MilestoneRow(
                  label: 'Hạn ghép nhóm:',
                  value: _date(regCloses),
                ),
                const SizedBox(height: 8),
                _MilestoneRow(
                  label: 'Hạn chốt đề tài:',
                  value: _date(topicDeadline),
                ),
                const SizedBox(height: 8),
                _MilestoneRow(
                  label: 'Hạn ghép Mentor:',
                  value: _date(mentorDeadline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Chỉnh sửa & Gia hạn', style: TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              if (onActivate != null) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onActivate,
                  icon: const Icon(Icons.check_circle_outline, size: 15),
                  label: const Text('Kích hoạt', style: TextStyle(fontSize: 12.5)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminPalette.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminPalette.ink),
          ),
        ],
      );
}

class _SemesterDialog extends StatefulWidget {
  const _SemesterDialog({this.initial});
  final Semester? initial;

  @override
  State<_SemesterDialog> createState() => _SemesterDialogState();
}

class _SemesterDialogState extends State<_SemesterDialog> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late DateTime _start, _end, _regOpens, _regCloses, _topicDeadline, _mentorDeadline;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    final now = DateTime.now();

    _code = TextEditingController(text: item?.code ?? (item?.name ?? ''));
    _name = TextEditingController(text: item?.name ?? '');

    _start = item?.startsAt ?? now;
    _end = item?.endsAt ?? now.add(const Duration(days: 90));
    _regOpens = item?.registrationOpensAt ?? now;
    _regCloses = item?.registrationClosesAt ?? now.add(const Duration(days: 30));
    _topicDeadline = item?.topicDeadline ?? _regCloses;
    _mentorDeadline = item?.mentorDeadline ?? _regCloses.add(const Duration(days: 7));
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
        title: Text(
          widget.initial == null ? 'Tạo học kỳ mới' : 'Chỉnh sửa & Gia hạn học kỳ',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _code,
                        decoration: const InputDecoration(
                          labelText: 'Mã học kỳ (VD: FALL2026) *',
                          hintText: 'FALL2026',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Tên học kỳ *',
                          hintText: 'Học kỳ Fall 2026',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Khoảng thời gian học kỳ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminPalette.ink),
                ),
                const SizedBox(height: 6),
                _DateRow(label: 'Ngày bắt đầu', value: _start, onTap: () => _pick((v) => _start = v, _start)),
                _DateRow(label: 'Ngày kết thúc', value: _end, onTap: () => _pick((v) => _end = v, _end)),
                const Divider(height: 24),
                const Text(
                  'Các mốc Deadline quan trọng',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminPalette.ink),
                ),
                const SizedBox(height: 6),
                _DateRow(label: 'Mở đăng ký nhóm', value: _regOpens, onTap: () => _pick((v) => _regOpens = v, _regOpens)),
                _DateRow(label: 'Hạn ghép nhóm (Đóng ĐK)', value: _regCloses, onTap: () => _pick((v) => _regCloses = v, _regCloses)),
                _DateRow(label: 'Hạn chốt đề tài', value: _topicDeadline, onTap: () => _pick((v) => _topicDeadline = v, _topicDeadline)),
                _DateRow(label: 'Hạn ghép Mentor', value: _mentorDeadline, onTap: () => _pick((v) => _mentorDeadline = v, _mentorDeadline)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              if (_name.text.trim().isEmpty) return;
              final codeStr = _code.text.trim().isEmpty ? _name.text.trim().toUpperCase() : _code.text.trim().toUpperCase();
              Navigator.pop(
                context,
                Semester(
                  id: widget.initial?.id ?? '',
                  name: _name.text.trim(),
                  code: codeStr,
                  startsAt: _start,
                  endsAt: _end,
                  registrationOpensAt: _regOpens,
                  registrationClosesAt: _regCloses,
                  topicDeadline: _topicDeadline,
                  mentorDeadline: _mentorDeadline,
                  status: widget.initial?.status ?? 'draft',
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AdminPalette.primary),
            child: const Text('Lưu học kỳ'),
          ),
        ],
      );

  @override
  void dispose() {
    _code.dispose();
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: Text(_SemesterCard._date(value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                foregroundColor: AdminPalette.ink,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: AdminPalette.subtle,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      );
}
