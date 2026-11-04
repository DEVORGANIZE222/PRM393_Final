# Firebase Cloud Messaging evidence

Run on 2026-11-04 06:58–07:00 with `e2e_test/capture_screens.py fcm` on the `Pixel_API_36` emulator (Android 16).
Each test message went through the FCM HTTP v1 API (`Backend.send_push`, the same service the Console's "Send test
message" uses) to the token the app saved in `students/{uid}.fcmToken`. Data payload: `kind = system`,
`teamId = team_fin02`, `actionLabel = View team`, `recipientId = <uid>`.

| State | File | What happened |
|---|---|---|
| Foreground | `foreground_alerts.png` | App open on Home. `onMessage` saved the message to `students/{uid}/notifications`; Alerts shows "FCM test · foreground" as a new System alert with "View team". |
| Background | `background.png` | App sent to the background with Home. Android showed "FCM test · background" in the notification shade. |
| Background, tapped | `background_opened.png` | Tapping it brought the app back; `onMessageOpenedApp` saved it and opened Team Detail for `team_fin02` (FinTech Guard). |
| Terminated | `terminated.png` | App process ended with `am kill` (`pidof` returned nothing). The notification "FCM test · terminated" still arrived. |
| Terminated, tapped | `terminated_opened.png` | Tapping it cold-started the app; `getInitialMessage` opened FinTech Guard. |

`am kill` is used instead of `am force-stop`: Android does not deliver FCM to an app that was force-stopped
until the user opens it again. The capture script resets the test data when it ends, which also deletes these
three notifications from Firestore.
