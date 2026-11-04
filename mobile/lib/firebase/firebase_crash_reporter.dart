import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../services/services.dart';

/// Firebase Crashlytics implementation.
class FirebaseCrashReporter implements CrashReporter {
  FirebaseCrashReporter([FirebaseCrashlytics? crashlytics])
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;
  final FirebaseCrashlytics _crashlytics;
  @override
  Future<void> setUserId(String? id) async {
    await _crashlytics.setUserIdentifier(id ?? '');
  }

  @override
  Future<void> setKey(String key, Object value) async {
    await _crashlytics.setCustomKey(key, value);
  }

  @override
  Future<void> recordError(Object error, StackTrace stack, {required String reason}) async {
    await _crashlytics.recordError(error, stack, reason: reason);
  }

  @override
  Future<void> testCrash() async {
    _crashlytics.crash();
  }
}
