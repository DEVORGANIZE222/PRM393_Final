import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border, BorderStyle;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/roster_entry.dart';
import '../services/admin_roster_service.dart';
import '../viewmodels/admin_roster_viewmodel.dart';

class RosterScreen extends StatelessWidget {
  const RosterScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AdminRosterViewModel(AdminRosterService())..load(),
    child: const _RosterView(),
  );
}

class _RosterView extends StatelessWidget {
  const _RosterView();

  Future<void> _selectRoster(BuildContext context) async {
    final model = context.read<AdminRosterViewModel>();
    try {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
        withData: true,
      );
      final bytes = selected?.files.single.bytes;
      if (bytes == null || !context.mounted) {
        return;
      }
      final extension = selected!.files.single.extension?.toLowerCase();
      if (extension == 'xlsx') {
        await model.importEntries(_parseXlsx(bytes));
      } else {
        await model.importCsv(utf8.decode(bytes, allowMalformed: true));
      }
    } catch (error) {
      model.reportImportError(error);
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 48),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quản lý Sinh viên & Roster', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text(
                    'Nhập danh sách sinh viên đủ điều kiện làm Dự án Khởi nghiệp từ file Excel. Hệ thống sẽ tự động đồng bộ email vào Google Access.',
                  ),
                ],
              ),
            ),
            Chip(label: Text('${model.entries.length} sinh viên đã nạp')),
          ],
        ),
        const SizedBox(height: 24),
        if (model.error != null) _Banner(message: model.error!, error: true),
        if (model.success != null) _Banner(message: model.success!, error: false),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Import danh sách Roster', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text('Chọn tệp Excel (.xlsx) hoặc CSV có các cột MSSV, Họ tên, Email/Gmail và Ngành đào tạo.'),
                const SizedBox(height: 18),
                InkWell(
                  onTap: model.importing ? null : () => _selectRoster(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    height: 156,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFDFB),
                      border: Border.all(color: const Color(0xFFB7D9C2), style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, size: 40, color: Color(0xFF168442)),
                        const SizedBox(height: 10),
                        Text(
                          model.importing ? 'Đang đọc và nhập dữ liệu…' : 'Nhấn để chọn tệp .xlsx / .csv',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        const Text('Tối đa 2.000 sinh viên; dữ liệu cũ được cập nhật an toàn.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          onChanged: model.setQuery,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Danh sách sinh viên trong hệ thống',
            hintText: 'Tìm theo mã số, tên hoặc email...',
          ),
        ),
        const SizedBox(height: 16),
        if (model.loading)
          const Center(
            child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
          )
        else
          _RosterTable(
            entries: model.visibleEntries,
            updatingEmail: model.updatingEmail,
            onEnabledChanged: model.setEnabled,
          ),
        const SizedBox(height: 16),
        const Text('Import chỉ cập nhật roster và Google Access whitelist. Hồ sơ mobile hiện có không bị ghi đè.'),
      ],
    );
  }
}

class _RosterTable extends StatelessWidget {
  const _RosterTable({required this.entries, required this.updatingEmail, required this.onEnabledChanged});
  final List<RosterEntry> entries;
  final String? updatingEmail;
  final Future<void> Function(RosterEntry, bool) onEnabledChanged;
  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Center(child: Text('No roster data yet. Import a CSV to seed Google Access.')),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF1F5F9)),
          columns: const [
            DataColumn(label: Text('STUDENT')),
            DataColumn(label: Text('EMAIL')),
            DataColumn(label: Text('MAJOR')),
            DataColumn(label: Text('GOOGLE ACCESS')),
          ],
          rows: entries
              .map(
                (entry) => DataRow(
                  cells: [
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.fullName.isEmpty ? 'Unnamed student' : entry.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (entry.studentCode.isNotEmpty)
                            Text(entry.studentCode, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    DataCell(Text(entry.email)),
                    DataCell(Text(entry.major.isEmpty ? '—' : entry.major)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: entry.enabled,
                            onChanged: updatingEmail == entry.email ? null : (value) => onEnabledChanged(entry, value),
                          ),
                          Text(entry.enabled ? 'Enabled' : 'Disabled'),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.error});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFEDEC) : const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: error ? const Color(0xFFB42318) : const Color(0xFF067647))),
    ),
  );
}
