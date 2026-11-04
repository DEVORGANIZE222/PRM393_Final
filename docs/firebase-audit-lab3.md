# Firebase implementation audit - PRM393 Lab 3

**Audit date:** 26 October 2026 (UTC+07:00)  
**Scope:** source tree, local configuration, repository state, existing E2E evidence, a read-only Firebase Console inspection, and local build tooling.  
**Change policy:** no production Firebase resource, Security Rule, billing setting, or implementation source was changed by this audit. This file is the sole audit artifact created.

## Status vocabulary

| Status | Meaning |
|---|---|
| **IMPLEMENTED** | Source code exists and is wired into the current composition root. |
| **CONFIGURED** | A local or Console configuration was directly observed. |
| **VERIFIED** | Reproducible runtime/Console evidence exists for the current Firebase implementation. |
| **PARTIAL** | Some required behaviour exists, but a material required part is absent or unsafe. |
| **NOT VERIFIED** | Code/configuration exists but no current runtime or Console proof was available. |
| **FAILED** | The audit directly observed a failing check. |
| **NOT IMPLEMENTED** | No implementation was found. |

## 1. Executive summary

The project has a substantial Firebase implementation in `lib/firebase/`, and the production Provider composition root selects those implementations. Android package configuration is internally consistent and a debug APK previously built successfully in this workspace. However, the Firebase portion cannot yet be rated ready for a Lab 3 demo or submission.

The blocking issues are:

1. **P0 - Firestore data is incomplete.** The directly observed `configuration/registration` document has only `semester: "Fall 2026"`; it lacks the required `opensAt` and `closesAt` Timestamps. [`firebase_pool_repository.dart`](../lib/firebase/firebase_pool_repository.dart#L40) now hides this with device-time fallback values, so it is not a valid real-data configuration.
2. **P0 - Firestore team authorization is unsafe.** [`firebase/firestore.rules`](../firebase/firestore.rules#L11) permits *any* authenticated account to update *any* team document. A client transaction is not server-side authorization.
3. **P0 - Restored Firebase sessions are not observed.** [`FirebaseAuthService.authStateChanges`](../lib/firebase/firebase_auth_service.dart#L34) only emits its in-memory `_currentStudent`; it does not subscribe to `FirebaseAuth.authStateChanges()`. Cold launch/session restore cannot be relied upon.
4. **P0 - Required Console evidence is absent.** No current evidence was found for Google sign-in, Storage upload, all three FCM states, Analytics DebugView, Crashlytics, or Remote Config before/after behaviour.
5. **P1 - Lab workflow and evidence are incomplete.** `flutter test` cannot run because the `test/` directory does not exist. Existing ARTEMIS evidence explicitly describes the old seeded/local implementation, and only five of thirteen cases have result files.

The original Lab 3 PDF at `C:\Users\Admin\Downloads\PRM393 - Lab 3 Cloud-Enabled Mobile App (Firebase, Patrol, AI Code Review).pdf` was read and used as the requirements baseline.

## 2. Project configuration

| Check | Status | Evidence / conclusion |
|---|---|---|
| Firebase project and Android package | **CONFIGURED** | `android/app/google-services.json` declares project `prm393-lab-3-exematching` and package `com.devorganize222.exematching`; [`android/app/build.gradle.kts`](../android/app/build.gradle.kts#L14) uses the same `applicationId`. |
| Android Firebase plugins | **IMPLEMENTED** | Google Services and Crashlytics plugins are applied in [`android/app/build.gradle.kts`](../android/app/build.gradle.kts#L1) and declared in [`android/settings.gradle.kts`](../android/settings.gradle.kts#L20). |
| Firebase initialization | **IMPLEMENTED** | [`main.dart`](../lib/main.dart#L37) calls `WidgetsFlutterBinding.ensureInitialized()` then `Firebase.initializeApp()` before building providers. Android can use the native `google-services.json`. |
| FlutterFire CLI / generated options | **FAILED** | `flutterfire` executable is not installed; `lib/firebase_options.dart`, `.firebaserc`, and `firebase.json` are absent. The app is Android-only native-configured, not FlutterFire-CLI configured. |
| Dependency resolution / compatibility | **PARTIAL** | `flutter pub get` exited 0 with Firebase packages resolved. It reported 41 newer incompatible-to-current-constraints packages; this is not a build failure. The debug APK built earlier in this workspace with exit 0, but Gradle warned that plugin KGP compatibility will fail in a future Flutter release. |
| SHA-1/SHA-256 and Google provider | **NOT VERIFIED** | This audit did not obtain a Console page proving registered fingerprints or an enabled Google provider. |
| Secret exposure | **PARTIAL** | A repository scan found the Android client API key in `google-services.json`; this is normal Firebase Android configuration and the PDF permits committing the file. No service-account private key, keystore, or `BEGIN PRIVATE KEY` was found. The file is currently untracked, so commit/review policy is still needed. |

## 3. Firebase services audit

### A. Authentication

| Requirement | Status | Evidence |
|---|---|---|
| Google account picker and Firebase credential sign-in | **IMPLEMENTED** | [`FirebaseAuthService.signInWithGoogle`](../lib/firebase/firebase_auth_service.dart#L43) uses `GoogleSignIn`, validates `@fpt.edu.vn`, creates a `GoogleAuthProvider` credential, then calls `FirebaseAuth.signInWithCredential`. |
| Wrong-domain and cancelled sign-in handling | **IMPLEMENTED** | Lines 44-49 throw `SignInCancelled` and `WrongDomain`. Existing old ARTEMIS files record three wrong-domain cases, but they are not proof of the current Firebase build. |
| Firebase UID use | **IMPLEMENTED** | UID is used for `students/{uid}`, notification documents, Storage paths, and the domain model; see lines 56-80 and [`firebase_storage_service.dart`](../lib/firebase/firebase_storage_service.dart#L14). |
| Auth-state routing | **PARTIAL** | Router redirects signed-out users at [`router.dart`](../lib/app/router.dart#L42), but the service does not listen to Firebase's auth-state stream. It therefore only knows a user after its own sign-in call. |
| Sign-out clears Firebase/Google session | **IMPLEMENTED** | [`firebase_auth_service.dart`](../lib/firebase/firebase_auth_service.dart#L85) signs out of Google and Firebase and clears in-memory student state. Local persisted-user data is not used by this implementation. |
| Google Sign-In on real Android | **NOT VERIFIED** | No current Android device was connected during audit and no Console Users-tab evidence was captured. |

### B. Cloud Firestore and data integration

**Implementation:** the app uses Cloud Firestore SDK only; no REST data client was found. The production bindings are in [`providers.dart`](../lib/app/providers.dart#L29): `FirestoreTeamRepository`, `FirebaseRegistrationService`, `FirebasePoolRepository`, and `FirebaseNotificationRepository`.

| Area | Status | Evidence |
|---|---|---|
| Team reads, streams, joins/leaves/votes/lock | **IMPLEMENTED** | [`firestore_team_repository.dart`](../lib/firebase/firestore_team_repository.dart#L83) has query/read/watch methods and transactions for join, leave, vote, and lock. |
| Notification inbox CRUD | **IMPLEMENTED** | [`firebase_notification_repository.dart`](../lib/firebase/firebase_notification_repository.dart#L35) streams, marks read, batch-marks, deletes and restores `students/{uid}/notifications`. |
| Real configuration document | **FAILED** | Direct read-only Console inspection on 26 Oct shows only `semester: "Fall 2026"` in `configuration/registration`, with no `opensAt` / `closesAt`. |
| Registration data failure handling | **PARTIAL** | Missing document produces `AppFailure`; missing timestamps now produce device-time defaults at lines 55-63 instead of a typed Firestore configuration. This avoids a crash but violates the PDF requirement for real submitted-build data. |
| Waiting-pool invitation | **PARTIAL** | [`inviteFromPool`](../lib/firebase/firestore_team_repository.dart#L233) only increments `invitesSent`; it does not select a pool student, create an invitation, or update pool records. |
| Loading / empty / error / retry | **PARTIAL** | ViewModels and reusable state widgets exist, but live permission-denied/offline Firestore paths were not run in this audit. |
| Indexes | **NOT VERIFIED** | No `firestore.indexes.json` or Console index evidence exists. Current queries may work without composite indexes, but this has not been verified against populated production data. |

### C. Cloud Storage

| Requirement | Status | Evidence |
|---|---|---|
| Per-user upload path | **IMPLEMENTED** | [`firebase_storage_service.dart`](../lib/firebase/firebase_storage_service.dart#L14) uploads to `reports/$uid/<filename>`. |
| PDF content type, progress, URL | **IMPLEMENTED** | Lines 16-20 set `application/pdf`, stream task progress, and return `getDownloadURL()`. UI displays progress and URL at [`profile_screen.dart`](../lib/screens/profile/profile_screen.dart#L186). |
| Rule source | **IMPLEMENTED** | [`storage.rules`](../firebase/storage.rules#L8) scopes read/write to authenticated `reports/{userId}/...` matching `request.auth.uid`. |
| Bucket, deployed rule, real upload | **NOT VERIFIED** | This audit did not capture a current bucket/file-list or deployed Storage rules. Existing `TC-13` files report uploads but the test plan identifies old seeded/local data; they cannot prove the current Firebase implementation. |
| Billing condition | **NOT VERIFIED** | No durable audit evidence records the current billing/bucket eligibility. |

### D. Cloud Messaging (FCM)

| Requirement | Status | Evidence |
|---|---|---|
| Android 13 notification permission | **IMPLEMENTED** | Manifest declares `POST_NOTIFICATIONS`; service calls `requestPermission()` at [`firebase_messaging_service.dart`](../lib/firebase/firebase_messaging_service.dart#L13). |
| Token and refresh handling | **IMPLEMENTED** | Lines 16-17 save `fcmToken` and subscribe to `onTokenRefresh`. |
| Foreground / opened / terminated persistence | **PARTIAL** | `onMessage`, `onMessageOpenedApp`, and `getInitialMessage()` persist messages (lines 18-21); background handler is registered in [`main.dart`](../lib/main.dart#L16). No navigation from a notification tap to the team-detail route is implemented. |
| Permission-denied UX, duplicate policy, all three state tests | **NOT IMPLEMENTED / NOT VERIFIED** | Permission denial silently returns; there is no explicit user message. No explicit duplicate policy is defined. No console test-message evidence was found for foreground, background, or terminated states. |

### E. Analytics

**IMPLEMENTED:** [`FirebaseAnalyticsService`](../lib/firebase/firebase_analytics_service.dart#L6) registers nine events and [`analytics-plan.md`](analytics-plan.md#L6) names the same plan:

`login`, `logout`, `search_teams`, `view_team`, `join_team`, `cast_vote`, `invite_pool`, `lock_roster`, and `export_report` (nine named events; the service interface includes these nine methods). Parameters use lengths, IDs/codes, counts, booleans, and file size; no email, name, student code, notification body, or PDF URL is sent by this service.

| Requirement | Status | Evidence |
|---|---|---|
| At least seven events and user ID | **IMPLEMENTED** | Event calls above; [`session_viewmodel.dart`](../lib/viewmodels/session_viewmodel.dart#L28) sets Analytics user ID on state change. |
| DebugView proof for every event | **NOT VERIFIED** | No DebugView screenshot or Console record was found. Local ARTEMIS `analytics.txt` is not Firebase Analytics DebugView evidence. |

### F. Crashlytics

| Requirement | Status | Evidence |
|---|---|---|
| Fatal Flutter/platform errors | **IMPLEMENTED** | [`main.dart`](../lib/main.dart#L41) forwards framework and platform errors to Crashlytics. |
| Non-fatal real error path and keys | **IMPLEMENTED** | [`ProfileViewModel.sendNonFatal`](../lib/viewmodels/profile_viewmodel.dart#L127) deliberately follows a failed missing-team lookup and sets `screen=profile`; session sets user ID and cohort key. |
| Test crash action | **IMPLEMENTED** | [`FirebaseCrashReporter.testCrash`](../lib/firebase/firebase_crash_reporter.dart#L26) invokes `.crash()`, exposed by [`profile_screen.dart`](../lib/screens/profile/profile_screen.dart#L132). |
| Console evidence of non-fatal and fatal reports | **NOT VERIFIED** | No Crashlytics dashboard evidence exists. |

### G. Remote Config

| Requirement | Status | Evidence |
|---|---|---|
| In-app defaults | **IMPLEMENTED** | [`ConfigKeys.defaults`](../lib/services/services.dart#L119) and [`FirebaseRemoteConfigService.initialize`](../lib/firebase/firebase_remote_config_service.dart#L14) set defaults before fetch. |
| Parameters / visible behaviour | **PARTIAL** | `max_team_members` influences fallback capacity; `enable_waiting_pool` controls Dashboard pool entry. Profile also renders values. `registration_closed` is in Dart but missing from [`remote-config-defaults.json`](../firebase/remote-config-defaults.json), creating a source/config mismatch. |
| Fetch failure handling | **FAILED** | `initialize()` awaits `refresh()` without catch. A fetch exception can prevent `AppServices.create()` and app launch; no visible fallback error path is demonstrated. |
| Console change without rebuild | **NOT VERIFIED** | Code subscribes to real-time updates and has a manual refresh, but no before/after Console evidence exists. |

## 4. Security review

| Finding | Severity | Evidence / impact |
|---|---|---|
| Any signed-in user can modify every team document | **Critical** | [`firestore.rules`](../firebase/firestore.rules#L11) says `allow update: if request.auth != null`. It permits forged membership, votes, leaders, lock codes, and locked state. Client transactions do not secure the backend. |
| Rules deployment not independently proven | **High** | Rule source is present, but the Console rules editor did not provide readable deployed text during this audit. Do not equate repository files with deployment. |
| Student and Storage UID scoping | **Good in source** | Student docs and Storage paths are UID-scoped in rules. Deployment and runtime denial tests remain unverified. |
| Sensitive configuration | **Low** | No service account/private key found. Android Firebase API key is present and expected; restrict it in Google Cloud Console and rely on rules/App Check rather than treating it as a secret. |

## 5. Architecture and integration review

**Strengths:** The Provider composition root injects service interfaces into ViewModels. No screen/widget direct Firebase SDK reference was found by the audit search. Firebase SDK calls are concentrated in `lib/firebase/` and the application bootstrap/background handler.

**Exceptions and dependencies:**

- The background FCM handler calls `FirebaseFirestore.instance` directly in [`main.dart`](../lib/main.dart#L21). This is reasonable background-isolate bootstrap code but is technically outside the stated service-only rule and should be documented/encapsulated.
- Existing documents still describe local implementations as the active runtime: [`README.md`](../README.md#L18), [`architecture.md`](architecture.md#L19), and [`design-traceability.md`](design-traceability.md#L7). This contradicts current [`providers.dart`](../lib/app/providers.dart#L29), which selects Firebase implementations.
- All Firebase changes are uncommitted: `git status --short` reports 21 modified tracked files plus five untracked Firebase-related artifacts. Git history therefore does not yet evidence the required staged implementation or review/fix commits for the Firebase work.

## 6. Commands executed and results

| Command | Result |
|---|---|
| `flutter pub get` | **exit 0**. Dependencies resolved. Output warned that 41 packages have newer incompatible-to-current constraints. |
| `flutter analyze --no-pub` | **exit 0**: `No issues found! (ran in 29.5s)`. |
| `flutter test` | **exit 1**: `Test directory "test" not found.` |
| `flutter build apk --debug` | **exit 0** in this workspace before the audit; APK produced at `build/app/outputs/flutter-apk/app-debug.apk`. Gradle emitted a future Kotlin-plugin compatibility warning. |
| `adb devices` | **not testable in current audit**: no emulator/device attached. |
| Firebase/FlutterFire CLI check | `firebase`, `flutterfire`, `.firebaserc`, `firebase.json`, and emulator config absent. |
| Secret scan | No service-account/private-key pattern found; expected Android API key found in `google-services.json`. |

No Firebase Emulator test was run because no Firebase CLI or emulator configuration is present. No ARTEMIS suite was re-run because it requires the absent connected device and configured external model credentials.

## 7. Lab 3 requirement compliance matrix

| Requirement | Status | Code evidence | Runtime evidence | Missing work | Owner / dependency |
|---|---|---|---|---|---|
| MVVM + injected services | **PARTIAL** | `providers.dart`, ViewModels, service interfaces | Static analysis only | Document background-handler exception; update stale docs | Firebase + Flutter architecture owner |
| Google Sign-In and state routing | **PARTIAL** | `firebase_auth_service.dart`, `router.dart` | No current device test | Observe Firebase auth state; prove SHA/provider and Android login/logout | Firebase Console + Android tester |
| Real Firestore data | **FAILED** | Firestore repositories | Console proves incomplete registration doc | Seed/maintain valid docs; remove runtime fallback before submission | Data/Firebase owner |
| Safe Firestore rules | **FAILED** | `firebase/firestore.rules` | Deployment not proven | Role/member-aware validation or trusted backend | Firebase/security owner |
| PDF export and per-user Storage | **PARTIAL** | storage service and profile VM | Old local E2E evidence only | Real authenticated upload and rule-denial proof | Firebase + Android tester |
| FCM all lifecycle states | **PARTIAL** | messaging service/background handler | None | Navigation, denial UI, console test messages in 3 states | Firebase + UI owner |
| Analytics plan, >=7 events, DebugView | **PARTIAL** | analytics service/plan | No DebugView | Verify every event on current Firebase build | Firebase tester |
| Crashlytics non-fatal and fatal | **PARTIAL** | reporter, profile diagnostics | No Console dashboard | Trigger both and capture dashboard keys/user ID | Firebase tester |
| Remote Config 2 visible values | **PARTIAL** | config service, dashboard/profile | No before/after | Align defaults, handle fetch failure, publish and demonstrate | Firebase + UI owner |
| Automated tests / 3 runs | **FAILED** | E2E source and partial artifacts | 5 cases have old evidence; test plan says results pending | Run all 13 cases x3 against current Firebase build; add Dart tests | QA owner |
| Code review / staged commits | **PARTIAL** | `docs/code-review.md` | Existing document | Commit current Firebase changes and update review evidence | Team owner |

## 8. Critical bugs and missing features

### P0 - fix before Firebase demo

1. Replace permissive `teams` rule with validated member/leader/field-change authorization and prove denial with Rules Emulator or Console Rules playground.
2. Populate `configuration/registration` with a real semester plus valid `opensAt` and `closesAt` server Timestamps; remove the device-time fallback for the submitted build.
3. Subscribe to `FirebaseAuth.authStateChanges()` (and map a restored Firebase user to a `Student`) so routing works after app restart.
4. Prove Google provider/fingerprint setup and execute sign-in/sign-out on the configured Android app.

### P1 - required evidence/behaviour

1. Test Storage upload and cross-user-denial, FCM foreground/background/terminated, Analytics DebugView, Crashlytics non-fatal/fatal, and Remote Config before/after values.
2. Implement notification-tap route navigation and permission-denied feedback.
3. Catch Remote Config fetch errors and allow default-config startup.
4. Align `remote-config-defaults.json` with Dart keys, especially `registration_closed`.
5. Replace the placeholder waiting-pool invite counter with real invite/pool mutation logic, or remove the claimed workflow.

### P2 - process and maintainability

1. Run FlutterFire CLI and commit generated `firebase_options.dart`, or formally document Android-only native initialization.
2. Update README, architecture, and traceability documents to reflect Firebase as the current provider rather than a future teammate task.
3. Add unit/widget tests under `test/`; run and preserve E2E evidence for the current Firebase build.
4. Commit work in required logical stages and preserve review/test evidence.

## 9. Dependencies on other team members

| Dependency | Why it blocks completion |
|---|---|
| Firebase project owner | Needs to confirm Google provider/SHA, deploy secure Firestore/Storage rules, maintain real data, and capture Console evidence. |
| Flutter/UI owner | Needs notification-tap navigation, permission/fetch-failure messages, and alignment of visible Remote Config behaviours with the screens. |
| Data/business-rule owner | Must define valid team membership/leader role model and waiting-pool/invite schema so rules can enforce it. |
| QA/ARTEMIS owner | Must run all test cases three times on the current Firebase build with a dedicated test account and retain results. |

## 10. Prioritized next actions

| Priority | Action | Estimate | Verification |
|---|---|---:|---|
| P0 | Design and deploy secure `teams` authorization rules; test owner/member/attacker cases | 2-4 h | Rules Emulator/Rules playground screenshots plus real app flow |
| P0 | Seed required Firestore configuration and realistic test collections | 30-60 min | Console screenshots; authenticated Home uses stored timestamps |
| P0 | Repair auth restore stream and test cold restart/sign-out | 1-2 h | Android recording/screenshots of signed-in and signed-out routes |
| P1 | Run live Storage, FCM, Analytics, Crashlytics and Remote Config proof matrix | 3-5 h | Console evidence saved under `evidence/` |
| P1 | Implement missing FCM navigation/error UX and Remote Config failure handling | 2-4 h | Manual tests plus widget tests |
| P2 | Align documentation, add tests, run 13x3 ARTEMIS suite, and commit staged work | 4-8 h | Green reports, trace IDs, Git log, updated docs |

## Conclusion

The Firebase code is **partially integrated but not submission-ready**. It can be used as a development base after real data is configured, but it should not be presented as a verified Lab 3 Firebase demo. The immediate blockers are the unsafe team rule, incomplete registration document, missing restored-auth state, and missing Console/device evidence for every required Firebase service.
