import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

sealed class ExportState {
  const ExportState();
}

final class ExportIdle extends ExportState {
  const ExportIdle();
}

final class ExportGenerating extends ExportState {
  const ExportGenerating();
}

final class ExportUploading extends ExportState {
  const ExportUploading(this.fraction, this.fileName, this.sizeKb);
  final double fraction;
  final String fileName;
  final int sizeKb;
}

final class ExportDone extends ExportState {
  const ExportDone(this.url, this.fileName, this.sizeKb);
  final String url;
  final String fileName;
  final int sizeKb;
}

final class ExportFailed extends ExportState {
  const ExportFailed(this.failure);
  final AppFailure failure;
}

/// Profile (added screen): account, file export + upload, Remote Config values,
/// Crashlytics demo actions and sign-out.
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(
    this._student,
    this._teams,
    this._reports,
    this._storage,
    this._config,
    this._crash,
    this._analytics,
  ) {
    _configSub = _config.changes.listen((_) => notifyListeners());
  }

  final Student _student;
  final TeamRepository _teams;
  final ReportService _reports;
  final StorageService _storage;
  final ConfigService _config;
  final CrashReporter _crash;
  final AnalyticsService _analytics;
  late final StreamSubscription<void> _configSub;

  Student get student => _student;
  ExportState export = const ExportIdle();
  bool refreshingConfig = false;
  AppFailure? configRefreshFailure;
  String? crashMessage;

  Map<String, String> get configValues => {
    ConfigKeys.maxTeamMembers: '${_config.getInt(ConfigKeys.maxTeamMembers)}',
    ConfigKeys.enableWaitingPool: '${_config.getBool(ConfigKeys.enableWaitingPool)}',
    ConfigKeys.registrationClosed: '${_config.getBool(ConfigKeys.registrationClosed)}',
  };

  Future<void> exportAndUpload() async {
    if (export is ExportGenerating || export is ExportUploading) return;
    export = const ExportGenerating();
    notifyListeners();
    try {
      final Team? team = await _teams.teamOf(_student.id);
      if (team == null) {
        export = const ExportFailed(
          AppFailure(
            'Nothing to export yet',
            'Join a team first. The summary lists your team, its status and its roster.',
            retryable: false,
          ),
        );
        notifyListeners();
        return;
      }
      final file = await _reports.buildTeamSummary(team: team, student: _student, generatedAt: DateTime.now());
      final sizeKb = ((await file.length()) / 1024).ceil();
      final name = file.uri.pathSegments.last;
      await for (final p in _storage.uploadReport(file: file, uid: _student.id)) {
        export = p.done ? ExportDone(p.downloadUrl!, name, sizeKb) : ExportUploading(p.fraction, name, sizeKb);
        notifyListeners();
      }
      if (export is! ExportDone) {
        // The upload ended without a download URL (cancelled or interrupted): CR-07.
        export = const ExportFailed(
          AppFailure("Upload didn't finish", 'Check your connection, then tap Export & Upload PDF again.'),
        );
        notifyListeners();
        return;
      }
      await _analytics.logExportReport(teamId: team.id, fileSizeKb: sizeKb);
    } catch (e, st) {
      export = ExportFailed(await toFailure(e, st, crash: _crash, reason: 'export_upload'));
      notifyListeners();
    }
  }

  /// Returns `null` when the server cannot be reached. The current Remote
  /// Config values remain available because the Firebase service sets defaults
  /// before its first fetch and retains the last activated values afterwards.
  Future<bool?> refreshConfig() async {
    refreshingConfig = true;
    configRefreshFailure = null;
    notifyListeners();
    try {
      return await _config.refresh();
    } catch (error, stack) {
      configRefreshFailure = await toFailure(
        error,
        stack,
        crash: _crash,
        reason: 'remote_config_refresh',
      );
      return null;
    } finally {
      refreshingConfig = false;
      notifyListeners();
    }
  }

  /// Handled error from a real error path (a failed lookup), reported as non-fatal.
  Future<void> sendNonFatal() async {
    try {
      await _teams.getTeam('team_that_does_not_exist');
    } catch (e, st) {
      await _crash.setKey('screen', 'profile');
      await _crash.recordError(e, st, reason: 'profile_demo_missing_team');
      crashMessage = 'Non-fatal error sent with your user ID and the key "screen".';
      notifyListeners();
    }
  }

  Future<void> testCrash() async {
    await _crash.setKey('screen', 'profile');
    await _crash.testCrash();
    crashMessage = 'Test crash requested.';
    notifyListeners();
  }

  @override
  void dispose() {
    _configSub.cancel();
    super.dispose();
  }
}
