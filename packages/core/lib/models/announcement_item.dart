import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementItem {
  final String id;
  final String title;
  final String body;
  final String authorId;
  final String authorName;
  final DateTime createdAt;

  const AnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

  factory AnnouncementItem.fromFirestore(String id, Map<String, dynamic> data) {
    return AnnouncementItem(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

