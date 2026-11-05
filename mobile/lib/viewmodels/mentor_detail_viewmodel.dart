import 'package:flutter/foundation.dart';

import '../models/mentor.dart';
import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

/// What the signed-in student can do about this lecturer.
enum MentorAction { assigned, otherMentor, noTeam, pendingHere, pendingElsewhere, notLeader, quotaFull, canRequest }

/// Lecturer profile, and the only place a team leader sends or withdraws a request.
class MentorDetailViewModel extends ChangeNotifier {
  MentorDetailViewModel(this.mentorId, this._me, this._mentors, this._teams, this._analytics, this._crash);

  final String mentorId;
  final Student _me;
  final MentorRepository _mentors;
  final TeamRepository _teams;
  final AnalyticsService _analytics;
  final CrashReporter _crash;

  ViewState<Mentor> state = const Loading();
  Team? team;
  MentorRequest? request;
  bool sending = false;
  bool withdrawing = false;

  bool get isLeader => team != null && team!.hasLeader && team!.leaderId == _me.id;

  /// True when this lecturer declined the team's last request.
  bool get declinedHere => request != null && request!.isRejected && request!.mentorId == mentorId;

  MentorAction actionFor(Mentor mentor) {
    final t = team;
    if (t == null) return MentorAction.noTeam;
    if (t.mentorId == mentor.id) return MentorAction.assigned;
    if (t.hasMentor) return MentorAction.otherMentor;
    if (request != null && request!.isPending) {
      return request!.mentorId == mentor.id ? MentorAction.pendingHere : MentorAction.pendingElsewhere;
    }
    if (!isLeader) return MentorAction.notLeader;
    if (!mentor.isAvailable) return MentorAction.quotaFull;
    return MentorAction.canRequest;
  }

  Future<void> load() async {
    state = const Loading();
    notifyListeners();
    try {
      final mentor = await _mentors.getMentor(mentorId);
      await _refreshTeam();
      state = Data(mentor);
      await _analytics.logViewMentor(mentorId: mentor.id);
    } catch (e, st) {
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'mentor_detail_load'));
    }
    notifyListeners();
  }

  Future<void> _refreshTeam() async {
    team = await _teams.teamOf(_me.id);
    request = team == null ? null : await _mentors.requestOfTeam(team!.id);
  }

  Future<AppFailure?> sendRequest(String message) async {
    final t = team;
    if (t == null) return null;
    sending = true;
    notifyListeners();
    try {
      await _mentors.requestMentor(teamId: t.id, mentorId: mentorId, sender: _me, message: message.trim());
      await _analytics.logRequestMentor(teamId: t.id, mentorId: mentorId);
      await _refreshTeam();
      return null;
    } catch (e, st) {
      return toFailure(e, st, crash: _crash, reason: 'request_mentor');
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<AppFailure?> withdraw() async {
    final t = team;
    if (t == null) return null;
    withdrawing = true;
    notifyListeners();
    try {
      await _mentors.withdrawRequest(t.id);
      await _refreshTeam();
      return null;
    } catch (e, st) {
      return toFailure(e, st, crash: _crash, reason: 'withdraw_mentor_request');
    } finally {
      withdrawing = false;
      notifyListeners();
    }
  }
}
