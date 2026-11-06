import 'package:firebase_auth/firebase_auth.dart';
import 'package:core/core.dart';

class AdminAuthService {
  AdminAuthService({FirebaseAuth? auth, SharedFirestoreService? profiles})
    : _auth = auth ?? FirebaseAuth.instance,
      _profiles = profiles ?? SharedFirestoreService();

  final FirebaseAuth _auth;
  final SharedFirestoreService _profiles;

  Stream<User?> get authChanges => _auth.authStateChanges();

  Future<UserProfile?> currentAuthorizedProfile(User user) async {
    final profile = await _profiles.getUserProfile(user.uid);
    return profile?.isAdmin == true ? profile : null;
  }

  Future<void> signInWithGoogle() async {
    await _auth.signInWithPopup(GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}));
  }

  Future<void> signOut() => _auth.signOut();
}
