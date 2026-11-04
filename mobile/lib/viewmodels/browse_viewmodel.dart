import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

/// SCR_03: search, filter chips, result list (limit from Remote Config).
class BrowseViewModel extends ChangeNotifier {
  BrowseViewModel(this._teams, this._config, this._analytics, this._crash) {
    _configSub = _config.changes.listen((_) => search());
    // Slot counts change while the list is open (joins, pool members, locks):
    // refresh in place instead of patching each navigation path (CR-10).
    // A failed live update keeps the list on screen; it is recorded, not thrown
    // into the zone where Crashlytics would count it as a crash.
    _teamsSub = _teams.teamsChanged().listen(
      (_) => _run(silent: true),
      onError: (Object e, StackTrace st) => toFailure(e, st, crash: _crash, reason: 'browse_live_updates'),
    );
  }

  final TeamRepository _teams;
  final ConfigService _config;
  final AnalyticsService _analytics;
  final CrashReporter _crash;
  late final StreamSubscription<void> _configSub;
  late final StreamSubscription<void> _teamsSub;

  ViewState<List<Team>> state = const Loading();
  String query = '';
  final Set<TeamFilter> filters = {TeamFilter.openSlots};
  int _requestId = 0;

  int get maxResults => 20;
  bool get hasCriteria => query.isNotEmpty || filters.length != 1 || !filters.contains(TeamFilter.openSlots);

  Future<void> search([String? newQuery]) {
    _debounce?.cancel();
    if (newQuery != null) query = newQuery.trim();
    return _run(silent: false);
  }

  Timer? _debounce;

  /// Search as the student types (400 ms after the last key), so the list
  /// always matches the text in the box, also when a filter chip is tapped
  /// before pressing Enter (TC-03 found the two disagreeing).
  void queryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => search(text));
  }

  /// [silent] keeps the current list on screen while refreshing.
  Future<void> _run({required bool silent}) async {
    if (silent && state is! Data<List<Team>>) return;
    final id = ++_requestId;
    if (!silent) {
      state = const Loading();
      notifyListeners();
    }
    try {
      final result = await _teams.searchTeams(query: query, filters: filters, limit: maxResults);
      if (id != _requestId) return; // a newer search started
      state = result.isEmpty ? const Empty() : Data(result);
      if (!silent) {
        await _analytics.logSearch(term: query, resultCount: result.length, filters: [for (final f in filters) f.name]);
      }
    } catch (e, st) {
      if (id != _requestId || silent) return; // a failed background refresh keeps the last list
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'browse_search'));
    }
    notifyListeners();
  }

  void toggleFilter(TeamFilter filter, bool on) {
    on ? filters.add(filter) : filters.remove(filter);
    search();
  }

  void clearCriteria() {
    query = '';
    filters
      ..clear()
      ..add(TeamFilter.openSlots);
    search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _teamsSub.cancel();
    _configSub.cancel();
    super.dispose();
  }
}
