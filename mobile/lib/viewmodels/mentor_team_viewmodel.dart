import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

/// A team the lecturer supervises: roster, leader and how to reach them.
class MentorTeamViewModel extends ChangeNotifier {
  MentorTeamViewModel(this.teamId, this._me, this._teams, this._crash);

  final String teamId;
  final Student _me;
  final TeamRepository _teams;
  final CrashReporter _crash;
  StreamSubscription<Team>? _watch;

  ViewState<Team> state = const Loading();

  /// Only the lecturer the team accepted sees its contact details.
  bool supervises(Team team) => team.mentorId != null && team.mentorId == _me.mentorId;

  /// Every member's address, leader first, without duplicates.
  List<String> emails(Team team) {
    final ordered = [
      ...team.members.where((m) => m.studentId == team.leaderId),
      ...team.members.where((m) => m.studentId != team.leaderId),
    ];
    return {for (final m in ordered) m.contactEmail.trim()}.where((e) => e.contains('@')).toList();
  }

  Future<void> load() async {
    state = const Loading();
    notifyListeners();
    try {
      state = Data(await _teams.getTeam(teamId));
      await _watch?.cancel();
      _watch = _teams.watchTeam(teamId).listen(
        (t) {
          state = Data(t);
          notifyListeners();
        },
        onError: (Object e, StackTrace st) async {
          state = Failure(await toFailure(e, st, crash: _crash, reason: 'mentor_team_watch'));
          notifyListeners();
        },
      );
    } catch (e, st) {
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'mentor_team_load'));
    }
    notifyListeners();
  }

  bool _disposed = false;

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
