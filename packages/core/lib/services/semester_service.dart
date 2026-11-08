import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/semester.dart';

class SemesterService {
  SemesterService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Stream<List<Semester>> watchAll() => _db
      .collection('semesters')
      .orderBy('startsAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Semester.fromFirestore(doc.id, doc.data())).toList());

  Future<void> save(Semester semester) async {
    final ref = semester.id.isEmpty ? _db.collection('semesters').doc() : _db.collection('semesters').doc(semester.id);
    final batch = _db.batch();
    batch.set(ref, {
      ...semester.toFirestore(),
      if (semester.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // If this semester is active or currently configured, immediately sync its registration
    // window to configuration/registration so mobile apps receive the updated dates in real-time.
    final configDoc = await _db.collection('configuration').doc('registration').get();
    final activeId = configDoc.data()?['activeSemesterId'] as String?;
    final isConfigActive = activeId == ref.id || (activeId == null && semester.isActive);

    if (semester.isActive || isConfigActive) {
      batch.set(_db.collection('configuration').doc('registration'), {
        'semester': semester.name,
        'opensAt': Timestamp.fromDate(semester.registrationOpensAt),
        'closesAt': Timestamp.fromDate(semester.registrationClosesAt),
        'registrationDeadline': Timestamp.fromDate(semester.registrationClosesAt),
        if (semester.topicDeadline != null) 'topicDeadline': Timestamp.fromDate(semester.topicDeadline!),
        if (semester.mentorDeadline != null) 'mentorDeadline': Timestamp.fromDate(semester.mentorDeadline!),
        'windowHours': semester.registrationClosesAt.difference(semester.registrationOpensAt).inHours,
        'activeSemesterId': ref.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> activate(Semester semester) async {
    final batch = _db.batch();
    final all = await _db.collection('semesters').where('status', isEqualTo: 'active').get();
    for (final doc in all.docs) {
      if (doc.id != semester.id)
        batch.update(doc.reference, {'status': 'draft', 'updatedAt': FieldValue.serverTimestamp()});
    }
    batch.set(_db.collection('semesters').doc(semester.id), {
      ...semester.toFirestore(),
      'status': 'active',
    }, SetOptions(merge: true));
    batch.set(_db.collection('configuration').doc('registration'), {
      'semester': semester.name,
      'opensAt': Timestamp.fromDate(semester.registrationOpensAt),
      'closesAt': Timestamp.fromDate(semester.registrationClosesAt),
      'registrationDeadline': Timestamp.fromDate(semester.registrationClosesAt),
      if (semester.topicDeadline != null) 'topicDeadline': Timestamp.fromDate(semester.topicDeadline!),
      if (semester.mentorDeadline != null) 'mentorDeadline': Timestamp.fromDate(semester.mentorDeadline!),
      'windowHours': semester.registrationClosesAt.difference(semester.registrationOpensAt).inHours,
      'activeSemesterId': semester.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> archive(Semester semester) => _db.collection('semesters').doc(semester.id).update({
    'status': 'archived',
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> delete(Semester semester) => _db.collection('semesters').doc(semester.id).delete();
}
