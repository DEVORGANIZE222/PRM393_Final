import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

/// SCR_06: leader election (Flow 2).
class VotingViewModel extends ChangeNotifier {
  VotingViewModel(this._student, this._teams, this._analytics, this._crash);

  final Student _student;
  final TeamRepository _teams;
  final AnalyticsService _analytics;
  final CrashReporter _crash;

  ViewState<Team> state = const Loading();
  String? selected;
  bool submitting = false;

  String get myId => _student.id;
  String? myVote(Team t) => t.votes[_student.id];

  /// Lab 2 critique C-01: tallies stay hidden until the student has voted.
  bool showTally(Team t) => myVote(t) != null;

  /// Submitting a different candidate after voting needs the confirm dialog.
  bool isChange(Team t) => myVote(t) != null && selected != myVote(t);

  bool canSubmit(Team t) => !t.locked && selected != null && selected != myVote(t) && !submitting;

  Future<void> load() async {
    state = const Loading();
    notifyListeners();
    try {
      final team = await _teams.teamOf(_student.id);
      if (team == null) {
        state = const Empty();
      } else {
        state = Data(team);
        selected = team.votes[_student.id];
      }
    } catch (e, st) {
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'voting_load'));
    }
    notifyListeners();
  }

  void select(String candidateId) {
    selected = candidateId;
    notifyListeners();
  }

  /// Returns the updated team, or a failure to show.
  Future<({Team? team, AppFailure? failure})> submit() async {
    final current = state;
    if (current is! Data<Team> || selected == null) return (team: null, failure: null);
    final changed = myVote(current.value) != null;
    submitting = true;
    notifyListeners();
    try {
      final team = await _teams.castVote(current.value.id, _student.id, selected!);
      state = Data(team);
      await _analytics.logVote(teamId: team.id, changed: changed);
      return (team: team, failure: null);
    } catch (e, st) {
      return (team: null, failure: await toFailure(e, st, crash: _crash, reason: 'cast_vote'));
    } finally {
      submitting = false;
      notifyListeners();
    }
  }
}
