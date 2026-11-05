import '../../models/mentor.dart';
import '../../models/student.dart';
import '../../models/team.dart';
import '../../models/view_state.dart';
import '../services.dart';
import 'local_database.dart';

/// Development implementation of [MentorRepository] over [LocalDatabase]. It
/// keeps the same rules as the Firestore one, which the unit tests rely on.
class LocalMentorRepository implements MentorRepository {
  LocalMentorRepository(this._db);
  final LocalDatabase _db;

  Mentor _mentor(String mentorId) =>
      _db.mentors[mentorId] ??
      (throw const AppFailure(
        'This mentor is no longer listed',
        'Choose another mentor from the list.',
        retryable: false,
        code: 'not-found',
      ));

  @override
  Future<List<Mentor>> searchMentors({String query = '', String? expertise, bool availableOnly = false}) async {
    await _db.roundTrip();
    return filterMentors(_db.mentors.values, query: query, expertise: expertise, availableOnly: availableOnly);
  }

  @override
  Future<Mentor> getMentor(String mentorId) async {
    await _db.roundTrip();
    return _mentor(mentorId);
  }

  @override
  Future<MentorRequest?> requestOfTeam(String teamId) async {
    await _db.roundTrip();
    return _db.mentorRequests[teamId];
  }

  @override
  Stream<MentorRequest?> watchRequestOfTeam(String teamId) async* {
    await _db.roundTrip();
    yield _db.mentorRequests[teamId];
    yield* _db.mentorRequestChanges.where((id) => id == teamId).map((_) => _db.mentorRequests[teamId]);
  }

  List<MentorRequest> _forMentor(String mentorId) =>
      _db.mentorRequests.values.where((r) => r.mentorId == mentorId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<MentorRequest>> watchRequestsForMentor(String mentorId) async* {
    await _db.roundTrip();
    yield _forMentor(mentorId);
    yield* _db.mentorRequestChanges.map((_) => _forMentor(mentorId));
  }

  @override
  Future<List<Team>> teamsOfMentor(String mentorId) async {
    await _db.roundTrip();
    return _db.teams.values.where((t) => t.mentorId == mentorId).toList();
  }

  @override
  Future<void> requestMentor({
    required String teamId,
    required String mentorId,
    required Student sender,
    required String message,
  }) async {
    await _db.roundTrip();
    final team = _db.teams[teamId]!;
    final mentor = _mentor(mentorId);
    final blocker = MentorRules.requestBlocker(
      team: team,
      mentor: mentor,
      senderId: sender.id,
      current: _db.mentorRequests[teamId],
    );
    if (blocker != null) throw blocker;
    _db.putMentorRequest(MentorRequest.create(team: team, mentor: mentor, sender: sender, message: message));
  }

  @override
  Future<void> withdrawRequest(String teamId) async {
    await _db.roundTrip();
    _db.removeMentorRequest(teamId);
  }

  @override
  Future<void> respond({required MentorRequest request, required bool accept, String? reason}) async {
    await _db.roundTrip();
    final stored = _db.mentorRequests[request.teamId];
    if (stored == null || !stored.isPending) throw MentorRules.requestClosed;
    if (accept) {
      final team = _db.teams[request.teamId]!;
      final mentor = _mentor(request.mentorId);
      final blocker = MentorRules.acceptBlocker(request: stored, team: team, mentor: mentor);
      if (blocker != null) throw blocker;
      _db.putTeam(team.copyWith(mentorId: mentor.id, supervisor: mentor.fullName));
      _db.mentors[mentor.id] = mentor.withTeam(team.name);
    }
    _db.putMentorRequest(stored.decided(accept: accept, reason: reason));
  }
}
