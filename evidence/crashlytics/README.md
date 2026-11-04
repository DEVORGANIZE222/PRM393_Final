# Firebase Crashlytics evidence

Package `com.devorganize222.exematching`, project `prm393-lab-3-exematching`. Demo run on 2026-11-04 06:51 with
`e2e_test/capture_screens.py crash` on the `Pixel_API_36` emulator (Android 16).

## How the app reports

- `main.dart`: `FlutterError.onError = recordFlutterFatalError`, and `PlatformDispatcher.instance.onError`
  records uncaught async errors as fatal.
- `SessionViewModel` sets the user ID (Firebase Auth UID) and the key `student_cohort` after sign-in.
- Profile → Diagnostics:
  - **Send Test Error** (`ProfileViewModel.sendNonFatal`) looks up a team that does not exist, sets
    `screen = profile` and calls `recordError(..., reason: 'profile_demo_missing_team')`, which records a non-fatal.
  - **Force Test Crash** asks for confirmation, sets `screen = profile` and calls `FirebaseCrashlytics.crash()`.
    The report is uploaded the next time the app starts.
- Team screens set `team_id`.

## Screenshots

| File | What it shows |
|---|---|
| `../../docs/screenshots/profile_non_fatal_sent.png` | App after **Send Test Error**: "Non-fatal error sent with your user ID and the key "screen"". |
| `../../docs/screenshots/profile_test_crash_dialog.png` | The confirmation before **Force Test Crash**. After "Crash App" the app closed to the launcher. |
| `crashlytics_nonfatal_keys.jpg` | Console, Non-fatals filter, issue `FirestoreTeamRepository._team` ("AppFailure(not-found): This team no longer exists. Error thrown profile_demo_missing_team"), event of Nov 4 06:51:40, Keys tab: `screen = profile`, `flutter_error_reason = thrown profile_demo_missing_team`, `student_cohort` (empty). |
| `crashlytics_crash_keys.jpg` | Console, issue `FlutterFirebaseCrashlyticsPlugin.crash$lambda$0` (`FirebaseCrashlyticsTestCrash`), event of Nov 4 06:51:57, Keys tab: `screen = profile`, `flutter_error_reason = thrown profile_demo_missing_team` and `flutter_error_exception` from the non-fatal sent just before, `student_cohort` (empty, see below). |
| `crashlytics_crash_user.jpg` | The same event, Data tab: User ID `F5KSMg0wLGXf8PiZAstfjzjtUDa2` (the E2E account's Auth UID), Android 16, `Sdk_gphone64_x86_64`. |
| `crashlytics_dashboard.jpg` | Crashlytics dashboard on 2026-11-03 (last 7 days). |

`student_cohort` is sent but empty: the account's `students/{uid}` document has `cohort: ''`, because neither
the sign-in flow nor the roster (`allowedEmails`) provides a cohort for a Google account.

## Older issues in the console

The console also lists layout and stream errors (`RenderBox was not laid out`, `RenderFlex overflowed`,
`[cloud_firestore/permission-denied]` on `notifications_watch`, `NotificationsViewModel was used after being
disposed`, `This team no longer exists`). The last events of the ones checked are from 2026-11-03, before the
fixes listed in `docs/test-plan.md`; some came from a teammate's Android 17 emulator. The Flutter log of the
final E2E session (build `81695c7`) and of every screen captured on 2026-11-04 contains no Flutter error
(`docs/screenshots/capture-flutter-errors.txt`).
