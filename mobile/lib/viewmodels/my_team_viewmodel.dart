import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/mentor.dart';
import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

enum TeamPhase { inFormation, electLeader, readyToLock, locked }

/// SCR_05: team workspace. Empty state = not in a team.
class MyTeamViewModel extends ChangeNotifier {
  MyTeamViewModel(this._student, this._teams, this._mentors, this._crash);

  final Student _student;
  final TeamRepository _teams;
  final MentorRepository _mentors;
  final CrashReporter _crash;
  StreamSubscription<Team?>? _watch;
  StreamSubscription<MentorRequest?>? _requestWatch;
  String? _requestTeamId;

  ViewState<Team> state = const Loading();
  bool leaving = false;

  /// The team's mentor request, kept live for the Mentor card.
  MentorRequest? mentorRequest;

  String get myId => _student.id;

  bool isLeader(Team t) => t.hasLeader && t.leaderId == _student.id;
  bool hasVoted(Team t) => t.votes.containsKey(_student.id);

  TeamPhase phaseOf(Team t) {
    if (t.locked) return TeamPhase.locked;
    if (!t.hasLeader) return TeamPhase.electLeader;
    if (!t.meetsSizeRule) return TeamPhase.inFormation;
    return TeamPhase.readyToLock;
  }

  Future<void> load() async {
    state = const Loading();
    notifyListeners();
    try {
      final team = await _teams.teamOf(_student.id);
      state = team == null ? const Empty() : Data(team);
      _followRequest(team);
      await _watch?.cancel();
      _watch = _teams.watchTeamOf(_student.id).listen(
        (t) {
          state = t == null ? const Empty() : Data(t);
          _followRequest(t);
          notifyListeners();
        },
        onError: (Object e, StackTrace st) async {
          state = Failure(await toFailure(e, st, crash: _crash, reason: 'my_team_watch'));
          notifyListeners();
        },
      );
    } catch (e, st) {
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'my_team_load'));
    }
    notifyListeners();
  }

  void _followRequest(Team? team) {
    if (team?.id == _requestTeamId) return;
    _requestTeamId = team?.id;
    _requestWatch?.cancel();
    mentorRequest = null;
    if (team == null) return;
    _requestWatch = _mentors.watchRequestOfTeam(team.id).listen(
      (request) {
        mentorRequest = request;
        notifyListeners();
      },
      // The rest of My Team still works; only the card falls back to "no request".
      onError: (Object e, StackTrace st) => _crash.recordError(e, st, reason: 'my_team_mentor_request'),
    );
  }

  Future<AppFailure?> leave(Team team) async {
    leaving = true;
    notifyListeners();
    try {
      await _teams.leaveTeam(team.id, _student.id);
      state = const Empty();
      return null;
    } catch (e, st) {
      return toFailure(e, st, crash: _crash, reason: 'leave_team');
    } finally {
      leaving = false;
      notifyListeners();
    }
  }

  Future<AppFailure?> seedMembers(Team team, {int count = 2}) async {
    try {
      await _teams.seedMembersToTeam(team.id, count: count);
      await load();
      return null;
    } catch (e, st) {
      return toFailure(e, st, crash: _crash, reason: 'seed_members');
    }
  }

  bool unlocking = false;

  Future<AppFailure?> unlock(Team team) async {
    unlocking = true;
    notifyListeners();
    try {
      final updated = await _teams.unlockTeam(team.id, _student.id);
      state = Data(updated);
      return null;
    } catch (e, st) {
      return toFailure(e, st, crash: _crash, reason: 'unlock_team');
    } finally {
      unlocking = false;
      notifyListeners();
    }
  }

  bool _disposed = false;

  // Async error handlers can finish after the screen closed.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _watch?.cancel();
    _requestWatch?.cancel();
    super.dispose();
  }
}
