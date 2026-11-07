import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/mentor.dart';
import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

/// The lecturer's home: live team requests to answer, and the teams they supervise.
class MentorPortalViewModel extends ChangeNotifier {
  MentorPortalViewModel(this._me, this._mentors, this._analytics, this._crash);

  final Student _me;
  final MentorRepository _mentors;
  final AnalyticsService _analytics;
  final CrashReporter _crash;
  StreamSubscription<List<MentorRequest>>? _watch;

  ViewState<Mentor> state = const Loading();
  List<MentorRequest> requests = const [];
  List<Team> teams = const [];
  bool processing = false;

  int get pendingCount => requests.where((r) => r.isPending).length;

  Future<void> load() async {
    state = const Loading();
    notifyListeners();
    final id = _me.mentorId!;
    try {
      await _refresh(id);
      await _watch?.cancel();
      _watch = _mentors.watchRequestsForMentor(id).listen(
        (list) async {
          requests = list;
          // A request just answered changes the quota and the team list.
          try {
            await _refresh(id);
          } catch (e, st) {
            state = Failure(await toFailure(e, st, crash: _crash, reason: 'mentor_portal_refresh'));
          }
          notifyListeners();
        },
        onError: (Object e, StackTrace st) async {
          state = Failure(await toFailure(e, st, crash: _crash, reason: 'mentor_portal_watch'));
          notifyListeners();
        },
      );
    } catch (e, st) {
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'mentor_portal_load'));
    }
    notifyListeners();
  }

  Future<void> _refresh(String id) async {
    final mentor = await _mentors.getMentor(id);
    teams = await _mentors.teamsOfMentor(id);
    state = Data(mentor);
  }

  Future<AppFailure?> respond(MentorRequest request, {required bool accept, String? reason}) async {
    processing = true;
    notifyListeners();
    try {
      await _mentors.respond(request: request, accept: accept, reason: reason);
      await _analytics.logRespondMentor(teamId: request.teamId, accepted: accept);
      return null;
    } catch (e, st) {
      return toFailure(e, st, crash: _crash, reason: 'respond_mentor');
    } finally {
      processing = false;
      notifyListeners();
    }
  }

  bool _disposed = false;

  // The stream callback can finish after the screen closed.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _watch?.cancel();
    super.dispose();
  }
}
