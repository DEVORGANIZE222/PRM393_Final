# Google Analytics DebugView evidence

Firebase Console → Analytics → DebugView for project `prm393-lab-3-exematching`, taken on 2026-11-03 while the
E2E suite and manual checks ran on the emulator.

Debug mode on the device:

```bash
adb shell setprop debug.firebase.analytics.app com.devorganize222.exematching
```

Turn it off afterwards with `adb shell setprop debug.firebase.analytics.app .none.`

| File | What it shows |
|---|---|
| `debugview_login_user_id.jpg` | The `login` event in Top Events, and the user property `user_id` = `F5KSMq0w…` (the Firebase Auth UID set by `setUserId` after sign-in). |
| `debugview_search_teams_params.jpg` | `search_teams` (4 events) with its parameters `query_length`, `result_count` and `filter_count`. The search text is not sent. Top Events also lists `cast_vote` (3) and `invite_pool` (3). |
| `debugview_cast_vote_params.jpg` | `cast_vote` (3 events) with `team_id` = `team_ai04` and `changed`. `changed` is sent as 0/1 because Analytics rejects a bool parameter. |

## Events in the app

`lib/firebase/firebase_analytics_service.dart` logs 10 events. Parameters are IDs and counts only, with no email, name or search text.

| Event | Trigger | Parameters |
|---|---|---|
| `login` | Google sign-in succeeded | `method` |
| `logout` | Sign out on Profile | — |
| `search_teams` | Search text or filter changed on Browse | `query_length`, `result_count`, `filter_count` |
| `view_team` | Team Detail opened | `team_id`, `team_code` |
| `create_team` | Team created | `team_id`, `team_code` |
| `join_team` | Join confirmed | `team_id`, `member_count` |
| `cast_vote` | Leader vote submitted | `team_id`, `changed` (0/1) |
| `invite_pool` | Leader invited from the Waiting Pool | `team_id`, `invited_count` |
| `lock_roster` | Leader locked the roster | `team_id`, `member_count` |
| `export_report` | Team PDF exported and uploaded | `team_id`, `file_size_kb` |

DebugView screenshots exist for `login`, `search_teams` and `cast_vote`; `invite_pool` appears in Top Events.
For the other events the evidence is the Logcat line `analytics_event <name> {...}` that each E2E run saves in
`e2e_test/evidence/<test>/run<n>/analytics.txt`.
