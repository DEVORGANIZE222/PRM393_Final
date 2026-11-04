/// Explicit state model owned by each data-loading ViewModel (handout §5).
sealed class ViewState<T> {
  const ViewState();
}

final class Loading<T> extends ViewState<T> {
  const Loading();
}

final class Empty<T> extends ViewState<T> {
  const Empty();
}

final class Failure<T> extends ViewState<T> {
  const Failure(this.failure);
  final AppFailure failure;
}

final class Data<T> extends ViewState<T> {
  const Data(this.value);
  final T value;
}

/// A user-facing failure. Copy follows the UX-writing checklist: the title says
/// what happened, the cause says why and what to do, and the user is never blamed.
class AppFailure implements Exception {
  const AppFailure(this.title, this.cause, {this.retryable = true, this.code});

  final String title;
  final String cause;
  final bool retryable;
  final String? code;

  static const offline = AppFailure(
    "Can't connect right now",
    'Check your Wi-Fi or mobile data, then try again. Nothing you entered is lost.',
    code: 'offline',
  );

  static const permissionDenied = AppFailure(
    "You don't have access to this",
    'Sign in with your @fpt.edu.vn account, or ask your team leader to add you.',
    retryable: false,
    code: 'permission-denied',
  );

  static AppFailure unexpected([Object? error]) => const AppFailure(
    'Something went wrong on our side',
    'Try again in a moment. If it keeps happening, contact the Academic Office.',
    code: 'unexpected',
  );

  @override
  String toString() => 'AppFailure($code): $title';
}
