import 'package:cloud_firestore/cloud_firestore.dart';

/// The stable Firestore contract consumed by the student mobile application.
class RegistrationConfiguration {
  const RegistrationConfiguration({
    required this.semester,
    required this.opensAt,
    required this.closesAt,
    required this.windowHours,
  });

  final String semester;
  final DateTime opensAt;
  final DateTime closesAt;
  final int windowHours;

  factory RegistrationConfiguration.fromFirestore(Map<String, dynamic> data) {
    DateTime readDate(dynamic value) => value is Timestamp ? value.toDate() : DateTime.now();
    return RegistrationConfiguration(
      semester: data['semester'] as String? ?? 'Current semester',
      opensAt: readDate(data['opensAt']),
      closesAt: readDate(data['closesAt']),
      windowHours: data['windowHours'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'semester': semester.trim(),
    'opensAt': Timestamp.fromDate(opensAt),
    'closesAt': Timestamp.fromDate(closesAt),
    'windowHours': windowHours,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
