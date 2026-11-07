# Data Model & Security Rules Specification (Appendix A)

## 1. Roles Definition
Roles are stored directly in `users/{uid}.role`:
* `user`: Standard student user (Mobile App).
* `staff`: Mentor / Instructor / Staff (Web Admin access).
* `admin`: System administrator (Full privileges).

The initial Admin account is configured via Firebase Console: `admin@fpt.edu.vn`. Only Admins can modify the `role` field.

---

## 2. Collections Specification (Appendix A)

| Collection | Key Fields (type) | Create | Read | Update | Delete | Used by Screens |
|---|---|---|---|---|---|---|
| `users/{uid}` | `role` (string: user, staff, admin), `displayName` (string), `email` (string) | Self on first sign-in (`role = 'user'`) | Self, Admin | Admin only (nobody changes own role) | Denied | Mobile Profile; Web User List |
| `events/{id}` | `title` (string $\le$ 120), `startAt` (timestamp), `status` (draft, published, archived), `description` (string) | Staff | Everyone signed in (`published` only) | Staff | Denied (Archive instead) | Mobile List/Detail; Web Management |
| `registrations/{id}` | `eventId` (string), `uid` (string), `status` (pending, approved, rejected), `reason` (string) | User (`status = pending`) | Owner, Staff | Staff (`pending` $\rightarrow$ `approved`/`rejected`) | Owner while `pending` | Mobile Detail; Web Review Queue |
| `announcements/{id}` | `title` (string), `body` (string), `authorId` (string), `createdAt` (timestamp) | Staff | Everyone signed in | Staff | Staff | Mobile Inbox; Web Announce Form |
| `teams/{id}` | `members` (map), `memberIds` (array), `votes` (map), `leaderId` (string), `locked` (bool) | User (solo team) | Roster members | Roster members (via `isValidTeamUpdate`) | Denied | Mobile Browse, Team, Lock Review |
| `mentors/{id}` | `fullName`, `title`, `department` (string), `expertise` (array), `maxQuota`, `currentAssigned` (int), `mentoredTeamNames` (array), `status` (active, archived) | Admin | Roster members, Admin | Admin (profile, quota, archive); the linked lecturer: `currentAssigned` +1 within `maxQuota` | Denied (archive instead) | Mobile Mentor list/profile/portal; Web Giảng viên |
| `mentor_requests/{teamId}` | `teamId`, `teamName`, `mentorId`, `mentorName`, `senderId`, `senderName`, `message` (string), `status` (pending, approved, rejected), `decisionReason` (string) | Team leader (`status = pending`, team has no mentor) | Roster members, Admin | The asked lecturer: `pending` → `approved`/`rejected`; team leader: `rejected` → new `pending` | Team leader while `pending` | Mobile My Team, Mentor profile, Mentor portal; Web Giảng viên |
| `waitingPool/{id}` | `assigned` (bool), `assignedTeamId` (string) | Denied | Self, Team Leader | Team Leader (invite transaction) | Denied | Mobile Lock Review |

---

## 3. Allowed Status Transitions per Role
* **`registrations`**:
  * `User`: None $\rightarrow$ `pending`
  * `User`: `pending` $\rightarrow$ deleted (cancel)
  * `Staff`: `pending` $\rightarrow$ `approved`
  * `Staff`: `pending` $\rightarrow$ `rejected` (requires `reason`)
* **`events`**:
  * `Staff`: `draft` $\rightarrow$ `published` $\rightarrow$ `archived`
* **`mentor_requests`**:
  * `Leader`: None $\rightarrow$ `pending`; `pending` $\rightarrow$ deleted (withdraw); `rejected` $\rightarrow$ `pending` (asks again)
  * Lecturer (`allowedEmails/{email}.mentorId`, set by an admin): `pending` $\rightarrow$ `approved` (also sets `teams.mentorId`, `teams.supervisor`, takes a quota slot and writes the leader's inbox in one transaction)
  * Lecturer: `pending` $\rightarrow$ `rejected` (with `decisionReason` and an inbox message)
* **`teams`**:
  * `Leader`: `locked = false` $\rightarrow$ `locked = true` ($\ge 4$ members)

