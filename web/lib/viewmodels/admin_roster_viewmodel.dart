import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/roster_entry.dart';
import '../services/admin_roster_service.dart';

class AdminRosterViewModel extends ChangeNotifier {
  AdminRosterViewModel(this._service);
  final AdminRosterService _service;
  StreamSubscription<List<RosterEntry>>? _subscription;

  List<RosterEntry> entries = const [];
  String query = '';
  String? error;
  String? success;
  bool loading = true;
  bool importing = false;
  String? updatingEmail;

  List<RosterEntry> get visibleEntries {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return entries;
    return entries
        .where(
          (entry) =>
              entry.email.contains(term) ||
              entry.fullName.toLowerCase().contains(term) ||
              entry.studentCode.toLowerCase().contains(term),
        )
        .toList();
  }

  int get enabledCount => entries.where((entry) => entry.enabled).length;

  void load() {
    _subscription?.cancel();
    _subscription = _service.watchWhitelist().listen(
      (value) {
        entries = value;
        loading = false;
        notifyListeners();
      },
      onError: (_) {
        error = 'Cannot load the whitelist. Publish the Admin Firestore Rules, then try again.';
        loading = false;
        notifyListeners();
      },
    );
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  Future<void> importCsv(String contents) async {
    await importEntries(AdminRosterService.parseCsv(contents));
  }

  Future<void> importEntries(List<RosterEntry> entries) async {
    importing = true;
    error = null;
    success = null;
    notifyListeners();
    try {
      final result = await _service.importEntries(entries);
      success = '${result.imported} student email${result.imported == 1 ? '' : 's'} added to Google Access.';
    } on FormatException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Import failed. Verify the CSV format and your Firebase Admin access.';
    } finally {
      importing = false;
      notifyListeners();
    }
  }

  void reportImportError(Object error) {
    this.error = error is FormatException
        ? error.message
        : 'Không thể đọc tệp. Hãy chọn file CSV hoặc Excel (.xlsx) hợp lệ.';
    success = null;
    notifyListeners();
  }

  Future<void> setEnabled(RosterEntry entry, bool value) async {
    updatingEmail = entry.email;
    error = null;
    notifyListeners();
    try {
      await _service.setEnabled(entry, value);
    } catch (_) {
      error = 'Could not update ${entry.email}.';
    } finally {
      updatingEmail = null;
      notifyListeners();
    }
  }

  Future<void> addSingle(RosterEntry entry) async {
    error = null;
    success = null;
    notifyListeners();
    try {
      await _service.addSingleStudent(entry);
      success = 'Đã thêm sinh viên ${entry.studentCode} (${entry.fullName}) thành công!';
    } catch (e) {
      error = 'Không thể thêm sinh viên: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<void> deleteStudent(String email) async {
    try {
      await _service.deleteStudent(email);
      success = 'Đã xóa sinh viên khỏi hệ thống.';
    } catch (e) {
      error = 'Không thể xóa sinh viên: $e';
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
