import 'dart:async';

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
