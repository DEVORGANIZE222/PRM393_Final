import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../services/services.dart';

class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository([FirebaseFirestore? firestore]) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      _db.collection('students').doc(uid).collection('notifications');

  AppNotification _from(DocumentSnapshot<Map<String, dynamic>> d) {
    final v = d.data()!;
    return AppNotification(
      id: d.id,
      kind: NotificationKind.values.byName(v['kind'] as String? ?? 'system'),
      title: v['title'] as String? ?? '',
      body: v['body'] as String? ?? '',
      createdAt: (v['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: v['read'] as bool? ?? false,
      teamId: v['teamId'] as String?,
      actionLabel: v['actionLabel'] as String?,
    );
  }

  AppNotification _fromAnnouncement(DocumentSnapshot<Map<String, dynamic>> d) {
    final v = d.data()!;
    DateTime createdAt = DateTime.now();
    if (v['createdAt'] is Timestamp) {
      createdAt = (v['createdAt'] as Timestamp).toDate();
    }
    return AppNotification(
      id: 'ann_${d.id}',
      kind: NotificationKind.system,
      title: '📢 ${v['title'] as String? ?? 'Announcement'}',
      body: v['body'] as String? ?? '',
      createdAt: createdAt,
      read: false,
      actionLabel: 'Announcement',
    );
  }

  Map<String, dynamic> _to(AppNotification n) => {
    'kind': n.kind.name,
    'title': n.title,
    'body': n.body,
    'createdAt': Timestamp.fromDate(n.createdAt),
    'read': n.read,
    'teamId': n.teamId,
    'actionLabel': n.actionLabel,
  };

  @override
  Stream<List<AppNotification>> watch(String studentId) {
    final controller = StreamController<List<AppNotification>>();
    List<AppNotification> personalNotifs = [];
    List<AppNotification> announcements = [];

    void emitMerged() {
      if (controller.isClosed) return;
      final merged = [...personalNotifs, ...announcements]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(merged);
    }

    final sub1 = _items(studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (s) {
            personalNotifs = s.docs.map(_from).toList();
            emitMerged();
          },
          onError: (e) {
            if (!controller.isClosed) controller.addError(e);
          },
        );

    final sub2 = _db
        .collection('announcements')
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen(
          (s) {
            announcements = s.docs.map(_fromAnnouncement).toList();
            emitMerged();
          },
          onError: (_) {
            // Announcements listener falls back gracefully if collection not yet created
          },
        );

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  @override
  Future<void> markRead(String studentId, String notificationId) async {
    if (notificationId.startsWith('ann_')) return;
    await _items(studentId).doc(notificationId).update({'read': true});
  }

  @override
  Future<void> markAllRead(String studentId) async {
    final b = _db.batch();
    for (final d in (await _items(studentId).where('read', isEqualTo: false).get()).docs) {
      b.update(d.reference, {'read': true});
    }
    await b.commit();
  }

  @override
  Future<void> remove(String studentId, String notificationId) async {
    if (notificationId.startsWith('ann_')) return;
    await _items(studentId).doc(notificationId).delete();
  }

  @override
  Future<void> restore(String studentId, AppNotification notification) async {
    if (notification.id.startsWith('ann_')) return;
    await _items(studentId).doc(notification.id).set(_to(notification));
  }
}
