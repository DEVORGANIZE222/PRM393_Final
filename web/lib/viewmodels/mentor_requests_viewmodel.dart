import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

/// The lecturer's queue: live requests from team leaders, and their teams.
class MentorRequestsViewModel extends ChangeNotifier {
  MentorRequestsViewModel(this._mentors, this._mentorId);

  final MentorRepository _mentors;

  /// The signed-in lecturer's `users/{uid}.mentorId`, or null for other staff.
  final Future<String?> Function() _mentorId;
  StreamSubscription<List<MentorRequest>>? _watch;

  ViewState<Mentor> state = const Loading();
  List<MentorRequest> requests = const [];
  List<Team> teams = const [];
  bool processing = false;

  int get pendingCount => requests.where((r) => r.isPending).length;

  Future<void> load() async {
    state = const Loading();
    notifyListeners();
    try {
      final id = await _mentorId();
      if (id == null) {
        state = const Empty();
        notifyListeners();
        return;
      }
      await _refreshProfile(id);
      await _watch?.cancel();
      _watch = _mentors.watchRequestsForMentor(id).listen((list) async {
        requests = list;
        // A request just accepted changes the quota and the team list.
        await _refreshProfile(id);
        notifyListeners();
      }, onError: _fail);
    } catch (e) {
      _fail(e);
    }
    notifyListeners();
  }

  Future<void> _refreshProfile(String id) async {
    final mentor = await _mentors.getMentor(id);
    teams = await _mentors.teamsOfMentor(id);
    state = Data(mentor);
  }

  void _fail(Object e) {
    state = Failure(e is AppFailure ? e : AppFailure.unexpected(e));
    notifyListeners();
  }

  Future<AppFailure?> respond(MentorRequest request, {required bool accept, String? reason}) async {
    processing = true;
    notifyListeners();
    try {
      await _mentors.respond(request: request, accept: accept, reason: reason);
      return null;
    } catch (e) {
      return e is AppFailure ? e : AppFailure.unexpected(e);
    } finally {
      processing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }
}
