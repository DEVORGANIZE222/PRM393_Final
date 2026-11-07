import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/roster_entry.dart';
import '../services/admin_roster_service.dart';
import '../theme/admin_theme.dart';
import '../viewmodels/admin_roster_viewmodel.dart';

/// EdTech SaaS Students & Roster Management — ExeMatching
/// Matches C:\Users\Administrator\Desktop\EXETeamMatching\fe\src\features\students\StudentsPage.jsx
/// Includes 2-column responsive layout, Excel import, manual single student addition,
/// and an ultra-fast virtualized roster list capable of displaying thousands of students with zero lag.
class RosterScreen extends StatelessWidget {
  const RosterScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AdminRosterViewModel(AdminRosterService())..load(),
    child: const _RosterView(),
  );
}

class _RosterView extends StatefulWidget {
  const _RosterView();

  @override
  State<_RosterView> createState() => _RosterViewState();
}

class _RosterViewState extends State<_RosterView> {
  String _addMode = 'excel'; // 'excel' | 'manual'
  String _selectedMajor = 'all';
  String _selectedFileName = '';
  Uint8List? _selectedFileBytes;
  int _page = 0;
  static const int _pageSize = 25;

  // Single manual student controllers
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _manualMajor = 'Software Engineering';

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
        withData: true,
      );
      if (selected == null || selected.files.isEmpty) return;
      final file = selected.files.first;
      setState(() {
        _selectedFileName = file.name;
        _selectedFileBytes = file.bytes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không thể chọn tệp: $e'), backgroundColor: AdminPalette.danger));
      }
    }
  }

  Future<void> _importFile(AdminRosterViewModel model) async {
    if (_selectedFileBytes == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vui lòng chọn tệp .xlsx hoặc .csv trước khi import.')));
      return;
    }

    try {
      if (_selectedFileName.toLowerCase().endsWith('.xlsx')) {
        await model.importEntries(_parseXlsx(_selectedFileBytes!));
      } else {
        await model.importCsv(utf8.decode(_selectedFileBytes!, allowMalformed: true));
      }
      setState(() {
        _selectedFileName = '';
        _selectedFileBytes = null;
      });
    } catch (error) {
      model.reportImportError(error);
    }
  }

  Future<void> _addSingleStudent(AdminRosterViewModel model) async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();

    if (code.isEmpty || name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vui lòng nhập đầy đủ MSSV, Họ tên và Email.')));
      return;
    }

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Địa chỉ email không hợp lệ.')));
      return;
    }

    await model.addSingle(
      RosterEntry(email: email, fullName: name, studentCode: code, major: _manualMajor, enabled: true),
    );

    if (mounted && model.error == null) {
      _codeController.clear();
      _nameController.clear();
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm sinh viên $code thành công!'), backgroundColor: AdminPalette.primary),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, AdminRosterViewModel model, RosterEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa sinh viên'),
        content: Text(
          'Bạn có chắc chắn muốn xóa sinh viên ${entry.fullName} (${entry.studentCode}) khỏi whitelist Google Access?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminPalette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await model.deleteStudent(entry.email);
    }
  }

  List<RosterEntry> _parseXlsx(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables.values.firstWhere((sheet) => sheet.rows.isNotEmpty);
    final rows = sheet.rows.map((row) => row.map((cell) => cell?.value?.toString().trim() ?? '').toList()).toList();
    final headerIndex = rows.indexWhere(
      (row) =>
          row.any((value) => _normalized(value).contains('email') || _normalized(value).contains('gmail')) &&
          row.any((value) => _normalized(value).contains('mssv')),
    );
    if (headerIndex < 0) throw const FormatException('Không tìm thấy hàng tiêu đề có MSSV và Email trong file Excel.');
    final headers = rows[headerIndex].map(_normalized).toList();
    int column(List<String> candidates) => headers.indexWhere((header) => candidates.any(header.contains));
    final email = column(['email', 'gmail']);
    final name = headers.indexWhere((header) => header == 'hoten' || header == 'fullname' || header == 'studentname');
    final code = column(['mssv', 'studentcode']);
    final major = column(['nganh', 'major']);
    if ([email, name, code, major].any((index) => index < 0)) {
      throw const FormatException('File Excel phải có các cột MSSV, Họ tên, Email/Gmail và Ngành.');
    }
    final unique = <String, RosterEntry>{};
    for (final row in rows.skip(headerIndex + 1)) {
      if (email >= row.length || !row[email].contains('@')) continue;
      String value(int index) => index >= 0 && index < row.length ? row[index] : '';
      final address = row[email].toLowerCase();
      if ([value(name), value(code), value(major)].any((value) => value.isEmpty)) continue;
      unique[address] = RosterEntry(
        email: address,
        fullName: value(name),
        studentCode: value(code),
        major: value(major),
      );
    }
    if (unique.isEmpty) {
      throw const FormatException(
        'Không có dòng sinh viên hoàn chỉnh (MSSV, Họ tên, Email/Gmail, Ngành) trong file Excel.',
      );
    }
    if (unique.length > 2000) {
      throw const FormatException('Mỗi lần import tối đa 2.000 sinh viên.');
    }
    return unique.values.toList();
  }

  String _normalized(String value) {
    const accents = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };
    return value
        .toLowerCase()
        .split('')
        .map((character) => accents[character] ?? character)
        .join()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AdminRosterViewModel>();

    // Filter by query and major
    final allEntries = model.entries;
    final term = model.query.trim().toLowerCase();
    final filtered = allEntries
        .where((entry) {
          final matchesQuery =
              term.isEmpty ||
              entry.email.toLowerCase().contains(term) ||
              entry.fullName.toLowerCase().contains(term) ||
              entry.studentCode.toLowerCase().contains(term) ||
              entry.major.toLowerCase().contains(term);

          final matchesMajor =
              _selectedMajor == 'all' || entry.major.toLowerCase().contains(_selectedMajor.toLowerCase());

          return matchesQuery && matchesMajor;
        })
        .toList(growable: false);

    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 9999);
    final safePage = _page.clamp(0, totalPages - 1);
    final pagedItems = filtered.skip(safePage * _pageSize).take(_pageSize).toList(growable: false);

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
                      'Quản lý Sinh viên & Roster',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AdminPalette.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Nhập danh sách sinh viên đủ điều kiện làm Dự án Khởi nghiệp từ file Excel hoặc tạo thủ công.',
                      style: TextStyle(fontSize: 14, color: AdminPalette.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AdminPalette.primaryLight,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AdminPalette.primaryBorder),
                ),
                child: Text(
                  '${allEntries.length} sinh viên đã nạp',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminPalette.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Notifications
          if (model.error != null) ...[_Banner(message: model.error!, error: true), const SizedBox(height: 16)],
          if (model.success != null) ...[_Banner(message: model.success!, error: false), const SizedBox(height: 16)],

          // ── 2-Column Responsive Layout (service-layout-grid) ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;

              final leftForm = Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mode Switcher Tabs
                      Row(
                        children: [
                          _ModeTab(
                            icon: Icons.table_chart_outlined,
                            label: 'Import Excel',
                            active: _addMode == 'excel',
                            onTap: () => setState(() => _addMode = 'excel'),
                          ),
                          const SizedBox(width: 8),
                          _ModeTab(
                            icon: Icons.person_add_outlined,
                            label: 'Thêm thủ công 1 sinh viên',
                            active: _addMode == 'manual',
                            onTap: () => setState(() => _addMode = 'manual'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Form 1: Excel Import
                      if (_addMode == 'excel') ...[
                        const Text(
                          'File Excel cần có các cột: MSSV, Họ tên, Email/Gmail và Ngành đào tạo.',
                          style: TextStyle(fontSize: 13, color: AdminPalette.muted),
                        ),
                        const SizedBox(height: 16),
                        // Drop Zone
                        InkWell(
                          onTap: model.importing ? null : _pickFile,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 140,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AdminPalette.hover,
                              border: Border.all(
                                color: _selectedFileName.isNotEmpty ? AdminPalette.primary : AdminPalette.borderStrong,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedFileName.isNotEmpty
                                      ? Icons.description_outlined
                                      : Icons.cloud_upload_outlined,
                                  size: 36,
                                  color: _selectedFileName.isNotEmpty ? AdminPalette.primary : AdminPalette.muted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedFileName.isNotEmpty ? _selectedFileName : 'Nhấn để chọn tệp .xlsx / .csv',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedFileName.isNotEmpty ? AdminPalette.primary : AdminPalette.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Hỗ trợ tệp bảng tính tối đa 2.000 sinh viên',
                                  style: TextStyle(fontSize: 12, color: AdminPalette.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: (model.importing || _selectedFileBytes == null) ? null : () => _importFile(model),
                          icon: model.importing
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.file_upload_outlined, size: 18),
                          label: Text(
                            model.importing ? 'Đang đọc và nhập dữ liệu...' : 'Import & Cấp quyền Google Access',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AdminPalette.primary,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],

                      // Form 2: Single Student Manual Add
                      if (_addMode == 'manual') ...[
                        TextField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: 'Mã số sinh viên (MSSV) *',
                            hintText: 'VD: SE170123',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên sinh viên *',
                            hintText: 'VD: Nguyễn Văn An',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email trường (@fpt.edu.vn) *',
                            hintText: 'VD: annvse170123@fpt.edu.vn',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _manualMajor,
                          decoration: const InputDecoration(labelText: 'Chuyên ngành đào tạo *'),
                          items: const [
                            DropdownMenuItem(value: 'Software Engineering', child: Text('Kỹ thuật phần mềm (SE)')),
                            DropdownMenuItem(value: 'Artificial Intelligence', child: Text('Trí tuệ nhân tạo (AI)')),
                            DropdownMenuItem(value: 'Information Assurance', child: Text('An toàn thông tin (IA)')),
                            DropdownMenuItem(value: 'Digital Marketing', child: Text('Digital Marketing (MKT)')),
                            DropdownMenuItem(value: 'International Business', child: Text('Kinh doanh quốc tế (IB)')),
                          ],
                          onChanged: (val) => setState(() => _manualMajor = val ?? 'Software Engineering'),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => _addSingleStudent(model),
                          icon: const Icon(Icons.person_add_outlined, size: 18),
                          label: const Text('Tạo tài khoản sinh viên'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AdminPalette.primary,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );

              final rightList = Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header & Counter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Danh sách sinh viên trong hệ thống',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AdminPalette.ink),
                          ),
                          Text(
                            '${filtered.length} / ${allEntries.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AdminPalette.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Filter Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (val) {
                                model.setQuery(val);
                                setState(() => _page = 0);
                              },
                              style: const TextStyle(fontSize: 13.5),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search, size: 20),
                                hintText: 'Tìm theo MSSV, họ tên, email hoặc ngành...',
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<String>(
                            value: _selectedMajor,
                            underline: const SizedBox.shrink(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminPalette.ink),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('Tất cả ngành')),
                              DropdownMenuItem(value: 'Software', child: Text('SE (Phần mềm)')),
                              DropdownMenuItem(value: 'Artificial', child: Text('AI (Trí tuệ NT)')),
                              DropdownMenuItem(value: 'Assurance', child: Text('IA (An toàn TT)')),
                              DropdownMenuItem(value: 'Marketing', child: Text('MKT (Marketing)')),
                              DropdownMenuItem(value: 'Business', child: Text('IB (Kinh doanh QT)')),
                            ],
                            onChanged: (val) => setState(() {
                              _selectedMajor = val ?? 'all';
                              _page = 0;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),

                      // ── Ultra-Fast Virtualized List Box ──
                      SizedBox(
                        height: 520,
                        child: model.loading
                            ? const Center(child: CircularProgressIndicator(color: AdminPalette.primary))
                            : filtered.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.people_outline, size: 36, color: AdminPalette.slate400),
                                      SizedBox(height: 8),
                                      Text(
                                        'Không tìm thấy sinh viên nào phù hợp.',
                                        style: TextStyle(color: AdminPalette.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: pagedItems.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = pagedItems[index];
                                  return _RosterRow(
                                    entry: item,
                                    isUpdating: model.updatingEmail == item.email,
                                    onToggleEnabled: (val) => model.setEnabled(item, val),
                                    onDelete: () => _confirmDelete(context, model, item),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      // ── Pagination Controls ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hiển thị ${filtered.isEmpty ? 0 : safePage * _pageSize + 1} – ${(safePage + 1) * _pageSize > filtered.length ? filtered.length : (safePage + 1) * _pageSize} trên ${filtered.length} sinh viên',
                            style: const TextStyle(fontSize: 12.5, color: AdminPalette.muted),
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: safePage > 0 ? () => setState(() => _page = safePage - 1) : null,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: const Size(36, 32),
                                ),
                                child: const Text('‹ Trước', style: TextStyle(fontSize: 12.5)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Trang ${safePage + 1} / $totalPages',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AdminPalette.ink,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: safePage < totalPages - 1
                                    ? () => setState(() => _page = safePage + 1)
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: const Size(36, 32),
                                ),
                                child: const Text('Sau ›', style: TextStyle(fontSize: 12.5)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 440, child: leftForm),
                    const SizedBox(width: 20),
                    Expanded(child: rightList),
                  ],
                );
              } else {
                return Column(children: [leftForm, const SizedBox(height: 20), rightList]);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? AdminPalette.subtle : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? AdminPalette.borderStrong : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: active ? AdminPalette.primary : AdminPalette.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AdminPalette.primary : AdminPalette.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.entry,
    required this.isUpdating,
    required this.onToggleEnabled,
    required this.onDelete,
  });

  final RosterEntry entry;
  final bool isUpdating;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initial = entry.fullName.isNotEmpty ? entry.fullName[0].toUpperCase() : 'S';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AdminPalette.primaryLight,
            foregroundColor: AdminPalette.primaryDark,
            child: Text(initial, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),

          // Student Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.fullName.isNotEmpty ? entry.fullName : 'Chưa có tên',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AdminPalette.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: entry.enabled ? AdminPalette.primaryLight : AdminPalette.warningLight,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        entry.enabled ? 'Google Access' : 'Tạm khóa',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: entry.enabled ? AdminPalette.primary : AdminPalette.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.studentCode.isNotEmpty ? entry.studentCode : 'MSSV'} · ${entry.email}',
                  style: const TextStyle(fontSize: 12, color: AdminPalette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Major Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AdminPalette.subtle,
              border: Border.all(color: AdminPalette.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              entry.major.isNotEmpty ? entry.major : 'Kỹ thuật PM',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminPalette.muted),
            ),
          ),
          const SizedBox(width: 8),

          // Google Access Toggle Switch
          if (isUpdating)
            const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Switch(value: entry.enabled, onChanged: onToggleEnabled, activeColor: AdminPalette.primary),

          // Delete Student Button
          IconButton(
            tooltip: 'Xóa khỏi whitelist',
            icon: const Icon(Icons.delete_outline, size: 18, color: AdminPalette.slate400),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.error});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? AdminPalette.dangerLight : AdminPalette.primaryLight,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: error ? const Color(0xFFFECACA) : AdminPalette.primaryBorder),
    ),
    child: Row(
      children: [
        Icon(
          error ? Icons.error_outline : Icons.check_circle_outline,
          color: error ? AdminPalette.danger : AdminPalette.primary,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: error ? AdminPalette.danger : AdminPalette.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
