import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Requests notification consent, stores an FCM token, and persists foreground
/// messages so the existing notification screen has one source of truth.
class FirebaseMessagingService {
  FirebaseMessagingService({FirebaseMessaging? messaging, FirebaseFirestore? firestore})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final _openedTeamIds = StreamController<String>.broadcast();
  final _notificationPermissionDenied = StreamController<void>.broadcast();
  String? _activeUid;
  bool _handlersBound = false;

  /// Emits a team ID when the user opens a notification that targets a team.
  Stream<String> get openedTeamIds => _openedTeamIds.stream;

  /// Emits when Android/iOS notification permission is denied. The app shell
  /// turns this into a visible, non-blocking UI message for the student.
  Stream<void> get notificationPermissionDenied => _notificationPermissionDenied.stream;

  Future<bool> initialize(String uid) async {
    _activeUid = uid;
    final settings = await _requestPermission();
    if (settings == null || settings.authorizationStatus == AuthorizationStatus.denied) {
      _notificationPermissionDenied.add(null);
      return false;
    }
    await _saveToken(uid, await _messaging.getToken());
    if (!_handlersBound) {
      _handlersBound = true;
      _messaging.onTokenRefresh.listen((token) {
        final activeUid = _activeUid;
        if (activeUid != null) unawaited(_saveToken(activeUid, token));
      });
      FirebaseMessaging.onMessage.listen((message) {
        final activeUid = _activeUid;
        if (activeUid != null) unawaited(_persist(activeUid, message));
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final activeUid = _activeUid;
        if (activeUid != null) unawaited(_handleOpened(activeUid, message));
      });
    }
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) await _handleOpened(uid, initialMessage);
    return true;
  }

  Future<NotificationSettings?> _requestPermission() async {
    try {
      return await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {
      // Notification delivery is optional: a permission/platform error must
      // not turn a successful Google sign-in into a failed sign-in.
      return null;
    }
  }

  Future<void> _saveToken(String uid, String? token) async {
    if (token != null) await _db.collection('students').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
  }

  Future<void> _persist(String uid, RemoteMessage message) =>
      _db.collection('students').doc(uid).collection('notifications').doc(message.messageId).set({
        'kind': message.data['kind'] ?? 'system',
        'title': message.notification?.title ?? message.data['title'] ?? 'Notification',
        'body': message.notification?.body ?? message.data['body'] ?? '',
        'teamId': message.data['teamId'],
        'actionLabel': message.data['actionLabel'],
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> _handleOpened(String uid, RemoteMessage message) async {
    await _persist(uid, message);
    final teamId = message.data['teamId'] as String?;
    if (teamId != null && teamId.isNotEmpty) _openedTeamIds.add(teamId);
  }
}
