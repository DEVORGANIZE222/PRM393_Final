import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

sealed class JoinOutcome {
  const JoinOutcome();
}

final class Joined extends JoinOutcome {
  const Joined(this.team);
  final Team team;
}

/// The team filled up between opening it and confirming (Flow 1 alternative path).
final class TeamWasFull extends JoinOutcome {
  const TeamWasFull(this.team);
  final Team team;
}

final class JoinFailed extends JoinOutcome {
  const JoinFailed(this.failure);
  final AppFailure failure;
}

/// SCR_04: team detail and join (Flow 1).
class TeamDetailViewModel extends ChangeNotifier {
  TeamDetailViewModel(this._student, this._teams, this._analytics, this._crash, this.teamId);

  final Student _student;
  final TeamRepository _teams;
  final AnalyticsService _analytics;
  final CrashReporter _crash;
  final String teamId;

  ViewState<Team> state = const Loading();
  bool joining = false;

  /// Why the join button is disabled, or null when joining is allowed.
  String? joinBlockedReason(Team team) {
    if (team.isMember(_student.id)) return "You're already a member of this team.";
    if (team.locked) return 'This team is locked.';
    if (team.isFull) return 'This team is full (${team.memberCount}/${team.capacity}).';
    return null;
  }

  /// The slot the student would take, for the confirmation dialog.
  String slotFor(Team team) =>
      'Slot ${team.memberCount + 1} · ${team.openRoles.isEmpty ? 'Open role' : team.openRoles.first}';

  Student get applicant => _student;

  Future<void> load() async {
    state = const Loading();
    notifyListeners();
    try {
      final team = await _teams.getTeam(teamId);
      await _crash.setKey('team_id', team.id);
      state = Data(team);
      await _analytics.logViewTeam(teamId: team.id, teamCode: team.code);
    } catch (e, st) {
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'team_detail_load'));
    }
    notifyListeners();
  }

  Future<AppFailure?> seedMembers({int count = 2}) async {
    try {
      await _teams.seedMembersToTeam(teamId, count: count);
      await load();
      return null;
    } catch (e, st) {
      return toFailure(e, st, crash: _crash, reason: 'seed_members');
    }
  }

  Future<JoinOutcome> join() async {
    joining = true;
    notifyListeners();
    try {
      final team = await _teams.joinTeam(teamId, _student);
      await _crash.setKey('team_id', team.id);
      state = Data(team);
      await _analytics.logJoinTeam(teamId: team.id, memberCount: team.memberCount);
      return Joined(team);
    } on TeamFullException {
      return _reloadAfterTeamFilled();
    } on AlreadyInTeamException catch (e) {
      return JoinFailed(
        AppFailure(
          "You're already in Team ${e.teamCode}",
          'Leave Team ${e.teamCode} on My Team first, then join this one.',
          retryable: false,
        ),
      );
    } catch (e, st) {
      return JoinFailed(await toFailure(e, st, crash: _crash, reason: 'join_team'));
    } finally {
      joining = false;
      notifyListeners();
    }
  }

  /// The team filled up first: show its latest roster. The refetch can fail
  /// too (CR-01), and that must end as a JoinFailed, not escape join().
  Future<JoinOutcome> _reloadAfterTeamFilled() async {
    try {
      final latest = await _teams.getTeam(teamId);
      state = Data(latest);
      return TeamWasFull(latest);
    } catch (e, st) {
      return JoinFailed(await toFailure(e, st, crash: _crash, reason: 'join_team_reload'));
    }
  }
}
