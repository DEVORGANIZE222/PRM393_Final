import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/student.dart';
import '../services.dart';
import 'local_database.dart';

/// Shows an account chooser and returns the chosen e-mail, or null if dismissed.
/// Wired in app/providers.dart so this service stays free of widgets.
typedef AccountPicker = Future<String?> Function(List<({String email, String name})> accounts);

/// Development sign-in with the seeded test accounts. Mirrors Google Sign-In:
/// a picker, a cancel path and the @fpt.edu.vn domain check. Replaced by
/// `FirebaseAuthService` (Google Sign-In + FirebaseAuth).
class LocalAuthService implements AuthService {
  LocalAuthService(this._db, this._prefs, this._pickAccount);

  final LocalDatabase _db;
  final SharedPreferences _prefs;
  final AccountPicker _pickAccount;
  static const _key = 'local_auth_uid';

  final _controller = StreamController<Student?>.broadcast();
  Student? _current;

  /// Restores the previous session (if any) before the first frame.
  void restore() {
    final uid = _prefs.getString(_key);
    _current = uid == null ? null : _db.students[uid];
  }

  @override
  Student? get currentStudent => _current;

  @override
  Stream<Student?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<Student> signInWithGoogle() async {
    final accounts = [
      for (final s in _db.students.values) (email: s.email, name: s.fullName),
      (email: 'minh.personal@gmail.com', name: 'Minh Le (personal)'),
    ];
    final email = await _pickAccount(accounts);
    if (email == null) throw const SignInCancelled();
    if (!email.toLowerCase().endsWith('@fpt.edu.vn')) throw EmailNotAllowed(email);
    await _db.roundTrip();
    final student = _db.students.values.firstWhere((s) => s.email == email);
    await _prefs.setString(_key, student.id);
    _current = student;
    _controller.add(student);
    return student;
  }

  @override
  Future<void> signOut() async {
    await _prefs.remove(_key);
    _current = null;
    _controller.add(null);
  }
}
