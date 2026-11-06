import 'package:cloud_firestore/cloud_firestore.dart';

class Semester {
  const Semester({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.registrationOpensAt,
    required this.registrationClosesAt,
    required this.status,
  });

  final String id;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime registrationOpensAt;
  final DateTime registrationClosesAt;
  final String status;

  bool get isActive => status == 'active';

  factory Semester.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime date(dynamic value) => value is Timestamp ? value.toDate() : DateTime.now();
    return Semester(
      id: id,
      name: data['name'] as String? ?? 'Untitled semester',
      startsAt: date(data['startsAt']),
      endsAt: date(data['endsAt']),
      registrationOpensAt: date(data['registrationOpensAt']),
      registrationClosesAt: date(data['registrationClosesAt']),
      status: data['status'] as String? ?? 'draft',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name.trim(),
    'startsAt': Timestamp.fromDate(startsAt),
    'endsAt': Timestamp.fromDate(endsAt),
    'registrationOpensAt': Timestamp.fromDate(registrationOpensAt),
    'registrationClosesAt': Timestamp.fromDate(registrationClosesAt),
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
