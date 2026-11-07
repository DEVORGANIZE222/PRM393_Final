import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mentor.dart';
import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';

/// Lecturers and team requests, shared by both clients: the mobile app sends a
/// request, the web admin answers it.
abstract interface class MentorRepository {
  Future<List<Mentor>> searchMentors({String query = '', String? expertise, bool availableOnly = false});
  Future<Mentor> getMentor(String mentorId);

  /// The team's only request, or null when it has not asked anyone yet.
  Future<MentorRequest?> requestOfTeam(String teamId);
  Stream<MentorRequest?> watchRequestOfTeam(String teamId);

  /// Every request sent to a lecturer, newest first, kept live.
  Stream<List<MentorRequest>> watchRequestsForMentor(String mentorId);

  /// The teams a lecturer has accepted to supervise.
  Future<List<Team>> teamsOfMentor(String mentorId);

  /// Team leader only. Throws the `AppFailure` from [MentorRules.requestBlocker].
  Future<void> requestMentor({
    required String teamId,
    required String mentorId,
    required Student sender,
    required String message,
  });

  Future<void> withdrawRequest(String teamId);

  /// Accepting makes the lecturer the team's supervisor and takes one quota slot.
  Future<void> respond({required MentorRequest request, required bool accept, String? reason});
}

/// Search shared by the repositories; the directory is small enough to filter here.
List<Mentor> filterMentors(
  Iterable<Mentor> mentors, {
  String query = '',
  String? expertise,
  bool availableOnly = false,
}) {
  final q = query.trim().toLowerCase();
  return mentors.where((m) {
    if (m.archived || (availableOnly && !m.isAvailable)) return false;
    if (expertise != null && !m.expertise.contains(expertise)) return false;
    if (q.isEmpty) return true;
    return [m.fullName, m.title, m.department, m.bio, ...m.expertise].join(' ').toLowerCase().contains(q);
  }).toList();
}

/// Firestore-backed directory (`mentors`) and requests (`mentor_requests/{teamId}`).
/// Sending and answering a request run in a transaction so the quota and
/// "one mentor per team" checks hold across clients.
class FirestoreMentorRepository implements MentorRepository {
  FirestoreMentorRepository([FirebaseFirestore? firestore]) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _mentors => _db.collection('mentors');
  CollectionReference<Map<String, dynamic>> get _requests => _db.collection('mentor_requests');
  CollectionReference<Map<String, dynamic>> get _teams => _db.collection('teams');

  Mentor _mentor(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw const AppFailure(
        'This mentor is no longer listed',
        'Choose another mentor from the list.',
        retryable: false,
        code: 'not-found',
      );
    }
    return Mentor.fromJson({...data, 'id': doc.id});
  }

  Team _team(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw const AppFailure(
        'This team no longer exists',
        'It may have been closed by its members.',
        retryable: false,
        code: 'not-found',
      );
    }
    return Team.fromJson({...data, 'id': doc.id});
  }

  MentorRequest? _request(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return d == null ? null : MentorRequest.fromJson({...d, 'teamId': doc.id});
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw switch (e.code) {
        'unavailable' => AppFailure.offline,
        'permission-denied' => AppFailure.permissionDenied,
        _ => e,
      };
    }
  }

  @override
  Future<List<Mentor>> searchMentors({String query = '', String? expertise, bool availableOnly = false}) =>
      _guard(() async {
        // Server only, like Browse: offline must show the error state, not "no mentors".
        final snap = await _mentors.get(const GetOptions(source: Source.server));
        return filterMentors(snap.docs.map(_mentor), query: query, expertise: expertise, availableOnly: availableOnly);
      });

  @override
  Future<Mentor> getMentor(String mentorId) => _guard(() async => _mentor(await _mentors.doc(mentorId).get()));

  @override
  Future<MentorRequest?> requestOfTeam(String teamId) =>
      _guard(() async => _request(await _requests.doc(teamId).get()));

  @override
  Stream<MentorRequest?> watchRequestOfTeam(String teamId) => _requests.doc(teamId).snapshots().map(_request);

  @override
  Stream<List<MentorRequest>> watchRequestsForMentor(String mentorId) =>
      _requests.where('mentorId', isEqualTo: mentorId).snapshots().map(
        (snap) => snap.docs.map(_request).whereType<MentorRequest>().toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Future<List<Team>> teamsOfMentor(String mentorId) => _guard(() async {
    final snap = await _teams.where('mentorId', isEqualTo: mentorId).get();
    return snap.docs.map(_team).toList();
  });

  @override
  Future<void> requestMentor({
    required String teamId,
    required String mentorId,
    required Student sender,
    required String message,
  }) => _guard(() async {
    final ref = _requests.doc(teamId);
    await _db.runTransaction((tx) async {
      final team = _team(await tx.get(_teams.doc(teamId)));
      final mentor = _mentor(await tx.get(_mentors.doc(mentorId)));
      final current = _request(await tx.get(ref));
      final blocker = MentorRules.requestBlocker(team: team, mentor: mentor, senderId: sender.id, current: current);
      if (blocker != null) throw blocker;
      tx.set(ref, {
        'teamId': teamId,
        'teamName': team.name,
        'mentorId': mentor.id,
        'mentorName': mentor.fullName,
        'senderId': sender.id,
        'senderName': sender.fullName,
        'message': message,
        'status': MentorRequestStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  });

  @override
  Future<void> withdrawRequest(String teamId) => _guard(() => _requests.doc(teamId).delete());

  @override
  Future<void> respond({required MentorRequest request, required bool accept, String? reason}) => _guard(() async {
    final ref = _requests.doc(request.teamId);
    final mentorRef = _mentors.doc(request.mentorId);
    final teamRef = _teams.doc(request.teamId);
    await _db.runTransaction((tx) async {
      final stored = _request(await tx.get(ref));
      final mentor = _mentor(await tx.get(mentorRef));
      final team = _team(await tx.get(teamRef));
      if (stored == null || !stored.isPending) throw MentorRules.requestClosed;
      final inbox = _db.collection('students').doc(stored.senderId).collection('notifications').doc();
      if (!accept) {
        tx.update(ref, {
          'status': MentorRequestStatus.rejected.name,
          'decisionReason': reason ?? '',
          'decidedAt': FieldValue.serverTimestamp(),
        });
        tx.set(inbox, _answer(stored, title: '${mentor.fullName} declined your request', body: reason ?? ''));
        return;
      }
      final blocker = MentorRules.acceptBlocker(request: stored, team: team, mentor: mentor);
      if (blocker != null) throw blocker;
      final updated = mentor.withTeam(stored.teamName);
      tx.update(ref, {'status': MentorRequestStatus.approved.name, 'decidedAt': FieldValue.serverTimestamp()});
      tx.update(teamRef, {'mentorId': mentor.id, 'supervisor': mentor.fullName});
      tx.update(mentorRef, {
        'currentAssigned': updated.currentAssigned,
        'mentoredTeamNames': updated.mentoredTeamNames,
      });
      tx.set(
        inbox,
        _answer(stored, title: '${mentor.fullName} is your mentor', body: '${stored.teamName} now has a supervisor.'),
      );
    });
  });

  Map<String, dynamic> _answer(MentorRequest request, {required String title, required String body}) => {
    'kind': 'system',
    'title': title,
    'body': body,
    'createdAt': FieldValue.serverTimestamp(),
    'read': false,
    'teamId': request.teamId,
    'actionLabel': 'View team',
  };
}
