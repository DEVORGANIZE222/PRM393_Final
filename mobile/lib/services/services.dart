/// Service interfaces. Screens never import these directly; ViewModels receive
/// them through their constructor (see app/providers.dart). Each interface has a
/// local development implementation (services/local/) and a Firebase
/// implementation (firebase/, owned by the Firebase integration teammate).
library;

export 'package:core/services/mentor_repository.dart' show MentorRepository, filterMentors;

import 'dart:io';

import '../models/app_notification.dart';
import '../models/registration.dart';
import '../models/student.dart';
import '../models/team.dart';

// ---------------------------------------------------------------------------
// Authentication (Firebase Auth + Google Sign-In)
// ---------------------------------------------------------------------------

/// Thrown when the user closes the account picker.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// Thrown when a Google account is not present in the administrator's roster.
///
/// The roster is stored in Firestore, not bundled into the application.
class EmailNotAllowed implements Exception {
  const EmailNotAllowed(this.email);
  final String email;
}

abstract interface class AuthService {
  /// Emits the signed-in student, or null when signed out.
  Stream<Student?> authStateChanges();
  Student? get currentStudent;

  /// Opens the Google account picker. Throws [SignInCancelled], [EmailNotAllowed]
  /// or an `AppFailure`.
  Future<Student> signInWithGoogle();

  /// Signs out and clears local user data.
  Future<void> signOut();
}

// ---------------------------------------------------------------------------
// Data (Cloud Firestore)
// ---------------------------------------------------------------------------

class TeamFullException implements Exception {
  const TeamFullException(this.teamCode);
  final String teamCode;
}

class AlreadyInTeamException implements Exception {
  const AlreadyInTeamException(this.teamCode);
  final String teamCode;
}

abstract interface class TeamRepository {
  Future<List<Team>> searchTeams({String query = '', Set<TeamFilter> filters = const {}, int limit = 20});
  Future<Team> getTeam(String teamId);

  /// The student's current team, or null.
  Future<Team?> teamOf(String studentId);

  /// Emits every change to one team (votes, members joining from the pool, lock).
  Stream<Team> watchTeam(String teamId);

  /// Emits the student's team (or null) whenever it changes: joining, leaving,
  /// votes, pool members, lock. Firestore: teams where memberIds contains uid.
  Stream<Team?> watchTeamOf(String studentId);

  /// Emits whenever any team changes (members, lock), so lists can refresh
  /// their open-slot counts. Firestore: a snapshot listener on `teams`.
  Stream<void> teamsChanged();

  /// Joins after a server-side capacity check. Throws [TeamFullException] or
  /// [AlreadyInTeamException].
  Future<Team> joinTeam(String teamId, Student student);
  Future<void> leaveTeam(String teamId, String studentId);

  /// Records or replaces the student's vote and elects a leader on majority.
  Future<Team> castVote(String teamId, String voterId, String candidateId);

  /// Locks the roster (leader only, 4–5 members). Returns the locked team with its code.
  Future<Team> lockTeam(String teamId, String leaderId);

  /// Unlocks the roster (leader only, recovery).
  Future<Team> unlockTeam(String teamId, String leaderId);

  /// Invites matching students from the Waiting Pool. Returns how many were invited.
  Future<int> inviteFromPool(String teamId);

  /// Creates a new team with the student as founder and first member.
  Future<Team> createTeam({
    required Student student,
    required String name,
    required String topic,
    required String category,
    String? description,
    List<String> tags = const [],
    List<String> openRoles = const [],
    int capacity = 5,
  });

  /// Seeds mock members into a team (development / demo helper).
  Future<void> seedMembersToTeam(String teamId, {int count = 2});
}

abstract interface class NotificationRepository {
  Stream<List<AppNotification>> watch(String studentId);
  Future<void> markRead(String studentId, String notificationId);
  Future<void> markAllRead(String studentId);
  Future<void> remove(String studentId, String notificationId);
  Future<void> restore(String studentId, AppNotification notification);
}

abstract interface class RegistrationService {
  Future<RegistrationWindow> currentWindow();
  Stream<RegistrationWindow> watchWindow();
}

abstract interface class PoolRepository {
  Future<PoolStatus> statusOf(String studentId);
}

// ---------------------------------------------------------------------------
// Remote Config
// ---------------------------------------------------------------------------

/// Remote Config keys with in-app defaults (firebase/remote-config-defaults.json).
abstract final class ConfigKeys {
  static const maxTeamMembers = 'max_team_members';

  /// Shows the Random Pool entry on Dashboard (bool, default true).
  static const enableWaitingPool = 'enable_waiting_pool';

  /// Forces the "registration closed" Dashboard state (bool, default false).
  static const registrationClosed = 'registration_closed';

  static const defaults = <String, Object>{
    maxTeamMembers: 5,
    enableWaitingPool: true,
    'urgent_deadline_days': 3,
    'banner_announcement': 'Registration deadline is approaching.',
    registrationClosed: false,
  };
}

abstract interface class ConfigService {
  int getInt(String key);
  bool getBool(String key);

  /// Fetches and activates new values. Returns true when something changed.
  Future<bool> refresh();

  /// Emits after new values are activated (real-time updates).
  Stream<void> get changes;
}

// ---------------------------------------------------------------------------
// Analytics and Crashlytics
// ---------------------------------------------------------------------------

/// Event names follow docs/analytics-plan.md (owned by the Firebase teammate).
/// Parameters never contain personal data (no e-mail, no name).
abstract interface class AnalyticsService {
  Future<void> setUserId(String? id);
  Future<void> logLogin({required String method});
  Future<void> logLogout();
  Future<void> logSearch({required String term, required int resultCount, required List<String> filters});
  Future<void> logViewTeam({required String teamId, required String teamCode});
  Future<void> logCreateTeam({required String teamId, required String teamCode});
  Future<void> logJoinTeam({required String teamId, required int memberCount});
  Future<void> logVote({required String teamId, required bool changed});
  Future<void> logInviteFromPool({required String teamId, required int invited});
  Future<void> logLockRoster({required String teamId, required int memberCount});
  Future<void> logExportReport({required String teamId, required int fileSizeKb});
  Future<void> logViewMentor({required String mentorId});
  Future<void> logRequestMentor({required String teamId, required String mentorId});
  Future<void> logRespondMentor({required String teamId, required bool accepted});
  Future<void> logAiRequest({required String feature, required String model});
  Future<void> logAiResultAccepted({required String feature});
  Future<void> logAiError({required String feature, required String errorReason});
}

abstract interface class CrashReporter {
  Future<void> setUserId(String? id);
  Future<void> setKey(String key, Object value);

  /// Non-fatal error from a real error path.
  Future<void> recordError(Object error, StackTrace stack, {required String reason});

  /// Forces a test crash (Crashlytics demo on Profile).
  Future<void> testCrash();
}

// ---------------------------------------------------------------------------
// File export (PDF) and Cloud Storage
// ---------------------------------------------------------------------------

abstract interface class ReportService {
  /// Builds a PDF summary of what the student sees on My Team.
  Future<File> buildTeamSummary({required Team team, required Student student, required DateTime generatedAt});
}

class UploadProgress {
  const UploadProgress({required this.fraction, this.downloadUrl});
  final double fraction;
  final String? downloadUrl;
  bool get done => downloadUrl != null;
}

abstract interface class StorageService {
  /// Uploads to `reports/{uid}/{fileName}` and reports progress; the last event carries the URL.
  Stream<UploadProgress> uploadReport({required File file, required String uid});
}
