# Firebase Remote Config evidence

Live demo on 2026-11-04, project `prm393-lab-3-exematching`, app running on the `Pixel_API_36` emulator.
The app was not restarted or reinstalled between the screenshots.

In-app defaults (`ConfigKeys.defaults` in `lib/services/services.dart`): `max_team_members = 5`,
`enable_waiting_pool = true`, `registration_closed = false`, `urgent_deadline_days = 3`,
`banner_announcement`. `FirebaseRemoteConfigService` listens to `onConfigUpdated`, activates the new values and
notifies `DashboardViewModel` and `ProfileViewModel` through its `changes` stream.

| Time | File | What it shows |
|---|---|---|
| before | `console_before.jpg` | Console, Config Version 5: only `enable_waiting_pool = true` and `max_team_members = 5` are published, so `registration_closed` uses the in-app default `false`. |
| 06:42 | `app_before.png` | App, Settings tab → App settings: `registration_closed  false`. |
| 06:44 | `console_published.jpg` | Console, Config Version 6: `registration_closed = true` published ("Just now"); "1 since last publish" under fetches. |
| 06:44 | `app_after.png` | The same Settings screen, with no tap or restart in between: `registration_closed  true`. |
| 06:45 | `app_after_home.png` | Home after switching tabs: "Registration is closed" banner and "View Matching Status". The Waiting Pool entry needs `enable_waiting_pool = true` and a student without a team. |

The Matching Status screen (`docs/screenshots/scr08_random_pool.png`) needs a `waitingPool/{uid}` record. The app
does not create one; in the Lab 2 design the Academic Office places students left without a team. For the
screenshot, `Backend.place_in_pool` (`e2e_test/backend.py`) wrote that record, and `Backend.reset` removes it again.

**Revert:** the parameter was deleted and published again (Config Version 7, back to the two original parameters).
The running app showed registration open again about 90 seconds later.
