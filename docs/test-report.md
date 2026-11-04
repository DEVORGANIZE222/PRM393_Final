# Final Test Report & Evidence Summary

This report aggregates all automated and manual verification conducted across the Mobile client, Web Admin, Firebase Security Rules, and AI features.

---

## 1. Automated Mobile E2E Testing (Google ARTEMIS & Pytest)
* **Execution Summary**: **10 test cases × 3 runs = 30 runs**.
* **Pass Rate**: **30 / 30 PASSED (100%)**.
* **Evidence Directory**: `e2e_test/evidence/` (JUnit XML: `e2e_test/evidence/junit.xml`).

| Test Case | Description | Result (Runs 1-3) |
|---|---|:---:|
| **TC-01** | Unauthorized account rejected with roster warning | 3/3 PASS |
| **TC-02** | Authorized roster account sign-in | 3/3 PASS |
| **TC-03** | Search and filter teams | 3/3 PASS |
| **TC-04** | Empty search state and filter reset | 3/3 PASS |
| **TC-05** | Network drop and reconnection recovery | 3/3 PASS |
| **TC-06** | Join team with open slot | 3/3 PASS |
| **TC-07** | Team fills before confirm join | 3/3 PASS |
| **TC-08** | Export and upload team summary PDF | 3/3 PASS |
| **TC-09** | Leader election voting transaction | 3/3 PASS |
| **TC-10** | Decline team invite with snackbar undo | 3/3 PASS |

---

## 2. Firebase Security Rules Unit Tests (Emulator Suite)
Tested via `@firebase/rules-unit-testing` in `firebase/tests/rules.test.js`:

| Rule Test ID | Collection | Role | Operation | Expected | Result |
|---|---|---|---|---|:---:|
| **R-01** | `registrations` | `user` | Create with `status = approved` | Denied | **PASS** |
| **R-02** | `registrations` | `staff` | Update `pending` $\rightarrow$ `approved` | Allowed | **PASS** |
| **R-03** | `users` | `user` | Update own `role` field | Denied | **PASS** |

---

## 3. Web Admin Checklist Verification
* **Sign-in**: Google Sign-In validates `users/{uid}.role`. Non-staff rejected with friendly message.
* **Management**: List, search, create, and archive entity operations functional.
* **Review Queue**: Approve and reject actions update Firestore in real time.
* **Dashboard**: Displays 3 aggregation metrics + 1 chart placeholder.
* **Announcement Broadcast**: Posts directly to `announcements` and updates mobile inbox in real time.

---

## 4. AI Code Review on New Architecture & Monorepo Code

| Finding ID | Severity | Component | Finding & Risk | Architectural Decision & Fix |
|---|---|---|---|---|
| **CR-01** | Medium | `packages/core` | Risk of circular dependencies and fat client coupling if `packages/core` imported client-specific routers (`go_router`) or state stores (`provider`). | **Isolated Core**: Restricted `packages/core` strictly to domain models, Firestore services, and pure design tokens/widgets. Routing and client-specific viewmodels remain isolated in `mobile/` and `web/`. |
| **CR-02** | High | `firebase/firestore.rules` | Students could attempt unauthorized privilege escalation or corrupt team metadata (e.g. modify topic title, mentor, or maximum team capacity) during join/leave transactions. | **Field Mask Enforcement**: Enforced `affectedKeys().hasOnly(...)` in `isValidTeamUpdate()`. Metadata is immutable by students; only roster slots, votes, and lock state can be mutated. |
| **CR-03** | High | `mobile/services/ai_topic_advisor_service.dart` | User input fields might contain personal data (emails, student IDs, phone numbers), violating Section 8 zero-PII requirements when calling Gemini Developer API. | **Regex Sanitizer & Graceful Fallback**: Implemented `sanitizePii()` stripping emails, student codes, and phones before API payload construction. Added Remote Config kill-switch `enable_ai_feature` and offline fallback. |
| **CR-04** | Medium | `FirebaseNotificationRepository` | Mobile client listening to personal notifications and broadcast announcements on separate streams could cause race conditions or split-brain UI updates. | **Repository Stream Merging**: Unified `students/{uid}/notifications` and `announcements` inside a single reactive `StreamController` emitting a unified list sorted by timestamp. |
