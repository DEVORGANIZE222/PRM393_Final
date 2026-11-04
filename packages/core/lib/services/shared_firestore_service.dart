import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../models/event_item.dart';
import '../models/registration_item.dart';
import '../models/announcement_item.dart';

class SharedFirestoreService {
  final FirebaseFirestore _firestore;

  SharedFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // --- Users & Roles ---
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromFirestore(doc.id, doc.data()!);
  }

  Stream<UserProfile?> streamUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromFirestore(doc.id, doc.data()!);
    });
  }

  Future<void> createUserProfile(UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(profile.uid)
        .set(profile.toFirestore(), SetOptions(merge: true));
  }

  // --- Events (Management) ---
  Stream<List<EventItem>> streamEvents({bool publishedOnly = false}) {
    Query query = _firestore.collection('events');
    if (publishedOnly) {
      query = query.where('status', isEqualTo: 'published');
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              EventItem.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> saveEvent(EventItem event) async {
    if (event.id.isEmpty) {
      await _firestore.collection('events').add(event.toFirestore());
    } else {
      await _firestore
          .collection('events')
          .doc(event.id)
          .set(event.toFirestore(), SetOptions(merge: true));
    }
  }

  Future<void> archiveEvent(String eventId) async {
    await _firestore
        .collection('events')
        .doc(eventId)
        .update({'status': 'archived'});
  }

  // --- Registrations (Review Queue) ---
  Stream<List<RegistrationItem>> streamPendingRegistrations() {
    return _firestore
        .collection('registrations')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RegistrationItem.fromFirestore(
              doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> updateRegistrationStatus({
    required String registrationId,
    required String status,
    String reason = '',
  }) async {
    await _firestore.collection('registrations').doc(registrationId).update({
      'status': status,
      if (reason.isNotEmpty) 'reason': reason,
    });
  }

  // --- Announcements ---
  Stream<List<AnnouncementItem>> streamAnnouncements() {
    return _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AnnouncementItem.fromFirestore(
              doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> createAnnouncement(AnnouncementItem announcement) async {
    await _firestore.collection('announcements').add(announcement.toFirestore());
  }
}

