import 'package:flutter/foundation.dart';

import '../models/mentor.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

/// Lecturer directory: search, expertise chips and an "available only" filter.
class MentorListViewModel extends ChangeNotifier {
  MentorListViewModel(this._mentors, this._analytics, this._crash);

  final MentorRepository _mentors;
  final AnalyticsService _analytics;
  final CrashReporter _crash;

  static const expertiseFilters = ['AI/ML', 'Web/Cloud', 'Mobile', 'Cybersecurity'];

  ViewState<List<Mentor>> state = const Loading();
  String query = '';
  String? expertise;
  bool availableOnly = false;

  Future<void> load() async {
    state = const Loading();
    notifyListeners();
    await _fetch();
  }

  Future<void> search(String value) async {
    query = value;
    await _fetch();
  }

  /// Tapping the selected chip clears it.
  Future<void> toggleExpertise(String value) async {
    expertise = expertise == value ? null : value;
    await _fetch();
  }

  Future<void> toggleAvailableOnly() async {
    availableOnly = !availableOnly;
    await _fetch();
  }

  Future<void> reset() async {
    query = '';
    expertise = null;
    availableOnly = false;
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final list = await _mentors.searchMentors(query: query, expertise: expertise, availableOnly: availableOnly);
      state = list.isEmpty ? const Empty() : Data(list);
      if (query.isNotEmpty) {
        await _analytics.logSearch(term: query, resultCount: list.length, filters: [?expertise]);
      }
    } catch (e, st) {
      state = Failure(await toFailure(e, st, crash: _crash, reason: 'mentor_search'));
    }
    notifyListeners();
  }
}
