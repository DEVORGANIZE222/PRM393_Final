import '../models/view_state.dart';
import '../services/services.dart';

/// Maps any exception from a service call to a user-facing [AppFailure] and,
/// for unexpected errors, reports a non-fatal to Crashlytics.
Future<AppFailure> toFailure(Object error, StackTrace stack, {CrashReporter? crash, required String reason}) async {
  if (error is AppFailure) {
    if (error.code == 'unexpected') await crash?.recordError(error, stack, reason: reason);
    return error;
  }
  await crash?.recordError(error, stack, reason: reason);
  return AppFailure.unexpected(error);
}
