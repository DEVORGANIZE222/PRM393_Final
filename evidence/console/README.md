# Firebase Console evidence

Screenshots of the Firebase Console for project **`prm393-lab-3-exematching`** (Android app
`com.devorganize222.exematching`), taken on 2026-11-03.

| File | What it shows |
|---|---|
| `console_auth_users.jpg` | Authentication → Users: four Google-provider accounts, including the E2E account `megalit2578@…` (UID `F5KSMg0wLGXf…`) signed in on Nov 3. |
| `console_firestore_allowed_emails.jpg` | Firestore → `allowedEmails`: the class roster (`<email>` → `enabled: true`) that sign-in checks. |
| `console_firestore_teams.jpg` | Firestore → `teams/team_ai04`: capacity 5, category AI/ML, code AI-04, `invitesSent`, `leaderId`, `locked: false`, `memberIds`. |
| `console_firestore_rules_teams.jpg` | Deployed Firestore rules, team updates: `onlyRosterFields = after.diff(before).affectedKeys().hasOnly([...])` (GR-01, commit `c9543a3`) and the per-mutation checks (`isSelfJoin`, `isSelfLeave`, `isSelfVote`, `isLeaderLock`, `isLeaderPoolInvite`). |
| `console_firestore_rules_waiting_pool.jpg` | Deployed Firestore rules, `waitingPool/{userId}`: leaders may read unassigned candidates (commit `68e0656`); only the leader of `assignedTeamId` may mark a candidate assigned. |
| `console_storage_files.jpg` | Storage → `reports/F5KSMg0wLG…/`: team PDFs `team-ai-04-YYYYMMDD-HHMM.pdf` uploaded by the app (E2E TC-13). |
| `console_storage_rules.jpg` | Deployed Storage rules: `match /reports/{userId}/{allPaths=**} { allow read, write: if request.auth != null && request.auth.uid == userId; }`. |

The rules files in the repository are `firebase/firestore.rules` and `firebase/storage.rules`; the screenshots
show they are the deployed versions.
