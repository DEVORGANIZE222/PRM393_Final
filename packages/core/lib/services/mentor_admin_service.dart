import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mentor.dart';
import '../models/view_state.dart';

/// Admin side of the mentor directory. A lecturer signs in on mobile because
/// their roster entry (`allowedEmails/{email}`) carries `mentorId`, so the
/// profile and that entry always change in the same batch.
class MentorAdminService {
  MentorAdminService({FirebaseFirestore? firestore}) : _firestore = firestore;
  final FirebaseFirestore? _firestore;

  // Resolved on first use, so tests can replace the service without Firebase.
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _mentors => _db.collection('mentors');
  CollectionReference<Map<String, dynamic>> get _roster => _db.collection('allowedEmails');

  Stream<List<Mentor>> watchMentors() => _mentors.snapshots().map(
    (snap) => snap.docs.map((d) => Mentor.fromJson({...d.data(), 'id': d.id})).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName)),
  );

  Stream<List<MentorRequest>> watchRequests() => _db.collection('mentor_requests').snapshots().map(
    (snap) => snap.docs.map((d) => MentorRequest.fromJson({...d.data(), 'teamId': d.id})).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  Map<String, dynamic> _profile(Mentor m) => {
    'fullName': m.fullName.trim(),
    'email': m.email.trim().toLowerCase(),
    'title': m.title.trim(),
    'department': m.department.trim(),
    'expertise': m.expertise,
    'bio': m.bio.trim(),
    'office': m.office.trim(),
    'maxQuota': m.maxQuota,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Future<void> create(Mentor mentor) async {
    final email = mentor.email.trim().toLowerCase();
    await _assertEmailFree(email, null);
    final ref = _mentors.doc();
    final batch = _db.batch();
    batch.set(ref, {
      ..._profile(mentor),
      'status': 'active',
      'currentAssigned': 0,
      'mentoredTeamNames': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    _link(batch, email, ref.id, mentor.fullName);
    await batch.commit();
  }

  /// Quota and team counts come from accepted requests, so only the quota
  /// ceiling can change here, and never below the teams already supervised.
  Future<void> update(Mentor before, Mentor after) async {
    if (after.maxQuota < before.currentAssigned) {
      throw AppFailure(
        'Quota thấp hơn số nhóm đang hướng dẫn',
        '${before.fullName} đang hướng dẫn ${before.currentAssigned} nhóm.',
        retryable: false,
        code: 'quota-below-assigned',
      );
    }
    final oldEmail = before.email.trim().toLowerCase();
    final newEmail = after.email.trim().toLowerCase();
    final batch = _db.batch();
    batch.update(_mentors.doc(before.id), _profile(after));
    if (newEmail != oldEmail) {
      await _assertEmailFree(newEmail, before.id);
      _unlink(batch, oldEmail);
      _link(batch, newEmail, before.id, after.fullName);
    }
    await batch.commit();
  }

  /// Archived lecturers leave the student directory and cannot sign in as a
  /// lecturer. Their teams keep the mentor they already have.
  Future<void> setArchived(Mentor mentor, bool archived) async {
    final email = mentor.email.trim().toLowerCase();
    final batch = _db.batch();
    batch.update(_mentors.doc(mentor.id), {
      'status': archived ? 'archived' : 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (archived) {
      _unlink(batch, email);
    } else {
      _link(batch, email, mentor.id, mentor.fullName);
    }
    await batch.commit();
  }

  Future<void> _assertEmailFree(String email, String? mentorId) async {
    final snap = await _roster.doc(email).get();
    final linked = snap.data()?['mentorId'] as String?;
    if (linked != null && linked != mentorId) {
      throw AppFailure(
        'Email đã gắn với giảng viên khác',
        '$email đang dùng cho một hồ sơ giảng viên khác.',
        retryable: false,
        code: 'email-taken',
      );
    }
  }

  void _link(WriteBatch batch, String email, String mentorId, String fullName) => batch.set(_roster.doc(email), {
    'enabled': true,
    'mentorId': mentorId,
    'fullName': fullName.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  void _unlink(WriteBatch batch, String email) =>
      batch.set(_roster.doc(email), {'mentorId': FieldValue.delete()}, SetOptions(merge: true));
}
