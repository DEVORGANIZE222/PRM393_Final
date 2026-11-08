import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../services/services.dart';

/// App-wide auth state; the router redirects on it (signed out → /sign-in).
class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._auth, this._analytics, this._crash) {
    _sub = _auth.authStateChanges().listen(_onAuth);
  }

  final AuthService _auth;
  final AnalyticsService _analytics;
  final CrashReporter _crash;
  late final StreamSubscription<Student?> _sub;

  Student? _student;
  bool _ready = false;

  Student? get student => _student;
  bool get isSignedIn => _student != null;
  bool get isMentor => _student?.isMentor ?? false;

  /// False until the first auth event, so the router doesn't flash Sign In.
  bool get ready => _ready;

  void _onAuth(Student? s) {
    _student = s;
    _ready = true;
    _analytics.setUserId(s?.id);
    _crash.setUserId(s?.id);
    if (s != null) _crash.setKey('student_cohort', s.cohort);
    notifyListeners();
  }

  Future<void> updateStudentProfile({
    required String major,
    required String role,
    required List<String> skills,
  }) async {
    if (_student == null) return;
    final uid = _student!.id;
    final db = FirebaseFirestore.instance;
    await db.collection('students').doc(uid).set({
      'major': major,
      'preferredRoles': [role],
      'role': role,
      'skills': skills,
    }, SetOptions(merge: true));

    // Also update any team where this student is a member
    try {
      final teamsQuery = await db.collection('teams').where('memberIds', arrayContains: uid).get();
      for (final doc in teamsQuery.docs) {
        final data = doc.data();
        final rawMembers = data['members'] as List<dynamic>? ?? [];
        final updatedMembers = rawMembers.map((m) {
          if (m is Map && (m['studentId'] == uid || m['id'] == uid)) {
            final copy = Map<String, dynamic>.from(m);
            copy['role'] = role;
            copy['skills'] = skills;
            return copy;
          }
          return m;
        }).toList();
        await doc.reference.update({'members': updatedMembers});
      }
    } catch (_) {}

    _student = _student!.copyWith(
      major: major,
      preferredRoles: [role],
      skills: skills,
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    await _analytics.logLogout();
    await _auth.signOut();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
