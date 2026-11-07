import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/app_notification.dart';
import '../../models/mentor.dart';
import '../../models/student.dart';
import '../../models/team.dart';
import '../../models/view_state.dart';

/// In-memory store for the local (pre-Firebase) services, seeded from
/// `assets/seed/seed.json` on every app launch, so every E2E test starts from
/// the same data. Replaced by Cloud Firestore in the submitted build.
class LocalDatabase {
  LocalDatabase({this.latency = const Duration(milliseconds: 500), this.requireNetwork = true});

  final Duration latency;

  /// The local services refuse to answer without connectivity, so the app's
  /// offline/error states can be exercised exactly as with Firestore.
  final bool requireNetwork;

  late final Map<String, dynamic> _seed;
  final Map<String, Student> students = {};
  final Map<String, Team> teams = {};
  final Map<String, List<AppNotification>> notifications = {};
  final List<TeamMember> poolStudents = [];
  final Set<String> fillsOnNextJoin = {};
  final Map<String, Mentor> mentors = {};

  /// teamId → that team's request.
  final Map<String, MentorRequest> mentorRequests = {};
  late final DateTime launchedAt;

  final _teamChanges = StreamController<Team>.broadcast();
  final _notificationChanges = StreamController<String>.broadcast();
  final _mentorRequestChanges = StreamController<String>.broadcast();

  Stream<Team> get teamChanges => _teamChanges.stream;
  Stream<String> get notificationChanges => _notificationChanges.stream;
  Stream<String> get mentorRequestChanges => _mentorRequestChanges.stream;

  Map<String, dynamic> get seed => _seed;

  Future<void> load() async {
    launchedAt = DateTime.now();
    _seed = jsonDecode(await rootBundle.loadString('assets/seed/seed.json')) as Map<String, dynamic>;
    for (final s in _seed['students'] as List) {
      final st = Student.fromJson(s as Map<String, dynamic>);
      students[st.id] = st;
    }
    for (final t in _seed['teams'] as List) {
      final map = t as Map<String, dynamic>;
      final team = Team.fromJson(map);
      teams[team.id] = team;
      if (map['_scenario'] == 'fillsOnNextJoin') fillsOnNextJoin.add(team.id);
    }
    for (final p in _seed['poolStudents'] as List) {
      poolStudents.add(TeamMember.fromJson(p as Map<String, dynamic>));
    }
    (_seed['notifications'] as Map<String, dynamic>).forEach((uid, list) {
      notifications[uid] = [
        for (final n in list as List) AppNotification.fromJson(n as Map<String, dynamic>, launchedAt),
      ];
    });
  }

  /// Simulates a round trip: waits [latency] and fails with
  /// [AppFailure.offline] when the device has no connectivity.
  Future<void> roundTrip() async {
    await Future<void>.delayed(latency);
    if (!requireNetwork) return;
    try {
      final result = await InternetAddress.lookup('firestore.googleapis.com').timeout(const Duration(seconds: 4));
      if (result.isEmpty || result.first.rawAddress.isEmpty) throw AppFailure.offline;
    } on SocketException {
      throw AppFailure.offline;
    } on TimeoutException {
      throw AppFailure.offline;
    }
  }

  void putTeam(Team team) {
    teams[team.id] = team;
    _teamChanges.add(team);
  }

  void putMentorRequest(MentorRequest request) {
    mentorRequests[request.teamId] = request;
    _mentorRequestChanges.add(request.teamId);
  }

  void removeMentorRequest(String teamId) {
    mentorRequests.remove(teamId);
    _mentorRequestChanges.add(teamId);
  }

  void addNotification(String uid, AppNotification n) {
    notifications.putIfAbsent(uid, () => []).insert(0, n);
    _notificationChanges.add(uid);
  }

  void notificationsChanged(String uid) => _notificationChanges.add(uid);
}
