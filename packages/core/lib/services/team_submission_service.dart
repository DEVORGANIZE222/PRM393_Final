import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/team_submission.dart';

/// Shared Firestore access for the cross-role locked-roster review flow.
class TeamSubmissionService {
  TeamSubmissionService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Stream<List<TeamSubmission>> watchAll() => _db
      .collection('teamSubmissions')
      .orderBy('submittedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => TeamSubmission.fromFirestore(doc.id, doc.data())).toList());

  Stream<TeamSubmission?> watchForTeam(String teamId) =>
      _db.collection('teamSubmissions').doc(teamId).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return TeamSubmission.fromFirestore(doc.id, doc.data()!);
      });

  Future<void> submit({
    required String teamId,
    required String leaderId,
    required String teamName,
    required String lockCode,
    required List<Map<String, dynamic>> memberSnapshot,
  }) => _db.collection('teamSubmissions').doc(teamId).set({
    'teamId': teamId,
    'leaderId': leaderId,
    'teamName': teamName,
    'lockCode': lockCode,
    'memberSnapshot': memberSnapshot,
    'status': 'pending',
    'submittedAt': FieldValue.serverTimestamp(),
    'reason': '',
  });

  Future<void> decide({
    required TeamSubmission submission,
    required String adminId,
    required bool approved,
    String reason = '',
  }) async {
    if (!approved && reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'A rejection reason is required.');
    }
    final batch = _db.batch();
    batch.update(_db.collection('teamSubmissions').doc(submission.id), {
      'status': approved ? 'approved' : 'rejected',
      'reason': approved ? '' : reason.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminId,
    });
    batch.set(_db.collection('students').doc(submission.leaderId).collection('notifications').doc(), {
      'kind': 'system',
      'title': approved ? 'Team roster approved' : 'Team roster needs changes',
      'body': approved
          ? '${submission.teamName} (${submission.lockCode}) has been approved by the Academic Office.'
          : reason.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      'teamId': submission.teamId,
      'actionLabel': 'View team',
    });
    await batch.commit();
  }
}
