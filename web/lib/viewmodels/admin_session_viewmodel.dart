import 'dart:async';

import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/admin_auth_service.dart';

class AdminSessionViewModel extends ChangeNotifier {
  AdminSessionViewModel(this._auth) {
    _subscription = _auth.authChanges.listen(_resolveSession);
  }

  final AdminAuthService _auth;
  late final StreamSubscription<User?> _subscription;
  UserProfile? profile;
  User? firebaseUser;
  String? error;
  bool ready = false;
  bool signingIn = false;

  bool get isAuthorized => profile?.isAdmin == true;

  Future<void> _resolveSession(User? user) async {
    profile = null;
    firebaseUser = user;
    if (user == null) {
      ready = true;
      notifyListeners();
      return;
    }

    error = null;
    try {
      profile = await _auth.currentAuthorizedProfile(user);
      if (profile == null) {
        error = 'This Google account is not authorized for Admin access.';
        ready = true;
        notifyListeners();
        await _auth.signOut();
        return;
      }
    } catch (_) {
      error = 'Could not verify your account role. Check your connection and try again.';
      ready = true;
      notifyListeners();
      await _auth.signOut();
      return;
    }
    ready = true;
    notifyListeners();
  }

  Future<void> signIn() async {
    if (signingIn) return;
    signingIn = true;
    error = null;
    notifyListeners();
    try {
      await _auth.signInWithGoogle();
    } catch (_) {
      error = 'Google sign-in could not be completed. Please try again.';
    } finally {
      signingIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
