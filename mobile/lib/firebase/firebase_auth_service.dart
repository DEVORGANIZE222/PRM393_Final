import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/student.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'firebase_messaging_service.dart';

/// Firebase Authentication + Google Sign-In implementation.
///
/// Lab 3 Requirement:
/// - Restrict sign-in to the administrator-seeded Firestore allowlist.
/// - Persist session with FirebaseAuth.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
    FirebaseMessagingService? messaging,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(
         scopes: [
           'email',
           'https://www.googleapis.com/auth/userinfo.profile',
         ],
       ),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessagingService();
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;
  final FirebaseMessagingService _messaging;
  Student? _currentStudent;
  final _messagingInitializedFor = <String>{};

  @override
  Stream<Student?> authStateChanges() async* {
    await for (final user in _auth.authStateChanges()) {
      if (user == null) {
        _currentStudent = null;
        yield null;
        continue;
      }

      try {
        _currentStudent = await _studentFor(user);
        yield _currentStudent;
      } on EmailNotAllowed {
        // A saved Firebase session must not bypass a later roster change.
        await _signOutSilently();
        _currentStudent = null;
        yield null;
      } catch (_) {
        // A temporarily unavailable Firestore roster must never leave the
        // router on its splash screen. Sign out and let the sign-in screen
        // show a retryable error on the next explicit attempt.
        await _signOutSilently();
        _currentStudent = null;
        yield null;
      }
    }
  }

  @override
  Student? get currentStudent => _currentStudent;

  @override
  Future<Student> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw const SignInCancelled();
    final authentication = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: authentication.accessToken,
      idToken: authentication.idToken,
    );
    try {
      final user = (await _auth.signInWithCredential(credential)).user!;
      _currentStudent = await _studentFor(user, account: account);
      return _currentStudent!;
    } catch (_) {
      await _signOutSilently();
      rethrow;
    }
  }

  Future<Student> _studentFor(User user, {GoogleSignInAccount? account}) async {
    final email = user.email ?? account?.email;
    if (email == null || email.isEmpty) {
      throw const AppFailure('Google account has no email', 'Choose a Google account with an email address and try again.');
    }
    final normalizedEmail = email.trim().toLowerCase();
    DocumentSnapshot<Map<String, dynamic>> allowed;
    try {
      allowed = await _firestore.collection('allowedEmails').doc(normalizedEmail).get();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const AppFailure(
          'Class roster is not ready yet',
          'The Firebase roster access rule has not been published. Ask the project administrator to complete the roster setup, then try again.',
          code: 'allowlist-unavailable',
        );
      }
      rethrow;
    }
    if (!allowed.exists || allowed.data()?['enabled'] != true) {
      throw EmailNotAllowed(email);
    }

    final reference = _firestore.collection('students').doc(user.uid);
    final snapshot = await reference.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final existingAvatar = data['avatarUrl'] as String?;
    final providerPhoto = user.providerData
        .map((p) => p.photoURL)
        .whereType<String>()
        .where((u) => u.isNotEmpty)
        .firstOrNull;
    final photoUrl = user.photoURL ?? account?.photoUrl ?? providerPhoto ?? existingAvatar;
    if (account?.photoUrl != null && user.photoURL == null) {
      try {
        await user.updatePhotoURL(account!.photoUrl);
      } catch (_) {}
    }
    final payload = <String, dynamic>{
      'email': normalizedEmail,
      'fullName': user.displayName ?? account?.displayName ?? (data['fullName'] as String?) ?? normalizedEmail.split('@').first,
      'studentCode': data['studentCode'] ?? normalizedEmail.split('@').first,
      'major': data['major'] ?? '',
      'cohort': data['cohort'] ?? '',
      'skills': data['skills'] ?? <String>[],
      'preferredRoles': data['preferredRoles'] ?? <String>[],
    };
    if (photoUrl != null && photoUrl.isNotEmpty) {
      payload['avatarUrl'] = photoUrl;
    }
    await reference.set(payload, SetOptions(merge: true));

    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final teamsSnap = await _firestore.collection('teams').where('memberIds', arrayContains: user.uid).get();
        for (final doc in teamsSnap.docs) {
          final members = (doc.data()['members'] as List? ?? []).map((m) {
            final map = Map<String, dynamic>.from(m as Map);
            if (map['studentId'] == user.uid) {
              map['avatarUrl'] = photoUrl;
            }
            return map;
          }).toList();
          await doc.reference.update({'members': members});
        }
      } catch (_) {}
    }

    final saved = (await reference.get()).data()!;
    final student = Student(
      id: user.uid,
      email: saved['email'] as String,
      fullName: saved['fullName'] as String,
      studentCode: saved['studentCode'] as String,
      major: saved['major'] as String,
      cohort: saved['cohort'] as String,
      avatarUrl: (saved['avatarUrl'] as String?) ?? photoUrl,
      skills: List<String>.from(saved['skills'] ?? const []),
      preferredRoles: List<String>.from(saved['preferredRoles'] ?? const []),
      mentorId: allowed.data()?['mentorId'] as String?,
    );
    if (_messagingInitializedFor.add(user.uid)) {
      await _messaging.initialize(user.uid);
    }
    return student;
  }

  @override
  Future<void> signOut() async {
    await _signOutSilently();
    _currentStudent = null;
  }

  Future<void> _signOutSilently() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
