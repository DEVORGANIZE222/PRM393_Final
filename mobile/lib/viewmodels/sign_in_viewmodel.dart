import 'package:flutter/foundation.dart';

import '../models/view_state.dart';
import '../services/services.dart';

enum SignInStatus { idle, signingIn }

/// SCR_01: Google sign-in with cancel and wrong-domain handling.
class SignInViewModel extends ChangeNotifier {
  SignInViewModel(this._auth, this._analytics);

  final AuthService _auth;
  final AnalyticsService _analytics;

  SignInStatus status = SignInStatus.idle;
  var _disposed = false;

  /// Inline message under the button (cancelled, wrong domain, offline).
  AppFailure? message;

  Future<void> signIn() async {
    if (status == SignInStatus.signingIn) return;
    status = SignInStatus.signingIn;
    message = null;
    _notifyIfActive();
    try {
      await _auth.signInWithGoogle();
      await _analytics.logLogin(method: 'google');
    } on SignInCancelled {
      message = const AppFailure(
        'Sign-in cancelled',
        'Tap "Continue with Google" when you are ready.',
        code: 'cancelled',
      );
    } on EmailNotAllowed catch (e) {
      message = AppFailure(
        'This account is not on the class roster',
        'You chose ${e.email}. Use an email that the Academic Office has approved for this class.',
        code: 'email-not-allowed',
      );
    } on AppFailure catch (f) {
      message = f;
    } catch (e) {
      message = AppFailure.unexpected(e);
    } finally {
      status = SignInStatus.idle;
      // A successful sign-in can immediately redirect away from this route.
      // Do not notify an already-disposed ViewModel after that async boundary.
      _notifyIfActive();
    }
  }

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
