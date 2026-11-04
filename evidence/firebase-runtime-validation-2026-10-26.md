# Firebase runtime validation — 26 October 2026

## Environment

- Android Emulator `emulator-5554` (`PRM393_API_35`)
- Debug APK installed successfully at 13:31 ICT
- Firebase project: `prm393-lab-3-exematching`
- `flutter analyze --no-pub`: passed with no issues

## Runtime evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Startup after a stored Firebase Auth session | PASS | `runtime-auth-recovery.png` shows the sign-in screen after recovery; no uncaught Flutter exception was found in the launch log. |
| Authentication provider configuration | CONFIGURED | Firebase Console shows Google provider as Enabled. A successful roster-authorized Google login has not been run. |
| Remote Config configuration/fetch | CONFIGURED | Firebase Console shows `enable_waiting_pool=true`, `max_team_members=5`, 10 fetches and 1 fetching user in the last 24 hours. Runtime UI behavior after a published value change has not been tested. |
| Cloud Storage | NOT VERIFIED | Bucket and `reports/` folder exist; no real PDF upload, progress, URL, or cross-user denial has been tested. |
| FCM | NOT VERIFIED | Android notification permission exists in the manifest. The app now displays a non-blocking Snackbar when permission is denied, but no real message has been sent or received. |
| Analytics | NOT VERIFIED | No seven custom events were observed in DebugView. |
| Crashlytics | FAIL (known issue fixed locally, console must be rechecked) | Console recorded two `cloud_firestore/permission-denied` Flutter crashes caused by the pre-fix restored-auth allowlist lookup. The recovered build now redirects to sign-in instead of remaining on Splash. A deliberate test crash and a separately verified non-fatal record are still required. |

## Follow-up validation — 28 October 2026

- Rebuilt and reinstalled the debug APK on `emulator-5554`.
- `flutter analyze --no-pub` passed with no issues.
- `flutter build apk --debug` passed.
- Firebase Auth restored the signed-in session for `lamhoangnhan20000@gmail.com` and loaded Home with Firestore-backed team data.
- Profile displayed fetched Remote Config values: `max_team_members=5`, `enable_waiting_pool=true`, and `registration_closed=false`.
- A real Storage export initially failed with `firebase_storage/unauthorized` (HTTP 403). Firebase Storage Console reported that the old rule used an unsupported cross-service Firestore call. The published rule was replaced with UID-only isolation: `request.auth != null && request.auth.uid == userId` under `reports/{userId}/{allPaths=**}`.
- Retesting **Export & Upload PDF** succeeded. The app exposed `export_done` and a Firebase Storage download URL for `reports/Uo0379maVGV02qhYPSmdsNn6vRR2/team-demo-01-20261028-1546.pdf`.

Storage cross-user denial, FCM delivery in three app states, Analytics DebugView, Crashlytics Console records, and Remote Config before/after behavior remain manual verification items.

## FCM follow-up validation — 28 October 2026

- A Firebase Notification campaign was delivered while the Android app was running in the foreground. The app persisted the message in the Alerts inbox; the device showed two received `Team update` entries.
- The initial campaign used the display code `demo-01`, which is **not** the Firestore document ID. The actual team document ID is `demo-flutter`.
- Fixed the inbox route for `NotificationKind.system`, which is the default FCM notification kind. It now opens `/browse/team/{teamId}` instead of doing nothing.
- Rebuilt, reinstalled, and relaunched the debug APK on `emulator-5554`. The tester then tapped a notification whose custom data used `teamId=demo-flutter` and confirmed that it navigated to the team detail screen.

This verifies foreground delivery, in-app inbox persistence, and foreground inbox-to-team navigation. Background delivery, terminated-app delivery, notification-permission denial, and the cross-user Storage denial test remain unverified.

## Crashlytics follow-up validation — 28 October 2026

- `Send Test Error` was triggered from Profile. The app displayed: `Non-fatal error sent with your user ID and the key "screen".` Logcat recorded the Crashlytics call from `ProfileViewModel.sendNonFatal`.
- `Force Test Crash` was confirmed. Android logcat recorded `FATAL EXCEPTION: main` for `FirebaseCrashlyticsTestCrash` caused by `.crash()` in Dart.
- After relaunching the app, the Firebase Crashlytics Console displayed a new `FlutterFirebaseCrashlyticsPlugin.crash$lambda$0` issue with `FirebaseCrashlyticsTestCrash` and `1 crash / 1 user`.
- The Console event Data tab showed `User ID: Uo0379maVGV02qhYPSmdsNn6vRR2`. Its Keys tab showed `screen=profile` and `team_id=demo-flutter` (plus the deliberately recorded non-fatal context), confirming user ID and custom-key propagation.
- The non-fatal report has been sent from the current APK but has not yet been directly located in its Console issue view; treat that Console confirmation as pending.

## Crash follow-up fix — 28 October 2026

- Crashlytics also exposed an earlier `SignInViewModel was used after being disposed` error. The asynchronous sign-in completion handler now guards `notifyListeners()` after disposal. `flutter analyze --no-pub` passed and a new debug APK was built and installed; the restored Gmail session reached Home successfully.

## Remote Config Console observation — 28 October 2026

- Console shows Config Version 1 with `enable_waiting_pool=true` and `max_team_members=5`.
- Console reports 4 fetches and 1 fetching user in the last 24 hours. The Profile runtime UI displayed the same fetched values.
- A published before/after parameter change and a deliberate fetch-failure fallback are still required to verify the two remaining Remote Config runtime criteria.

## Important blocker

The production Firestore Rules do not yet permit the new `allowedEmails/{email}` lookup and the allowlist has not been seeded. The app correctly returns to Sign In instead of hanging, but roster-authorized login cannot pass until the Rules are verified, published, and the roster is seeded.

