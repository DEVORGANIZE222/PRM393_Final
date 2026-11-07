import 'package:cloud_firestore/cloud_firestore.dart';

class Semester {
  const Semester({
    required this.id,
    required this.name,
    this.code,
    required this.startsAt,
    required this.endsAt,
    required this.registrationOpensAt,
    required this.registrationClosesAt,
    this.topicDeadline,
    this.mentorDeadline,
    required this.status,
  });

  final String id;
  final String name;
  final String? code;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime registrationOpensAt;
  final DateTime registrationClosesAt;
  final DateTime? topicDeadline;
  final DateTime? mentorDeadline;
  final String status;

  bool get isActive => status == 'active';
  String get displayCode => (code != null && code!.trim().isNotEmpty) ? code!.trim() : name;

  factory Semester.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime date(dynamic value) => value is Timestamp ? value.toDate() : DateTime.now();
    DateTime? optDate(dynamic value) => value is Timestamp ? value.toDate() : null;
    return Semester(
      id: id,
      name: data['name'] as String? ?? 'Untitled semester',
      code: data['code'] as String?,
      startsAt: date(data['startsAt']),
      endsAt: date(data['endsAt']),
      registrationOpensAt: date(data['registrationOpensAt']),
      registrationClosesAt: date(data['registrationClosesAt']),
      topicDeadline: optDate(data['topicDeadline']),
      mentorDeadline: optDate(data['mentorDeadline']),
      status: data['status'] as String? ?? 'draft',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name.trim(),
    if (code != null && code!.trim().isNotEmpty) 'code': code!.trim().toUpperCase(),
    'startsAt': Timestamp.fromDate(startsAt),
    'endsAt': Timestamp.fromDate(endsAt),
    'registrationOpensAt': Timestamp.fromDate(registrationOpensAt),
    'registrationClosesAt': Timestamp.fromDate(registrationClosesAt),
    if (topicDeadline != null) 'topicDeadline': Timestamp.fromDate(topicDeadline!),
    if (mentorDeadline != null) 'mentorDeadline': Timestamp.fromDate(mentorDeadline!),
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
