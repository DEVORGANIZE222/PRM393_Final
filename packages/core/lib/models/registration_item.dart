import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationItem {
  final String id;
  final String eventId;
  final String uid;
  final String status; // 'pending', 'approved', 'rejected'
  final String reason;
  final DateTime createdAt;

  const RegistrationItem({
    required this.id,
    required this.eventId,
    required this.uid,
    this.status = 'pending',
    this.reason = '',
    required this.createdAt,
  });

  factory RegistrationItem.fromFirestore(String id, Map<String, dynamic> data) {
    return RegistrationItem(
      id: id,
      eventId: data['eventId'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      reason: data['reason'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'uid': uid,
      'status': status,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

