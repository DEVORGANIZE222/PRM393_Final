import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document(
    title: 'PRM393 Lab 3 Final Report - EXEMatching',
    author: 'DEVORGANIZE222',
  );

  // E2E results of the last full run (e2e_test/evidence): pass/fail per run from junit.xml,
  // ARTEMIS time per run from each run's result.json. Nothing here is typed in by hand.
  final runOk = <String, Map<int, bool>>{};
  final agentSeconds = <String, List<double>>{};
  final junit = File('e2e_test/evidence/junit.xml');
  if (junit.existsSync()) {
    final xml = junit.readAsStringSync();
    for (final m in RegExp(r'<testcase [^>]*name="(test_(tc\d+)_\w+)\[run(\d)\]"[^>]*?(/>|>([\s\S]*?)</testcase>)').allMatches(xml)) {
      final id = m.group(2)!.toUpperCase().replaceFirst('TC', 'TC-');
      final run = int.parse(m.group(3)!);
      final failed = (m.group(5) ?? '').contains('<failure') || (m.group(5) ?? '').contains('<error');
      final runs = runOk.putIfAbsent(id, () => {});
      runs[run] = (runs[run] ?? true) && !failed;
      final result = File('e2e_test/evidence/${m.group(1)}/run$run/result.json');
      if (result.existsSync()) {
        final seconds = (jsonDecode(result.readAsStringSync()) as Map<String, dynamic>)['seconds'];
        if (seconds is num) agentSeconds.putIfAbsent(id, () => []).add(seconds.toDouble());
      }
    }
  }
  String passCell(String id) {
    final runs = runOk[id]?.values.toList() ?? [];
    if (runs.isEmpty) return 'not run';
    final ok = runs.where((r) => r).length;
    return '$ok/${runs.length} (${(100 * ok / runs.length).round()}%)';
  }
  String timeCell(String id) {
    final s = agentSeconds[id] ?? [];
    return s.isEmpty ? '-' : '${(s.reduce((a, b) => a + b) / s.length).toStringAsFixed(1)}s';
  }
  final passedRuns = runOk.values.expand((r) => r.values).where((ok) => ok).length;
  final totalRuns = runOk.values.expand((r) => r.values).length;

  // A requirement counts as verified only when its screenshots are in the repository.
  bool captured(List<String> files) => files.every((f) => File(f).existsSync());
  String status(List<String> files) => captured(files) ? 'VERIFIED' : 'NOT CAPTURED YET';
  String check(List<String> files) => captured(files) ? '[x]' : '[ ]';
  const fcmShots = ['evidence/fcm/foreground_alerts.png', 'evidence/fcm/background_opened.png', 'evidence/fcm/terminated_opened.png'];
  const debugViewShots = ['evidence/debugview/debugview_login_user_id.jpg', 'evidence/debugview/debugview_search_teams_params.jpg', 'evidence/debugview/debugview_cast_vote_params.jpg'];
  const crashShots = ['evidence/crashlytics/crashlytics_nonfatal_keys.jpg', 'evidence/crashlytics/crashlytics_crash_keys.jpg', 'evidence/crashlytics/crashlytics_crash_user.jpg'];
  const remoteConfigShots = ['evidence/remote_config/app_before.png', 'evidence/remote_config/console_published.jpg', 'evidence/remote_config/app_after.png', 'evidence/remote_config/app_after_home.png'];
  // Filled in by hand from docs/test-plan.md section 4 once the session has really been run.
  final exploratory = File('e2e_test/exploratory/summary.txt');

  final primaryColor = PdfColor.fromHex('#1E3A8A'); // Navy
  final accentColor = PdfColor.fromHex('#0D9488');  // Teal
  final textColor = PdfColor.fromHex('#1F2937');
  final greyColor = PdfColor.fromHex('#64748B');
  final lightBg = PdfColor.fromHex('#F8FAFC');
  final borderColor = PdfColor.fromHex('#E2E8F0');

  pw.Widget buildHeader(String title, String subtitle) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(color: primaryColor, fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text(subtitle, style: pw.TextStyle(color: greyColor, fontSize: 8)),
            ],
          ),
          pw.Text('PRM393 · Lab 3 Final Report', style: pw.TextStyle(color: greyColor, fontSize: 8)),
        ],
      ),
    );
  }

  pw.Widget buildFooter(int pageNum, int totalPages) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Project EXEMatching — Team DEVORGANIZE222', style: pw.TextStyle(color: greyColor, fontSize: 8)),
          pw.Text('Page $pageNum of $totalPages', style: pw.TextStyle(color: greyColor, fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.PageTheme pageTheme() {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );
  }

  // ==================== PAGE 1: TITLE & EXECUTIVE SUMMARY ====================
  pdf.addPage(
    pw.Page(
      pageTheme: pageTheme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('FPT UNIVERSITY — PRM393 MOBILE PROGRAMMING', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('LAB 3: CLOUD-ENABLED MOBILE APP', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('EXEMatching: Cloud-Enabled Capstone Team Formation with Firebase, Google ARTEMIS & AI Code Review', style: pw.TextStyle(color: PdfColor.fromHex('#93C5FD'), fontSize: 11)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 1,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(color: lightBg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)), border: pw.Border.all(color: borderColor)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PROJECT METADATA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 6),
                      pw.Text('Team: DEVORGANIZE222', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('App: EXEMatching (Android)', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Firebase ID: prm393-lab-3-exematching', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Package: com.devorganize222.exematching', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Target SDK: Android 16 (API 36)', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Flutter SDK: 3.47.4 / Dart 3.13.3', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(color: lightBg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)), border: pw.Border.all(color: borderColor)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('EXECUTIVE SUMMARY', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 6),
                      pw.Text('This report documents the transformation of the Lab 2 Figma prototype into a cloud-enabled Android application powered by Google Firebase. The application adheres to strict Model-View-ViewModel (MVVM) architecture with Provider, enforces zero Firebase SDK calls from UI widgets, and verifies all 3 user flows end-to-end.', style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 4),
                      pw.Text('Key Deliverables: 10 production screens, 6 integrated Firebase cloud services, 10 privacy-compliant Analytics events, 13 automated E2E tests driven by Google ARTEMIS ($passedRuns/$totalRuns runs passed), and an AI code review with 5 findings across 3 categories.', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('1. PROJECT OVERVIEW & LAB 2 RECAP', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 6),
          pw.Text('• Persona: Minh Le, a senior Software Engineering student needing to form an official 4-5 member capstone team before the semester registration deadline.\n• Success Criterion: Students can find an open team matching their skills, elect a leader with hidden voting tallies, and the leader locks the roster, recovering from under-capacity via Waiting Pool automated invites.\n• Three Critical User Flows:\n  - Flow 1 (Discovery & Join): Browse teams with skill filters, view team details, join open role with capacity validation.\n  - Flow 2 (Leader Election): Members cast confidential votes; real-time tally reveals winner upon majority consensus.\n  - Flow 3 (Roster Finalization): Leader validates team conditions (4-5 members, supervisor, leader). If under-capacity, leader triggers automated invitations from Waiting Pool, then locks roster to generate official code.', style: const pw.TextStyle(fontSize: 8.5)),
          pw.Spacer(),
          buildFooter(1, 10),
        ],
      ),
    ),
  );

  // ==================== PAGE 2: DESIGN TRACEABILITY ====================
  pdf.addPage(
    pw.Page(
      pageTheme: pageTheme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader('2. DESIGN TRACEABILITY & SYSTEMATIC DEVIATIONS', 'Figma PRM_LAB2 (Page 03 Final UI) -> Flutter Code Mapping'),
          pw.Text('All 9 Figma screens plus an added Firebase Profile Screen have been implemented in Flutter with full state fidelity (Loading, Empty, Error, Data). Deviations are governed by the UX Writing Checklist (Bobbie Wood) and UI Consistency Checklist.', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Screen ID', 'Figma Node', 'Flutter Route', 'ViewModel', 'Data Source', 'States Verified'],
            data: [
              ['SCR_01', 'Sign In (FPT SSO)', '/sign-in', 'SignInViewModel', 'AuthService', 'Default, SigningIn, Cancelled, WrongDomain'],
              ['SCR_02', 'Dashboard / Home', '/home', 'DashboardViewModel', 'TeamRepo, RegService', 'Loading, InTeam, NoTeam, RegClosed, Error'],
              ['SCR_03', 'Browse Groups', '/browse', 'BrowseViewModel', 'TeamRepo, ConfigService', 'Loading, Results, Empty, OfflineError, Retry'],
              ['SCR_04', 'Group Detail', '/browse/team/:id', 'TeamDetailViewModel', 'TeamRepository', 'Loading, Default, Joining, FilledError, Member'],
              ['SCR_05', 'My Group Hub', '/team', 'MyTeamViewModel', 'TeamRepository', 'Loading, NoTeam, ElectLeader, ReadyLock, Locked'],
              ['SCR_06', 'Leader Voting', '/team/vote', 'VotingViewModel', 'TeamRepository', 'Loading, Unvoted(Hidden), Selected, Elected'],
              ['SCR_07', 'Lock & Recovery', '/team/lock', 'LockReviewViewModel', 'TeamRepository', 'Loading, Blocked(<4), Inviting, Recovered, Locked'],
              ['SCR_08', 'Random Pool', '/home/pool', 'PoolStatusViewModel', 'PoolRepository', 'Loading, Matching, QueueStatus, Error'],
              ['SCR_09', 'Alerts & Invites', '/alerts', 'NotificationsViewModel', 'NotificationRepo', 'Loading, List, Filtered, Empty, Decline+Undo'],
              ['Profile', 'Firebase Demo Area', '/profile', 'ProfileViewModel', 'Storage, Config, Crash', 'Default, PDF Exporting, Progress, URL, Crash'],
            ],
            headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Key Systematic Deviations & Technical Rationale:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 4),
          pw.Bullet(text: 'DV-01 (Terminology): Unified "Group" and "Team" to "Team" everywhere for cognitive clarity.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: 'DV-04 (Direct Join): In Figma, join sent an unhandled request; app joins directly upon open-slot validation.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: 'DV-05 (Actionable Errors): Changed vague "Ineligible to Lock" to front-loaded "Can\'t lock yet: needs 1 more member".', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: 'DV-08 (Profile / Demo Area): Repurposed top bar avatar to open Profile screen hosting all Firebase demo actions.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: 'DV-09/10 (WCAG Accessibility): Boosted warning text to #B4530A (5.7:1 contrast) and inputs to #737980 (>=3:1).', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Spacer(),
          buildFooter(2, 10),
        ],
      ),
    ),
  );

  // ==================== PAGE 3: ARCHITECTURE & MVVM ====================
  pdf.addPage(
    pw.Page(
      pageTheme: pageTheme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader('3. ARCHITECTURE & MVVM IMPLEMENTATION', 'Strict Layer Separation, State Modeling & Dependency Injection'),
          pw.Text('The codebase enforces unidirectional downward dependencies: UI (View) -> ViewModel -> Service Interface -> Concrete Firebase Implementations. No widget contains business logic or direct SDK imports.', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: lightBg, border: pw.Border.all(color: borderColor), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ARCHITECTURAL PRINCIPLES (Section 5 Compliance):', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.SizedBox(height: 4),
                pw.Text('1. Zero SDK Leakage: lib/screens/ and lib/widgets/ never import firebase_core, cloud_firestore, firebase_auth, or http. All external operations are encapsulated in lib/firebase/.', style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text('2. Composition Root: lib/app/providers.dart creates concrete singletons and binds them to abstract interfaces via Provider. Swapping cloud backends requires no UI changes.', style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text('3. Explicit State Modeling: Every data screen is governed by sealed class ViewState<T> (Loading, Empty, Failure, Data) with typed AppFailure payloads.', style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text('4. Atomic Mutations: Team mutations (join, leave, vote, lock, pool-invite) run within Firestore Transactions to guarantee concurrency safety.', style: const pw.TextStyle(fontSize: 7.5)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Directory Structure & Layer Boundaries:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Directory', 'Layer / Responsibility', 'Key Classes / Enforcements'],
            data: [
              ['lib/models/', 'Domain Data & State Model', 'Student, Team, Vote, AppNotification, ViewState<T>, AppFailure'],
              ['lib/theme/', 'Design Tokens & System', 'ColorScheme, AppColors, TextTheme, AppSpacing, AppRadius'],
              ['lib/widgets/', 'Reusable UI Components', 'AppButton, AppTextField, AppCard, AppDialog, LoadingState, ErrorState'],
              ['lib/services/', 'Abstract Service Contracts', 'AuthService, TeamRepository, NotificationRepository, ConfigService, StorageService'],
              ['lib/firebase/', 'Concrete Cloud Backends', 'FirebaseAuthService, FirestoreTeamRepository, FirebaseStorageService, FirebaseRemoteConfigService'],
              ['lib/viewmodels/', 'Presentation Logic & State', 'SignInViewModel, BrowseViewModel, TeamDetailViewModel, LockReviewViewModel'],
              ['lib/screens/', 'Pure Declarative Views', 'StatelessWidget / ConsumerWidget rendering ViewState<T>, zero SDK calls'],
              ['lib/app/', 'App Shell & Routing', 'go_router with auth redirects, providers.dart composition root'],
            ],
            headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
          ),
          pw.Spacer(),
          buildFooter(3, 10),
        ],
      ),
    ),
  );

  // ==================== PAGE 4: DESIGN SYSTEM IN CODE ====================
  pdf.addPage(
    pw.Page(
      pageTheme: pageTheme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader('4. DESIGN SYSTEM IN CODE & ACCESSIBILITY', 'Design Tokens, Reusable Widget Library & WCAG Validation'),
          pw.Text('All visual tokens originate from Figma PRM_LAB2 page 02 Design Tokens and are codified in lib/theme/. No hardcoded hex colors, font sizes, or paddings exist in application screens.', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(color: lightBg, border: pw.Border.all(color: borderColor), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('COLOR & TYPOGRAPHY TOKENS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 4),
                      pw.Text('• Primary: #0284C7 (FPT Navy Accent)\n• Success: #15803D (Verified / Locked)\n• Warning: #B4530A (Deadlines / Warnings)\n• Error: #B91C1C (Negative / Blocked)\n• Surface: #FFFFFF / Background: #F8FAFC\n• Type Scale: Roboto (12sp caption, 14sp body, 16sp title, 20sp headline, 26sp display)', style: const pw.TextStyle(fontSize: 7)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(color: lightBg, border: pw.Border.all(color: borderColor), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SPACING, RADIUS & ELEVATION', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 4),
                      pw.Text('• Spacing: AppSpacing.xs (4dp), sm (8dp), md (16dp), lg (24dp), xl (32dp)\n• Corner Radius: sm (4dp), md (8dp), lg (12dp), pill (999dp)\n• Elevation: AppElevation.none (0), card (1dp), dialog (4dp)\n• Min Touch Target: 48dp x 48dp minimum for all buttons and interactive chips', style: const pw.TextStyle(fontSize: 7)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text('Reusable Component Library (lib/widgets/):', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Component', 'File Location', 'Variants & States Supported', 'Accessibility Feature'],
            data: [
              ['AppButton', 'app_button.dart', 'Primary, Secondary, Destructive, Text x Default, Pressed, Loading, Disabled', '48dp target, Semantics button label'],
              ['AppTextField', 'app_text_field.dart', 'SearchField, InputField x Default, Focused, Filled, Error', 'High contrast outline, clear icon button'],
              ['AppCard', 'app_card.dart', 'Default, Outlined, SelectableCard (Radio check)', 'High contrast border, readable elevation'],
              ['State Widgets', 'states.dart', 'LoadingState (Skeleton/Spinner), EmptyState (Icon+Action), ErrorState (Retry)', 'Descriptive feedback, no spinner forever'],
              ['Status Indicators', 'status.dart', 'StatusBadge, InfoBanner, SlotRow, AppProgressBar', 'Icon + text (never color alone - WCAG 1.4.1)'],
            ],
            headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
          ),
          pw.Spacer(),
          buildFooter(4, 10),
        ],
      ),
    ),
  );

  // ==================== PAGE 5: FIREBASE INTEGRATION (AUTH, FIRESTORE, STORAGE) ====================
  pdf.addPage(
    pw.Page(
      pageTheme: pageTheme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader('5. CLOUD BACKEND DESIGN — FIREBASE SERVICES (PART 1)', 'Authentication, Cloud Firestore & Cloud Storage Architecture'),
          pw.Text('5.1. Firebase Authentication & Roster Authorization', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.Text('• Implementation: FirebaseAuthService utilizes Google Sign-In and creates Firebase credentials via GoogleAuthProvider.credential().\n• Session Stream: Listens to FirebaseAuth.instance.authStateChanges() and maps users to domain Student objects.\n• Centralized Roster Allowlist: To accommodate real university scenarios where students (K19+) use individual email accounts, authentication is validated against Firestore allowedEmails/{email}. Any authenticated Google account not present with enabled: true is rejected with "This account is not on the class roster".\n• Failure Handling: Graceful handling for cancelled sign-in, wrong domain, and offline network state.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 8),
          pw.Text('5.2. Cloud Firestore & Concurrency Safeguards', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.Text('• Implementation: FirestoreTeamRepository manages collections teams, waitingPool, and configuration.\n• Transaction Safety: Roster joins, leaves, votes, and lock operations execute in runTransaction. If another user fills a team or casts a vote concurrently, the transaction aborts and retries safely.\n• Waiting Pool Recovery: In Flow 3, inviteFromPool queries candidate documents, verifies assigned == false within the transaction, appends the member, and atomically marks assigned: true.\n• Security Rules (firebase/firestore.rules): Strictly enforces isRosterMember() and limits updates to 8 whitelisted roster fields (GR-01 fix). No student can modify team metadata (supervisor, capacity, topic).', style: const pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 8),
          pw.Text('5.3. Firebase Cloud Storage & User Isolation', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.Text('• Implementation: FirebaseStorageService generates team confirmation summary PDFs and uploads them to reports/{uid}/{fileName}.\n• Progress & URL: Emits UploadProgress stream tracking byte transfer percentage (0% to 100%), then retrieves signed download URL.\n• Security Rules (firebase/storage.rules): Grants read/write exclusively to request.auth != null && request.auth.uid == userId. Cross-user access is strictly forbidden by server rules.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Spacer(),
          buildFooter(5, 10),
        ],
      ),
    ),
  );

  // ==================== PAGE 6: FIREBASE INTEGRATION (FCM, ANALYTICS, CRASHLYTICS, CONFIG) ====================
  pdf.addPage(
    pw.Page(
      pageTheme: pageTheme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader('6. CLOUD BACKEND DESIGN — FIREBASE SERVICES (PART 2)', 'Cloud Messaging (FCM), Crashlytics, Remote Config & Analytics Plan'),
          pw.Text('6.1. Firebase Cloud Messaging (FCM) Across 3 App States', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.Text('• Permission: Automatically requests POST_NOTIFICATIONS consent on Android 13+ devices.\n• Three Lifecycle States:\n  1. Foreground: onMessage captures notifications and persists them directly into the Alerts inbox.\n  2. Background: onBackgroundMessage runs isolated handler in main.dart writing directly to Firestore students/{uid}/notifications.\n  3. Terminated: getInitialMessage launches the app and onMessageOpenedApp navigates to /browse/team/{teamId}.\n• Deep Linking: Tapping a notification with teamId payload navigates directly to the relevant Team Detail screen.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 8),
          pw.Text('6.2. Firebase Crashlytics & Diagnostic Telemetry', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.Text('• Fatal Errors: FlutterError.onError and PlatformDispatcher.instance.onError forward unhandled engine errors to Crashlytics.\n• Handled Non-Fatal: ProfileViewModel.sendNonFatal simulates failed network lookups, with custom keys screen=profile and student_cohort (set at sign-in with the user ID; empty when the student profile has no cohort); team_id is set on team screens.\n• Test Crash Action: Dedicated Profile button invokes FirebaseCrashlytics.instance.crash() for live verification.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 8),
          pw.Text('6.3. Firebase Remote Config & Zero-Rebuild Realtime Updates', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.Text('• In-App Defaults: ConfigKeys.defaults defines max_team_members=5, enable_waiting_pool=true, registration_closed=false.\n• Real-Time Synchronization: onConfigUpdated automatically activates published values and emits through changes stream.\n• Runtime change without reinstalling: publishing registration_closed=true in the Console switches Home to the closed banner and, while enable_waiting_pool is true, shows the Waiting Pool entry for students without a team.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 8),
          pw.Text('6.4. Google Analytics Event Plan (Privacy-by-Design)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.Text('Tracks 10 events (login, logout, search_teams, view_team, create_team, join_team, cast_vote, invite_pool, lock_roster, export_report). Parameters carry IDs and counts only: search_teams sends query_length, never the search text. Every E2E run saves the events it caused from Logcat (analytics.txt); login with setUserId, search_teams and cast_vote are also shown in DebugView (evidence/debugview/).', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Spacer(),
          buildFooter(6, 10),
        ],
      ),
    ),
  );

  // ==================== PAGE 7: ARTEMIS E2E AUTOMATION ====================
  pdf.addPage(
    pw.Page(
      pageTheme: pageTheme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader('7. AUTOMATED E2E TESTING WITH GOOGLE ARTEMIS', '13 Test Cases, 3-Run Reliability Benchmark & Ground-Truth Assertions'),
          pw.Text('Google ARTEMIS is an open-source AI agent that navigates the real Android app using multimodal models. The suite in e2e_test/ uses pytest-asyncio and asserts on the Semantics accessibility tree and Logcat rather than status=="SUCCESS".', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Case ID', 'Flow Tested', 'Goal & Natural-Language Instruction', '3-Run Pass', 'Avg ARTEMIS time'],
            data: [
              ['TC-01', 'Auth / Error', 'Sign in with unauthorized account -> Verify error banner', passCell('TC-01'), timeCell('TC-01')],
              ['TC-02', 'Auth / Success', 'Sign in with roster account -> Verify Home greetings & deadline', passCell('TC-02'), timeCell('TC-02')],
              ['TC-03', 'Flow 1 / Search', 'Browse tab -> Filter AI/ML & Open Slots -> Search "drone"', passCell('TC-03'), timeCell('TC-03')],
              ['TC-04', 'Flow 1 / Empty', 'Search non-existent term -> Verify empty state -> Clear filters', passCell('TC-04'), timeCell('TC-04')],
              ['TC-05', 'Flow 1 / Offline', 'Disable network via ADB -> Observe error -> Reconnect & retry', passCell('TC-05'), timeCell('TC-05')],
              ['TC-06', 'Flow 1 / Join', 'Find FinTech Guard -> Join Team -> confirm -> My Team shows 3 of 5', passCell('TC-06'), timeCell('TC-06')],
              ['TC-07', 'Flow 1 / Filled', 'Open team -> Concurrently fill team -> Verify filled banner', passCell('TC-07'), timeCell('TC-07')],
              ['TC-08', 'Flow 2 / Voting', 'Leader voting -> Verify tallies hidden before casting vote', passCell('TC-08'), timeCell('TC-08')],
              ['TC-09', 'Flow 2 / Elect', 'Vote for yourself -> Submit -> Verify elected banner & Firestore', passCell('TC-09'), timeCell('TC-09')],
              ['TC-10', 'Flow 3 / Lock', 'Lock blocked (<4) -> Invite from pool -> Recover & lock', passCell('TC-10'), timeCell('TC-10')],
              ['TC-11', 'Flow 3 / Native', 'Tap Share Team Link -> Verify Android Share Sheet intent', passCell('TC-11'), timeCell('TC-11')],
              ['TC-12', 'Alerts / Undo', 'Decline team invite -> Click Undo in snackbar -> Restore card', passCell('TC-12'), timeCell('TC-12')],
              ['TC-13', 'Profile / Export', 'Export & Upload Team PDF -> Verify progress & Storage URL', passCell('TC-13'), timeCell('TC-13')],
            ],
            headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Result: $passedRuns of $totalRuns runs passed. Failed runs and their causes (including Gemini free-tier quota exhaustion) are listed per trace ID in docs/test-plan.md section 3.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 6),
          pw.Text('Exploratory Testing Session (ARTEMIS Pro profile):', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.Text(exploratory.existsSync() ? exploratory.readAsStringSync().trim() : 'Not run yet. See docs/test-plan.md section 4.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Spacer(),
          buildFooter(7, 10),
        ],
      ),
    ),
  );

  // ==================== PAGE 8: AI-ASSISTED CODE REVIEW ====================
  pdf.addPage(
    pw.Page(
      pageTheme: pageTheme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader('8. AI-ASSISTED CODE REVIEW & AUDITABLE DECISIONS', 'Pull Request #8 Code Review via Google Gemini (gemini-3.5-flash-lite)'),
          pw.Text('The team configured an automated GitHub Actions workflow (.github/workflows/gemini-review.yml) that submits pull request diffs to Google Gemini. 5 findings across 3 categories were recorded with rigorous technical decisions.', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['ID', 'Category · Severity', 'Location', 'Gemini Finding Summary', 'Decision', 'Commit'],
            data: [
              ['GR-01', 'Security · High', 'firestore.rules:57', 'isSelfJoin only checks roster size, allowing malicious modification of team metadata (supervisor, capacity).', 'Accepted (Widened to all 5 team mutations)', 'c9543a3'],
              ['GR-02', 'Concurrency · Med', 'firestore_team_repo:269', 'Querying waiting pool outside transaction could cause 2 teams to target the same student.', 'Rejected (In-transaction re-read & atomic assignment prevent race)', '—'],
              ['GR-03', 'Reliability · Med', 'backend.py:42', 'Missing Firebase CLI login raises bare KeyError instead of actionable guidance.', 'Accepted (Provides explicit firebase login instruction)', 'ee6ec78'],
              ['GR-04', 'Reliability · Low', 'remote_config_svc:24', 'Catch block suppresses Remote Config startup fetch error message.', 'Accepted (Adjusted to log error and continue with in-app defaults)', 'd6926d1'],
              ['GR-05', 'Reliability · Med', 'gemini_review.py:61', 'Slicing error body to 2000 chars might split UTF-8 multi-byte characters.', 'Rejected (False positive: decode occurs before string slicing)', '—'],
            ],
            headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Detailed Analysis of Key Review Findings:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 4),
          pw.Text('• GR-01 (Crucial Security Fix): Demonstrated that AI review excels at spotting authorization boundary gaps. The fix strictly enforces after.diff(before).affectedKeys().hasOnly([...]) across all 5 team mutation types.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Text('• GR-02 (Critical Human Judgment): Rejecting GR-02 proved that engineers must not blindly trust AI suggestions. Firestore Client SDK does not support queries inside transactions; re-reading the candidate document with tx.get() inside the transaction is the canonical architectural solution.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Spacer(),
          buildFooter(8, 10),
        ],
      ),
    ),
  );

  // ==================== PAGE 9: VERIFICATION EVIDENCE MATRIX ====================
  pdf.addPage(
    pw.Page(
      pageTheme: pageTheme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader('9. VERIFICATION EVIDENCE MATRIX & CONSOLE PROOF', 'Comprehensive Artifacts Linking Requirements to Verifiable Evidence'),
          pw.Text('Each row is marked VERIFIED only when its screenshots or files exist in the repository at the time this PDF is generated.', style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Requirement', 'Console / Device Evidence', 'Repository Location', 'Verification Status'],
            data: [
              ['Google Sign-In', 'Authentication Users tab with the Google-provider accounts and UIDs', 'evidence/console/console_auth_users.jpg', status(['evidence/console/console_auth_users.jpg'])],
              ['Firestore Roster & Rules', 'allowedEmails roster, deployed team and waitingPool rules', 'evidence/console/', status(['evidence/console/console_firestore_allowed_emails.jpg', 'evidence/console/console_firestore_rules_teams.jpg', 'evidence/console/console_firestore_rules_waiting_pool.jpg'])],
              ['Storage Isolation', 'reports/{uid}/ PDFs uploaded by the app and the deployed storage.rules', 'evidence/console/', status(['evidence/console/console_storage_files.jpg', 'evidence/console/console_storage_rules.jpg'])],
              ['FCM 3 States', 'Test message received in foreground, background and terminated states', 'evidence/fcm/', status(fcmShots)],
              ['Analytics DebugView', 'login with user ID, search_teams and cast_vote with their parameters', 'evidence/debugview/', status(debugViewShots)],
              ['Crashlytics Reports', 'Crash dashboard and a non-fatal issue with keys screen and student_cohort', 'evidence/crashlytics/', status(crashShots)],
              ['Remote Config', 'App before, value published in Console, app after without reinstalling', 'evidence/remote_config/', status(remoteConfigShots)],
              ['ARTEMIS E2E', 'JUnit XML, per-run result.json, final screenshot, screen text, Logcat events ($passedRuns/$totalRuns runs passed)', 'e2e_test/evidence/', status(['e2e_test/evidence/junit.xml'])],
              ['AI Code Review', 'Pull request #8 review comments, docs/code-review.md, 3 fix commits', 'docs/code-review.md', status(['docs/code-review.md'])],
              ['Design Traceability', 'Figma frames next to app screenshots, deviations with reasons', 'docs/design-traceability.md', status(['docs/design-traceability.md'])],
            ],
            headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
          ),
          pw.SizedBox(height: 10),
          pw.Text('10. CHALLENGES ENCOUNTERED & LESSONS LEARNED', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 4),
          pw.Text('1. Cross-Service Storage Rules: Initially attempted to validate user team membership inside storage.rules using firestore.get(). This caused HTTP 403 errors because Firebase Storage does not support cross-service Firestore lookups. Fixed by scoping rules directly to authenticated UID: reports/{userId}/{allPaths=**}.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Text('2. AI Review Quota Throttling: Multi-turn agentic review tools exhausted Gemini API quotas. Solved by engineering a single-request script (.github/scripts/gemini_review.py) that transmits the entire git diff in one structured prompt.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Text('3. Asynchronous Provider Lifecycle: Fixed a subtle bug where notifyListeners() was called on SignInViewModel after being unmounted during async Google sign-in transitions.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Spacer(),
          buildFooter(9, 10),
        ],
      ),
    ),
  );

  // ==================== PAGE 10: DISCLOSURE OF AI TOOLS & CONCLUSION ====================
  pdf.addPage(
    pw.Page(
      pageTheme: pageTheme(),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildHeader('10. DISCLOSURE OF AI TOOLS & SUBMISSION CHECKLIST', 'Academic Integrity Statement & Final Verification'),
          pw.Text('10.1. Disclosure of AI Tools Used (Handout Section 10 Compliance)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['AI Tool / Service', 'Model / Version', 'Purpose in Project', 'Human Review & Verification'],
            data: [
              ['Google Gemini (CLI/Actions)', 'gemini-3.5-flash-lite', 'Pull Request #8 automated code review', 'All 5 findings evaluated manually; 3 accepted, 2 rejected'],
              ['Google ARTEMIS', 'Commit 351ca84, Flash & Pro Profile', 'E2E automated test execution & exploratory testing', 'Device assertions verified via Semantics tree & Logcat'],
              ['Antigravity / Claude', 'Claude Opus 5.5 / Gemini 3.8 Flash', 'Pair programming, MVVM architecture & report drafting', 'Code reviewed line-by-line; tested on Android API 36 emulator'],
            ],
            headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: primaryColor),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
          ),
          pw.SizedBox(height: 12),
          pw.Text('10.2. Final Submission Checklist & Verification', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 4),
          pw.Bullet(text: '[ ] Submission repository name PRM393_Lab03_<StudentID>: the GitHub repository is still DEVORGANIZE222/Lab3_Cloud-Enabled_Mobile_App.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: '[x] MVVM layering enforced: Zero Firebase SDK imports in lib/screens/ or lib/widgets/.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: '[x] All 6 Firebase cloud services operational with explicit failure and offline handling.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: '[x] Storage rules enforce strict per-user UID isolation (no public allow read, write: if true).', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: '${check(debugViewShots)} Analytics event plan implemented with 10 events, shown in DebugView, no PII in parameters.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: '${check(fcmShots)} FCM test message received in foreground, background and terminated states.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: '${check(crashShots)} Crashlytics reports both deliberate test crash and non-fatal error with custom keys.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: '${check(remoteConfigShots)} Remote Config updates the UI at runtime without reinstalling the APK.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: '[x] ARTEMIS E2E suite covers 13 test cases x 3 runs: $passedRuns/$totalRuns runs passed.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: '${exploratory.existsSync() ? '[x]' : '[ ]'} ARTEMIS Pro exploratory session recorded in docs/test-plan.md section 4.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: '[x] AI Code Review on PR #8 documented with 5 findings and 3 traceable fix commits.', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Bullet(text: '[x] Final Report PDF and presentation slides generated (PDF, plus an editable PPTX for Canva or PowerPoint).', style: const pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: lightBg, border: pw.Border.all(color: primaryColor), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Center(
              child: pw.Text('END OF REPORT — DEVORGANIZE222 — PRM393 LAB 3', style: pw.TextStyle(color: primaryColor, fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ),
          ),
          pw.Spacer(),
          buildFooter(10, 10),
        ],
      ),
    ),
  );

  final outputFile = File('report/Final_DEVORGANIZE222.pdf');
  await outputFile.parent.create(recursive: true);
  final bytes = await pdf.save();
  await outputFile.writeAsBytes(bytes);
  final legacyOutput = File('report/Lab03_DEVORGANIZE222.pdf');
  await legacyOutput.writeAsBytes(bytes);
  print('Successfully generated Final Report: ${outputFile.path} (${await outputFile.length()} bytes)');
}

