import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:core/core.dart' show TeamSubmission, TeamSubmissionService;

import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

enum CheckStatus { passed, pending, failed }

class LockCheck {
  const LockCheck(this.id, this.title, this.detail, this.status);
  final String id;
  final String title;
  final String detail;
  final CheckStatus status;
}

/// SCR_07: verification before the irreversible lock, with the < 4 members
/// error and the Waiting Pool recovery (Flow 3).
class LockReviewViewModel extends ChangeNotifier {
  LockReviewViewModel(this._student, this._teams, this._submissions, this._analytics, this._crash);

  final Student _student;
  final TeamRepository _teams;
  final TeamSubmissionService _submissions;
  final AnalyticsService _analytics;
  final CrashReporter _crash;
  StreamSubscription<Team>? _watch;
  StreamSubscription<TeamSubmission?>? _submissionWatch;

  ViewState<Team> state = const Loading();
  bool inviting = false;
  bool locking = false;
  TeamSubmission? submission;

  /// Set when a pool student joins while this screen is open.
  String? lastJoinedName;

  String get myId => _student.id;

  bool isLeader(Team t) => t.hasLeader && t.leaderId == _student.id;

  List<LockCheck> checks(Team t) => [
    LockCheck(
      'size',
      'Team size',
      '${t.memberCount} of ${TeamRules.minMembers} minimum members',
      t.meetsSizeRule ? CheckStatus.passed : CheckStatus.failed,
    ),
    LockCheck(
      'leader',
      'Leader elected',
      t.hasLeader ? '${t.leader!.fullName} · ${t.votesFor(t.leaderId!)} votes' : 'Waiting for a majority vote',
      t.hasLeader ? CheckStatus.passed : CheckStatus.pending,
    ),
    LockCheck('mentor', 'Supervisor assigned', t.supervisor, CheckStatus.passed),
  ];

  bool canLock(Team t) => !t.locked && isLeader(t) && checks(t).every((c) => c.status == CheckStatus.passed);

  /// Plain-language reason the lock button is disabled (shown under it).
  String? blockedReason(Team t) {
    if (t.locked) return null;
    if (!t.meetsSizeRule) return 'Available when your team has ${TeamRules.minMembers} members.';
    if (!t.hasLeader) return 'Available after your team elects a leader.';
    if (!isLeader(t)) return 'Only ${t.leader!.fullName}, the team leader, can lock the roster.';
    return null;
  }

  Future<void> load() async {
    state = const Loading();
    notifyListeners();
    try {
      final team = await _teams.teamOf(_student.id);
      if (team == null) {
        state = const Empty();
      } else {
        await _crash.setKey('team_id', team.id);
        state = Data(team);
        await _watch?.cancel();
        await _submissionWatch?.cancel();
        _submissionWatch = _submissions.watchForTeam(team.id).listen((value) {
          submission = value;
          notifyListeners();
        });
        _watch = _teams
            .watchTeam(team.id)
            .listen(
              (t) {
                final before = state is Data<Team> ? (state as Data<Team>).value.memberCount : t.memberCount;
                if (t.memberCount > before) lastJoinedName = t.members.last.fullName;
                state = Data(t);
                notifyListeners();
              },
              // e.g. the team was deleted or access was revoked: show the error
              // state with Retry instead of an uncaught zone error.
              onError: (Object e, StackTrace st) async {
                state = Failure(await toFailure(e, st, crash: _crash, reason: 'lock_review_watch'));
                notifyListeners();
              },
            );
      }
    } catch (e, st) {
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'lock_review_load'));
    }
    notifyListeners();
  }

  Future<({int? invited, AppFailure? failure})> inviteFromPool() async {
    final s = state;
    if (s is! Data<Team>) return (invited: null, failure: null);
    inviting = true;
    notifyListeners();
    try {
      final n = await _teams.inviteFromPool(s.value.id);
      await _analytics.logInviteFromPool(teamId: s.value.id, invited: n);
      return (invited: n, failure: null);
    } catch (e, st) {
      return (invited: null, failure: await toFailure(e, st, crash: _crash, reason: 'invite_from_pool'));
    } finally {
      inviting = false;
      notifyListeners();
    }
  }

  Future<AppFailure?> lock() async {
    final s = state;
    if (s is! Data<Team>) return null;
    locking = true;
    notifyListeners();
    try {
      final team = await _teams.lockTeam(s.value.id, _student.id);
      await _submissions.submit(
        teamId: team.id,
        leaderId: _student.id,
        teamName: team.name,
        lockCode: team.lockCode ?? '',
        memberSnapshot: team.members
            .map(
              (member) => <String, dynamic>{
                'studentId': member.studentId,
                'fullName': member.fullName,
                'studentCode': member.studentCode,
                'email': member.email,
                'role': member.role,
              },
            )
            .toList(growable: false),
      );
      await _crash.setKey('team_id', team.id);
      state = Data(team);
      await _analytics.logLockRoster(teamId: team.id, memberCount: team.memberCount);
      return null;
    } catch (e, st) {
      return toFailure(e, st, crash: _crash, reason: 'lock_roster');
    } finally {
      locking = false;
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
    _submissionWatch?.cancel();
    super.dispose();
  }
}
