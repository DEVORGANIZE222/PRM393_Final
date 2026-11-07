import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

/// Mentor directory for admins: live profiles and every team's request.
class AdminMentorViewModel extends ChangeNotifier {
  AdminMentorViewModel(this._service);
  final MentorAdminService _service;
  StreamSubscription<List<Mentor>>? _mentorWatch;
  StreamSubscription<List<MentorRequest>>? _requestWatch;

  List<Mentor> mentors = const [];
  List<MentorRequest> requests = const [];
  String query = '';
  bool showArchived = false;
  bool loading = true;
  bool saving = false;
  String? error;
  String? success;

  List<Mentor> get visibleMentors {
    final term = query.trim().toLowerCase();
    return mentors.where((m) {
      if (m.archived != showArchived) return false;
      if (term.isEmpty) return true;
      return [m.fullName, m.email, m.department, ...m.expertise].join(' ').toLowerCase().contains(term);
    }).toList();
  }

  int get activeCount => mentors.where((m) => !m.archived).length;
  int get openSlots => mentors.where((m) => !m.archived).fold(0, (sum, m) => sum + m.remainingSlots);
  int get pendingCount => requests.where((r) => r.isPending).length;

  void load() {
    loading = true;
    error = null;
    notifyListeners();
    _mentorWatch?.cancel();
    _requestWatch?.cancel();
    void failed(Object _) {
      error = 'Không thể tải dữ liệu giảng viên. Kiểm tra quyền Admin và kết nối, rồi thử lại.';
      loading = false;
      notifyListeners();
    }

    _mentorWatch = _service.watchMentors().listen((value) {
      mentors = value;
      loading = false;
      notifyListeners();
    }, onError: failed);
    _requestWatch = _service.watchRequests().listen((value) {
      requests = value;
      notifyListeners();
    }, onError: failed);
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setShowArchived(bool value) {
    showArchived = value;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action, String done) async {
    saving = true;
    error = null;
    success = null;
    notifyListeners();
    try {
      await action();
      success = done;
      return true;
    } on AppFailure catch (e) {
      error = '${e.title}. ${e.cause}';
      return false;
    } catch (_) {
      error = 'Không thể lưu thay đổi. Kiểm tra quyền Admin và kết nối, rồi thử lại.';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> create(Mentor mentor) => _run(() => _service.create(mentor), 'Đã thêm ${mentor.fullName}.');

  Future<bool> update(Mentor before, Mentor after) =>
      _run(() => _service.update(before, after), 'Đã cập nhật ${after.fullName}.');

  Future<bool> setArchived(Mentor mentor, bool archived) => _run(
    () => _service.setArchived(mentor, archived),
    archived ? 'Đã lưu trữ ${mentor.fullName}.' : 'Đã khôi phục ${mentor.fullName}.',
  );

  @override
  void dispose() {
    _mentorWatch?.cancel();
    _requestWatch?.cancel();
    super.dispose();
  }
}
