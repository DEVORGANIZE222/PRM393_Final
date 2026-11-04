import 'package:cloud_firestore/cloud_firestore.dart';

class EventItem {
  final String id;
  final String title;
  final String description;
  final DateTime startAt;
  final String status; // 'draft', 'published', 'archived'

  const EventItem({
    required this.id,
    required this.title,
    required this.description,
    required this.startAt,
    this.status = 'draft',
  });

  factory EventItem.fromFirestore(String id, Map<String, dynamic> data) {
    return EventItem(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      startAt: data['startAt'] != null
          ? (data['startAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] as String? ?? 'draft',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'startAt': Timestamp.fromDate(startAt),
      'status': status,
    };
  }
}

