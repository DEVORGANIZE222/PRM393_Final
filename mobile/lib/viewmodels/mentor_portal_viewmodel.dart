import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/mentor.dart';
import '../models/registration.dart';
import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

/// The lecturer's home: live team requests to answer, and the teams they supervise.
class MentorPortalViewModel extends ChangeNotifier {
  MentorPortalViewModel(
    this._me,
    this._mentors,
    this._analytics,
    this._crash, {
    RegistrationService? registration,
    ConfigService? config,
  })  : _registration = registration,
        _config = config {
    final cfg = _config;
    if (cfg != null) {
      _configSub = cfg.changes.listen((_) => _onConfigChanged());
    }
    final reg = _registration;
    if (reg != null) {
      _windowSub = reg.watchWindow().listen(
        _onWindow,
        onError: (Object e, StackTrace st) => toFailure(e, st, crash: _crash, reason: 'mentor_portal_window_watch'),
      );
    }
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final Student _me;
  final MentorRepository _mentors;
  final AnalyticsService _analytics;
  final CrashReporter _crash;
  final RegistrationService? _registration;
  final ConfigService? _config;

  StreamSubscription<List<MentorRequest>>? _watch;
  StreamSubscription<RegistrationWindow>? _windowSub;
  StreamSubscription<void>? _configSub;
  Timer? _clock;

  ViewState<Mentor> state = const Loading();
  List<MentorRequest> requests = const [];
  List<Team> teams = const [];
  bool processing = false;

  RegistrationWindow? window;
  DateTime now = DateTime.now();
  bool closedByConfig = false;

  int get pendingCount => requests.where((r) => r.isPending).length;

  bool get registrationClosed => closedByConfig || (window != null && window!.isClosed(now));
  Duration? get timeLeft => window?.closesAt.difference(now);
  bool get urgent => timeLeft != null && timeLeft!.inHours < 48;
  double get remainingFraction => window == null ? 1.0 : (1.0 - window!.elapsed(now)).clamp(0.0, 1.0);

  void _onWindow(RegistrationWindow w) {
    window = w;
    notifyListeners();
  }

  void _onConfigChanged() {
    final cfg = _config;
    if (cfg != null) {
      closedByConfig = cfg.getBool(ConfigKeys.registrationClosed);
      notifyListeners();
    }
  }

  void _tick() {
    now = DateTime.now();
    notifyListeners();
  }

  Future<void> load() async {
    state = const Loading();
    notifyListeners();

    final reg = _registration;
    if (reg != null) {
      try {
        window = await reg.currentWindow();
      } catch (_) {}
    }
    final cfg = _config;
    if (cfg != null) {
      closedByConfig = cfg.getBool(ConfigKeys.registrationClosed);
    }

    final id = _me.mentorId!;
    try {
      await _refresh(id);
      await _watch?.cancel();
      _watch = _mentors.watchRequestsForMentor(id).listen(
        (list) async {
          requests = list;
          // A request just answered changes the quota and the team list.
          try {
            await _refresh(id);
          } catch (e, st) {
            state = Failure(await toFailure(e, st, crash: _crash, reason: 'mentor_portal_refresh'));
          }
          notifyListeners();
        },
        onError: (Object e, StackTrace st) async {
          state = Failure(await toFailure(e, st, crash: _crash, reason: 'mentor_portal_watch'));
          notifyListeners();
        },
      );
    } catch (e, st) {
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'mentor_portal_load'));
    }
    notifyListeners();
  }

  Future<void> _refresh(String id) async {
    final mentor = await _mentors.getMentor(id);
    teams = await _mentors.teamsOfMentor(id);
    state = Data(mentor);
  }

  Future<AppFailure?> respond(MentorRequest request, {required bool accept, String? reason}) async {
    processing = true;
    notifyListeners();
    try {
      await _mentors.respond(request: request, accept: accept, reason: reason);
      await _analytics.logRespondMentor(teamId: request.teamId, accepted: accept);
      return null;
    } catch (e, st) {
      return toFailure(e, st, crash: _crash, reason: 'respond_mentor');
    } finally {
      processing = false;
      notifyListeners();
    }
  }

  bool _disposed = false;

  // The stream callback can finish after the screen closed.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    _windowSub?.cancel();
    _configSub?.cancel();
    _watch?.cancel();
    super.dispose();
  }
}
