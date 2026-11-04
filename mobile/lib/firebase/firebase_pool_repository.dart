import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/registration.dart';
import '../models/view_state.dart';
import '../services/services.dart';

class FirebasePoolRepository implements PoolRepository {
  FirebasePoolRepository([FirebaseFirestore? firestore]) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  @override
  Future<PoolStatus> statusOf(String studentId) async {
    final d = await _db.collection('waitingPool').doc(studentId).get();
    if (!d.exists) {
      throw const AppFailure(
        'No Waiting Pool record',
        'Join the pool when registration opens.',
        retryable: false,
        code: 'not-found',
      );
    }
    final v = d.data()!;
    return PoolStatus(
      queueId: v['queueId'] as String,
      progress: (v['progress'] as num).toDouble(),
      stage: v['stage'] as String,
      expectedResult: (v['expectedResult'] as Timestamp).toDate(),
      preferredRoles: List<String>.from(v['preferredRoles'] ?? const []),
      skills: List<String>.from(v['skills'] ?? const []),
      studentsInPool: v['studentsInPool'] as int? ?? 0,
      contactEmail: v['contactEmail'] as String? ?? '',
      lastChecked: DateTime.now(),
    );
  }
}

class FirebaseRegistrationService implements RegistrationService {
  FirebaseRegistrationService([FirebaseFirestore? firestore]) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  @override
  Future<RegistrationWindow> currentWindow() async {
    final d = await _db.collection('configuration').doc('registration').get();
    if (!d.exists) {
      throw const AppFailure(
        'Registration is not configured',
        'Please check with the Academic Office.',
        retryable: true,
        code: 'not-found',
      );
    }
    final v = d.data()!;
    // The configuration document is maintained in Firestore by the project
    // administrators.  Keep the first app launch usable while that document
    // is being populated; as soon as Timestamp values exist they take
    // precedence over these runtime defaults.
    final opensAt = v['opensAt'];
    final closesAt = v['closesAt'];
    if (opensAt is! Timestamp || closesAt is! Timestamp) {
      throw const AppFailure(
        'Registration dates are not configured',
        'opensAt and closesAt Timestamps must be set in Firestore configuration/registration.',
        retryable: true,
        code: 'invalid-configuration',
      );
    }
    return RegistrationWindow(
      semester: v['semester'] as String? ?? 'Current semester',
      opensAt: opensAt.toDate(),
      closesAt: closesAt.toDate(),
    );
  }
}
