import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/registration.dart';
import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

class DashboardData {
  const DashboardData({
    required this.student,
    required this.window,
    required this.team,
    required this.closedByConfig,
    required this.showPoolEntry,
    required this.now,
  });

  final Student student;
  final RegistrationWindow window;
  final Team? team;

  /// Remote Config `registration_closed` (forces the closed state for demos).
  final bool closedByConfig;
  final bool showPoolEntry;
  final DateTime now;

  /// Derived from [now], so the closed state appears when the deadline passes (CR-06).
  bool get registrationClosed => closedByConfig || window.isClosed(now);

  Duration get timeLeft => window.closesAt.difference(now);

  /// Deadline is urgent below 48 hours (Lab 2 critique F-05).
  bool get urgent => timeLeft.inHours < 48;

  /// "Formation health" chips on the Figma Dashboard.
  bool get sizeOk => team?.meetsSizeRule ?? false;
  bool get leaderOk => team?.hasLeader ?? false;

  DashboardData withTeam(Team? team) => _copy(team, now);
  DashboardData at(DateTime time) => _copy(team, time);

  DashboardData _copy(Team? team, DateTime now) => DashboardData(
    student: student,
    window: window,
    team: team,
    closedByConfig: closedByConfig,
    showPoolEntry: showPoolEntry,
    now: now,
  );
}

/// SCR_02: deadline countdown, team status, next step.
class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel(this._student, this._teams, this._registration, this._config, this._crash) {
    _configSub = _config.changes.listen((_) => load());
    _teamSub = _teams.watchTeamOf(_student.id).listen(
      _onTeam,
      // Keeps the last loaded dashboard; recorded as a handled error.
      onError: (Object e, StackTrace st) => toFailure(e, st, crash: _crash, reason: 'dashboard_team_watch'),
    );
    // The countdown, the Urgent badge and the closed state follow the real-time clock (CR-06).
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final Student _student;
  final TeamRepository _teams;
  final RegistrationService _registration;
  final ConfigService _config;
  final CrashReporter _crash;
  late final StreamSubscription<void> _configSub;
  late final StreamSubscription<Team?> _teamSub;
  late final Timer _clock;

  ViewState<DashboardData> state = const Loading();

  Future<void> load() async {
    state = const Loading();
    notifyListeners();
    try {
      final results = await Future.wait([_registration.currentWindow(), _teams.teamOf(_student.id)]);
      final window = results[0] as RegistrationWindow;
      final now = DateTime.now();
      state = Data(
        DashboardData(
          student: _student,
          window: window,
          team: results[1] as Team?,
          closedByConfig: _config.getBool(ConfigKeys.registrationClosed),
          showPoolEntry: _config.getBool(ConfigKeys.enableWaitingPool),
          now: now,
        ),
      );
    } catch (e, st) {
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'dashboard_load'));
    }
    notifyListeners();
  }

  /// Team changed elsewhere (joined, voted, locked): update without a spinner.
  void _onTeam(Team? team) {
    final s = state;
    if (s is! Data<DashboardData>) return;
    state = Data(s.value.withTeam(team));
    notifyListeners();
  }

  Future<AppFailure?> unlockTeam(Team team) async {
    try {
      final updated = await _teams.unlockTeam(team.id, _student.id);
      _onTeam(updated);
      return null;
    } catch (e, st) {
      return toFailure(e, st, crash: _crash, reason: 'dashboard_unlock');
    }
  }

  void _tick() {
    final s = state;
    if (s is! Data<DashboardData>) return;
    state = Data(s.value.at(DateTime.now()));
    notifyListeners();
  }

  @override
  void dispose() {
    _clock.cancel();
    _teamSub.cancel();
    _configSub.cancel();
    super.dispose();
  }
}
