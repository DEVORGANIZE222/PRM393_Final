import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/registration_configuration.dart';

class AdminRegistrationService {
  AdminRegistrationService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  DocumentReference<Map<String, dynamic>> get _registration => _db.collection('configuration').doc('registration');

  Stream<RegistrationConfiguration?> watchCurrent() => _registration.snapshots().map((snapshot) {
    final data = snapshot.data();
    return data == null ? null : RegistrationConfiguration.fromFirestore(data);
  });

  Future<void> save(RegistrationConfiguration configuration) => _registration.set(configuration.toFirestore(), SetOptions(merge: true));
}
