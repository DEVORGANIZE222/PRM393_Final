import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/app_notification.dart';
import '../../models/registration.dart';
import '../services.dart';
import 'local_database.dart';

/// Development implementations used until the Firebase teammate's versions
/// replace them in app/providers.dart.

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository(this._db);
  final LocalDatabase _db;

  List<AppNotification> _list(String uid) => List.unmodifiable(_db.notifications[uid] ?? const []);

  @override
  Stream<List<AppNotification>> watch(String studentId) async* {
    await _db.roundTrip();
    yield _list(studentId);
    yield* _db.notificationChanges.where((uid) => uid == studentId).map((_) => _list(studentId));
  }

  @override
  Future<void> markRead(String studentId, String notificationId) async {
    final list = _db.notifications[studentId];
    if (list == null) return;
    final i = list.indexWhere((n) => n.id == notificationId);
    if (i >= 0) list[i] = list[i].copyWith(read: true);
    _db.notificationsChanged(studentId);
  }

  @override
  Future<void> markAllRead(String studentId) async {
    final list = _db.notifications[studentId];
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(read: true);
    }
    _db.notificationsChanged(studentId);
  }

  @override
  Future<void> remove(String studentId, String notificationId) async {
    _db.notifications[studentId]?.removeWhere((n) => n.id == notificationId);
    _db.notificationsChanged(studentId);
  }

  @override
  Future<void> restore(String studentId, AppNotification notification) async {
    final list = _db.notifications.putIfAbsent(studentId, () => []);
    list.add(notification);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _db.notificationsChanged(studentId);
  }
}

class LocalRegistrationService implements RegistrationService {
  LocalRegistrationService(this._db);
  final LocalDatabase _db;

  @override
  Future<RegistrationWindow> currentWindow() async {
    await _db.roundTrip();
    final r = _db.seed['registration'] as Map<String, dynamic>;
    final closesAt = _db.launchedAt.add(Duration(hours: r['closesInHours'] as int));
    return RegistrationWindow(
      semester: r['semester'] as String,
      closesAt: closesAt,
      opensAt: closesAt.subtract(Duration(hours: r['windowHours'] as int)),
    );
  }
}

class LocalPoolRepository implements PoolRepository {
  LocalPoolRepository(this._db);
  final LocalDatabase _db;

  @override
  Future<PoolStatus> statusOf(String studentId) async {
    await _db.roundTrip();
    final p = _db.seed['pool'] as Map<String, dynamic>;
    final student = _db.students[studentId];
    return PoolStatus(
      queueId: p['queueId'] as String,
      progress: (p['progress'] as num).toDouble(),
      stage: p['stage'] as String,
      expectedResult: _db.launchedAt.add(Duration(hours: p['expectedInHours'] as int)),
      preferredRoles: student?.preferredRoles ?? const [],
      skills: student?.skills ?? const [],
      studentsInPool: p['studentsInPool'] as int,
      contactEmail: p['contactEmail'] as String,
      lastChecked: DateTime.now(),
    );
  }
}

/// In-app defaults, plus build-time overrides for demos and screenshots:
/// `--dart-define=CONFIG_OVERRIDES=registration_closed=true,browse_max_results=3`.
/// `FirebaseConfigService` adds fetch/activate and real-time updates with the
/// same keys and defaults.
class LocalConfigService implements ConfigService {
  LocalConfigService() {
    const overrides = String.fromEnvironment('CONFIG_OVERRIDES');
    for (final pair in overrides.split(',').where((p) => p.contains('='))) {
      final [key, raw] = pair.split('=');
      final fallback = ConfigKeys.defaults[key];
      if (fallback is int) _values[key] = int.tryParse(raw) ?? fallback;
      if (fallback is bool) _values[key] = raw == 'true';
    }
  }

  final _changes = StreamController<void>.broadcast();
  final Map<String, Object> _values = Map.of(ConfigKeys.defaults);

  @override
  int getInt(String key) => _values[key] as int? ?? ConfigKeys.defaults[key] as int;

  @override
  bool getBool(String key) => _values[key] as bool? ?? ConfigKeys.defaults[key] as bool;

  @override
  Future<bool> refresh() async => false;

  @override
  Stream<void> get changes => _changes.stream;
}

/// Prints events to Logcat (tag `flutter`) so an E2E test can check them.
class DebugAnalyticsService implements AnalyticsService {
  final List<String> events = [];

  Future<void> _log(String name, [Map<String, Object> params = const {}]) async {
    final line = 'analytics_event $name $params';
    events.add(line);
    debugPrint(line);
  }

  @override
  Future<void> setUserId(String? id) => _log('set_user_id', {'id': id ?? 'null'});
  @override
  Future<void> logLogin({required String method}) => _log('login', {'method': method});
  @override
  Future<void> logLogout() => _log('logout');
  @override
  Future<void> logSearch({required String term, required int resultCount, required List<String> filters}) =>
      _log('search', {'search_term': term, 'result_count': resultCount, 'filters': filters.join(',')});
  @override
  Future<void> logViewTeam({required String teamId, required String teamCode}) =>
      _log('view_team', {'team_id': teamId, 'team_code': teamCode});
  @override
  Future<void> logCreateTeam({required String teamId, required String teamCode}) =>
      _log('create_team', {'team_id': teamId, 'team_code': teamCode});
  @override
  Future<void> logJoinTeam({required String teamId, required int memberCount}) =>
      _log('join_group', {'group_id': teamId, 'member_count': memberCount});
  @override
  Future<void> logVote({required String teamId, required bool changed}) =>
      _log('cast_vote', {'team_id': teamId, 'changed': changed});
  @override
  Future<void> logInviteFromPool({required String teamId, required int invited}) =>
      _log('invite_from_pool', {'team_id': teamId, 'invited': invited});
  @override
  Future<void> logLockRoster({required String teamId, required int memberCount}) =>
      _log('lock_roster', {'team_id': teamId, 'member_count': memberCount});
  @override
  Future<void> logExportReport({required String teamId, required int fileSizeKb}) =>
      _log('export_report', {'team_id': teamId, 'file_size_kb': fileSizeKb});
  @override
  Future<void> logAiRequest({required String feature, required String model}) =>
      _log('ai_request', {'feature': feature, 'model': model});
  @override
  Future<void> logAiResultAccepted({required String feature}) =>
      _log('ai_result_accepted', {'feature': feature});
  @override
  Future<void> logAiError({required String feature, required String errorReason}) =>
      _log('ai_error', {'feature': feature, 'reason': errorReason});
}

class DebugCrashReporter implements CrashReporter {
  @override
  Future<void> setUserId(String? id) async => debugPrint('crash_reporter user_id=$id');
  @override
  Future<void> setKey(String key, Object value) async => debugPrint('crash_reporter key $key=$value');
  @override
  Future<void> recordError(Object error, StackTrace stack, {required String reason}) async =>
      debugPrint('crash_reporter non_fatal reason="$reason" error=$error');
  @override
  Future<void> testCrash() async => debugPrint('crash_reporter test_crash (Crashlytics not connected)');
}

/// Copies the file under the app's documents folder with the same per-user
/// path Cloud Storage will use (`reports/{uid}/...`).
class LocalStorageService implements StorageService {
  @override
  Stream<UploadProgress> uploadReport({required File file, required String uid}) async* {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/reports/$uid');
    await dir.create(recursive: true);
    for (final f in [0.1, 0.35, 0.6, 0.85]) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      yield UploadProgress(fraction: f);
    }
    final target = await file.copy('${dir.path}/${file.uri.pathSegments.last}');
    yield UploadProgress(fraction: 1, downloadUrl: target.uri.toString());
  }
}
