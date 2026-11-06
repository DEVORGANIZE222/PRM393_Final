import 'package:flutter/widgets.dart';
import 'package:core/core.dart' show TeamSubmissionService;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../firebase/firebase_analytics_service.dart';
import '../firebase/firebase_auth_service.dart';
import '../firebase/firebase_crash_reporter.dart';
import '../firebase/firebase_notification_repository.dart';
import '../firebase/firebase_messaging_service.dart';
import '../firebase/firebase_pool_repository.dart';
import '../firebase/firebase_remote_config_service.dart';
import '../firebase/firebase_storage_service.dart';
import '../firebase/firestore_team_repository.dart';
import '../services/pdf_report_service.dart';
import '../services/services.dart';
import '../viewmodels/session_viewmodel.dart';

/// Root navigator, also used by the local account picker.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Composition root: the only place that names concrete service classes.
///
/// Screens and ViewModels depend only on interfaces; this is the production
/// composition root for the Firebase implementations.
class AppServices {
  AppServices._(this.providers);

  final List<SingleChildWidget> providers;

  static Future<AppServices> create() async {
    final messaging = FirebaseMessagingService();
    final auth = FirebaseAuthService(messaging: messaging);
    final AnalyticsService analytics = FirebaseAnalyticsService();
    final CrashReporter crash = FirebaseCrashReporter();
    final config = FirebaseRemoteConfigService();
    await config.initialize();

    return AppServices._([
      Provider<AuthService>.value(value: auth),
      Provider<FirebaseMessagingService>.value(value: messaging),
      Provider<TeamRepository>.value(value: FirestoreTeamRepository()),
      Provider<TeamSubmissionService>.value(value: TeamSubmissionService()),
      Provider<NotificationRepository>.value(value: FirebaseNotificationRepository()),
      Provider<RegistrationService>.value(value: FirebaseRegistrationService()),
      Provider<PoolRepository>.value(value: FirebasePoolRepository()),
      Provider<ConfigService>.value(value: config),
      Provider<AnalyticsService>.value(value: analytics),
      Provider<CrashReporter>.value(value: crash),
      Provider<ReportService>.value(value: PdfReportService()),
      Provider<StorageService>.value(value: FirebaseStorageService()),
      ChangeNotifierProvider<SessionViewModel>(create: (_) => SessionViewModel(auth, analytics, crash)),
    ]);
  }
}
