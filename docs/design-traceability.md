# Design traceability: Lab 2 → Flutter

**Source of truth:**
- Team Figma file **PRM_LAB2** (https://www.figma.com/design/Z42q9LamOZojK54FSBDcCd/PRM_LAB2), page *03 Final UI*.
- `design/DESIGN.md`, `design/screen-spec.md`, `ux/user-flow.md` and `handoff/flutter-handoff.md` in the Lab 2 repo (DEVORGANIZE222/PRM393_LAB2_uiuxdesign).

**Status:** every screen runs on Firebase (project `prm393-lab-3-exematching`) and was checked on the emulator (Pixel API 36) at 412 dp and 360 dp. The local implementations in `lib/services/local/` are kept for widget tests only.

Screenshots: [`docs/screenshots/`](screenshots), captured from the Firebase build with `e2e_test/capture_screens.py` on 2026-11-04. The script also saves any Flutter layout error printed while each screen was open to `docs/screenshots/capture-flutter-errors.txt`.

## 1. Screens

| Lab 2 screen | Figma frame (node) | Flutter route | Screen widget | ViewModel | Data source | States implemented | App screenshot | Status |
|---|---|---|---|---|---|---|---|---|
| SCR_01 Sign In | [`SCR_01: Sign In (FPT SSO)`](https://www.figma.com/design/Z42q9LamOZojK54FSBDcCd/PRM_LAB2?node-id=6-1712) | `/sign-in` | `SignInScreen` | `SignInViewModel` | `AuthService` | default · signing in · cancelled · wrong domain | [sign in](screenshots/scr01_sign_in.png), [picker](screenshots/scr01_account_picker.png) | done |
| SCR_02 Dashboard | [`SCR_02: Dashboard / Home`](https://www.figma.com/design/Z42q9LamOZojK54FSBDcCd/PRM_LAB2?node-id=6-840) | `/home` (tab 1) | `DashboardScreen` | `DashboardViewModel` | `TeamRepository`, `RegistrationService`, `ConfigService` | loading · in a team · not in a team · registration closed · error | [in a team](screenshots/scr02_home.png), [no team](screenshots/scr02_home_no_team.png), [closed](screenshots/scr02_home_registration_closed.png) | done |
| SCR_03 Browse | [`SCR_03: Browse Groups`](https://www.figma.com/design/Z42q9LamOZojK54FSBDcCd/PRM_LAB2?node-id=6-24) | `/browse` (tab 2) | `BrowseScreen` | `BrowseViewModel` | `TeamRepository`, `ConfigService` | loading · results · empty · offline error | [results](screenshots/scr03_browse.png), [empty](screenshots/scr03_browse_empty.png) | done |
| SCR_04 Team Detail | [`SCR_04: Group Detail`](https://www.figma.com/design/Z42q9LamOZojK54FSBDcCd/PRM_LAB2?node-id=6-1043) + [`SRC4 Diaglog`](https://www.figma.com/design/Z42q9LamOZojK54FSBDcCd/PRM_LAB2?node-id=112-164) | `/browse/team/:teamId` | `TeamDetailScreen` + join dialog | `TeamDetailViewModel` | `TeamRepository` | loading · default · joining overlay · team just filled · already a member · error | [detail](screenshots/scr04_team_detail.png), [dialog](screenshots/scr04_join_dialog.png) | done |
| SCR_05 My Team | [`SCR_05: My Group Hub`](https://www.figma.com/design/Z42q9LamOZojK54FSBDcCd/PRM_LAB2?node-id=6-1254), `SCR_05 (Leader View - Ready to Lock)` | `/team` (tab 3) | `MyTeamScreen` | `MyTeamViewModel` | `TeamRepository` (live) | loading · no team · elect leader · needs members · ready to lock · locked · leaving · error | [no team](screenshots/scr05_no_team.png), [member](screenshots/scr05_my_team.png), [leader](screenshots/scr05_my_team_leader.png) | done |
| SCR_06 Leader Voting | [`SCR_06: Leader Voting`](https://www.figma.com/design/Z42q9LamOZojK54FSBDcCd/PRM_LAB2?node-id=103-2) | `/team/vote` | `LeaderVotingScreen` | `VotingViewModel` | `TeamRepository` | loading · nothing selected · selected · submitting · elected · change-vote dialog · error | [selected](screenshots/scr06_voting_selected.png), [elected](screenshots/scr06_voting_elected.png) | done |
| SCR_07 Lock Review | [`SCR_07: Group Lock Review & Error Recovery`](https://www.figma.com/design/Z42q9LamOZojK54FSBDcCd/PRM_LAB2?node-id=6-474) | `/team/lock` | `LockReviewScreen` | `LockReviewViewModel` | `TeamRepository` (live) | loading · blocked (< 4) · invites sent · member joined · confirm dialog · locking · locked · error | [error](screenshots/scr07_lock_error.png), [recovered](screenshots/scr07_pool_member_joined.png), [dialog](screenshots/scr07_lock_dialog.png), [locked](screenshots/scr07_locked.png) | done |
| SCR_08 Random Pool | [`SCR_08: Random Pool Status`](https://www.figma.com/design/Z42q9LamOZojK54FSBDcCd/PRM_LAB2?node-id=6-290) | `/home/pool` | `RandomPoolScreen` | `PoolStatusViewModel` | `PoolRepository` | loading · matching · refreshing · error | [pool](screenshots/scr08_random_pool.png) | done |
| SCR_09 Alerts | [`SCR_09: Notifications & Invites`](https://www.figma.com/design/Z42q9LamOZojK54FSBDcCd/PRM_LAB2?node-id=6-636) | `/alerts` (bell in the app bar) | `NotificationsScreen` | `NotificationsViewModel` | `NotificationRepository` (live) | loading · list · filtered · empty · error · accept · decline with undo | [alerts](screenshots/scr09_alerts.png) | done |
| *(added)* Profile / Settings | — (handout §3: add if not designed) | `/profile` (tab 4 "Settings", or the avatar) | `ProfileScreen` | `ProfileViewModel` | `ReportService`, `StorageService`, `ConfigService`, `CrashReporter` | account · creating PDF · upload progress · uploaded (URL) · nothing to export · config values · crash checks · sign out | [profile](screenshots/profile.png), [export](screenshots/profile_export_done.png), [config](screenshots/profile_config_diagnostics.png), [non-fatal sent](screenshots/profile_non_fatal_sent.png), [test crash](screenshots/profile_test_crash_dialog.png) | done |
| *(added)* Create Team | — (not in Lab 2; needed so a student can start a team, not only join one) | `/create-team` ("Create" on Browse) | `CreateTeamScreen` | `CreateTeamViewModel` | `TeamRepository` | default · creating · already in a team · error | [create](screenshots/create_team.png) | done |

## 2. Flows

| Lab 2 flow | Routes in order | Alternative / error path in the app | Covered by E2E | Status |
|---|---|---|---|---|
| Flow 1 · Discover & join | `/home` → `/browse` → `/browse/team/:id` → join dialog → `/team` | Team filled before confirming: "EduSmart Analytics just filled up", Join disabled with the reason, "Back to Browse" returns to a refreshed list. No results: empty state with "Clear Filters". Offline: "Can't connect right now" with "Try Again". | TC-03 … TC-07 | done |
| Flow 2 · Leader voting | `/team` → `/team/vote` → submit → `/team` | Tallies stay hidden until the student votes. Changing a vote asks for confirmation. Load error: retry. | TC-08, TC-09 | done |
| Flow 3 · Lock roster | `/team` (leader) → `/team/lock` → destructive dialog → locked | Fewer than 4 members: "Can't lock yet: needs 1 more member", lock disabled with the reason. Recovery: "Invite from Waiting Pool"; when a pool student accepts, the checks turn green and lock unblocks. "Share Team Link" opens the Android share sheet. | TC-10, TC-11 | done |

## 3. Components

| Lab 2 component | Variants / states | Widget (`lib/widgets/`) |
|---|---|---|
| Button | primary · secondary · destructive · text × default · pressed · disabled · loading | `AppButton` |
| Text field | default · focused · filled · error · disabled | `AppTextField` (+ `AppSearchField`) |
| Card | default · pressed · selected | `AppCard`, `SelectableCard` |
| Bottom navigation | 4 destinations, one selected, unread badge | `AppNavigationShell` |
| App bar | default · with back · with actions | `AppTopBar` |
| Dialog | confirmation · destructive | `showAppDialog()` |
| Loading | skeleton list · spinner · blocking overlay | `LoadingState`, `SkeletonList`, `BlockingOverlay` |
| Empty state | icon + message + one action | `EmptyState` |
| Error state | message + cause in plain language + retry | `ErrorState` |
| Badge / chip / banner / avatar / progress | tone variants | `StatusBadge`, `AppChip`, `InfoBanner`, `MemberAvatar`, `SlotRow`, `AppProgressBar` |
| Team status (screen-level) | phase badge, stats, roster row, open slot | `TeamStatusCard`, `MemberTile`, `OpenSlotTile` (`lib/screens/shared/`) |

## 4. Deviations from the Figma file (with reasons)

The changes come from building the design against the two principle sets the team adopted for Lab 3:
- **UX Writing Best Practices Checklist** (Bobbie Wood: content heuristics).
- **UI Consistency Checklist** (identityforge.io).

Each change still has to be mirrored in the Figma file by a teammate with edit access.

| # | Figma | App | Reason (principle) |
|---|---|---|---|
| DV-01 | The same concept is called *Group* and *Team* ("My Group Hub", "Leave Group", "Team AI-04", "Request to Join Team") | **Team** everywhere: tab "My Team", "Leave Team", "Browse Teams" | Consistency: *each concept has one name throughout*. UX writing: *consistent terminology*. |
| DV-02 | Button and heading case is mixed ("View Details & Join", "Submit Vote", "Cancel and return to hub") | Title Case for buttons, tabs and screen titles; sentence case for body, helper and error text | Consistency: *capitalisation follows one rule*. |
| DV-03 | Some primary buttons and the join dialog end with an arrow "→" while others don't | No arrows inside button labels; navigation is shown by the screen change | Consistency: *primary actions look the same*. |
| DV-04 | The join dialog sends a *request* to the leader ("Send Join Request?", "Confirm & Send Request") | The dialog says **"Join Team AI-04?"**, names the slot the student takes, and the confirm button reads **"Join Team"** | The Lab 2 Flow 1 spec joins directly after a real-time capacity check; a leader-approval step would add a waiting state no flow covers. UX writing: *buttons name their action, confirmations echo it*. |
| DV-05 | Error copy such as "Ineligible to Lock Roster" puts the cause last | **"Can't lock yet: needs 1 more member"**, then the count, the rule and what to do | UX writing, error messages: *actionable* and *front-loaded*. |
| DV-06 | Notification titles start with the actor ("FinTech Guard invited you to join their team as …") | The key words come first ("Invite: FinTech Guard · Mobile & Frontend"), the full sentence underneath | UX writing, notifications: *front-loaded* (still clear when truncated). |
| DV-07 | Step badges ("Step 01/02/03") and long copy on Sign In | Kept as "Step 1–3", copy shortened to ≤ 2 lines per step | UX writing: *concise*, *readable*. |
| DV-08 | Dashboard and Team Detail show a bell, an avatar and settings in the app bar; Alerts is the 4th tab | The bell with its unread badge opens **Alerts**; the avatar and the 4th tab "Settings" open **Profile** (added screen) | Handout §3 (Profile screen required). Alerts are checked, not visited, so they sit behind the bell the Figma app bar already shows; the tab bar keeps the four places a student works in. |
| DV-09 | Warning text `#B26A00` on white (4.24 : 1) | Warning and accent text `#B4530A`, the Figma orange-brown (5.7 : 1 on white, 4.9 : 1 on the `#FDE8DA` peach panels) | WCAG 1.4.3 contrast; consistency: *colour tokens, not one-off values*. |
| DV-10 | Input and card borders `#E1E3E5` (1.29 : 1) | Inputs, chips and outlined buttons use `outline` `#737980` (≥ 3 : 1); card borders stay light because a card is recognised by its content, not its edge | WCAG 1.4.11 non-text contrast. |
| DV-11 | Dashboard "Prerequisite Check" card | Removed | No data source for it exists in Lab 2 or Lab 3 scope; showing fixed "passed" rows would be false information. UX writing: *truthful*. |
| DV-12 | "Continue with Google" as a white outlined button | Filled primary button | It is the only action on the screen; consistency: *the primary action uses the primary style*. |
| DV-13 | Dashboard "Skill Match" health chip | Replaced by **Team size · Leader · Supervisor** stats with icon + text | Skill match has no defined calculation; the three stats are the real lock conditions (consistency with SCR_07 checks). |
| DV-14 | Status shown by colour only on some chips | Every status badge has an icon and a text label; selection uses a radio icon and a 2 dp border | WCAG 1.4.1; consistency: *one status vocabulary* (`teamPhase()` used on every screen). |
| DV-15 | Primary action at the bottom of the roster on My Team | The next action ("Vote for Leader", "Review & Lock") sits under the status banner, before the roster; "Leave Team" stays last | Found while testing: the action was below the fold at 412 dp. UX: *the next step is always visible*. |
| DV-16 | Typography: Inter in the Lab 2 tokens | Roboto (system font on Android) with the same type scale | DESIGN.md allows Inter or Roboto; Roboto avoids bundling a font and matches Android. |
