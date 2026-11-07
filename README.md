# PRM393 — Final Assignment: One Complete System on Firebase

**PRM393 Final Assignment**, team **DEVORGANIZE222**. A complete cross-client system joining the Lab 2 design and Lab 3 mobile app into one unified production architecture:
1. **Mobile App (`mobile/`)**: Flutter Android app for students (flows: auth, browse, join, vote, lock review, announcement inbox, Level 2 Gemini AI advisor).
2. **Web Admin (`web/`)**: Flutter Web application on Firebase Hosting for Staff/Admin (Dashboard, Entity Management, Review Queue, Announcement Broadcast).
3. **Shared Core Package (`packages/core/`)**: Common Dart models, Firestore services, and Lab 2 design tokens shared across mobile and web.
4. **Backend (`firebase/`)**: Role-based Firestore Security Rules tested via Emulator Suite, zero-server architecture.
5. **AI Feature**: Google Gemini Developer API integration (Level 2: Structured output with Remote Config, App Check, and Analytics logging).
6. **E2E Quality Assurance**: Google ARTEMIS automated E2E test suite (**10 test cases × 3 runs = 30 runs, 30/30 PASSED**).

---

## 1. Demo Accounts & Roles (Section 6 & 10)

Roles are stored in `users/{uid}.role` and enforced on every read/write by Firestore Security Rules:

| Role | Demo Account Email | Client | Access & Capabilities |
|---|---|---|---|
| **`admin`** | `admin@fpt.edu.vn` | Web Admin | Initial Admin configured in Firebase Console. Can change user roles, archive entities, view analytics dashboard. |
| **`staff`** | `mentor@fpt.edu.vn` | Web Admin | Mentor / Capstone Organizer. Can approve/reject mobile registrations in Review Queue, create entities, broadcast announcements. |
| **`user`** | `hoang@fpt.edu.vn`<br>`minh@fpt.edu.vn` | Mobile App | Student. Can browse teams, join teams, vote for leaders, lock roster, receive real-time announcements, draft topics with Gemini AI. |

* **Live Web Admin URL**: `https://prm393-final-exematching.web.app` (Firebase Hosting)
* **Demo Video Link**: `https://youtu.be/prm393-final-demo-placeholder` (8–12 minutes walkthrough)

---

## 2. Deliverables & Repository Structure (Section 10)

```
PRM393_Final_DEVORGANIZE222/
├── README.md
├── packages/
│   └── core/                     # Shared models, Firestore services, Lab 2 theme & widgets
├── mobile/                       # Flutter Android student application
├── web/                          # Flutter Web admin application
├── e2e_test/                     # Google ARTEMIS 10 test cases × 3 runs = 30 runs
│   └── evidence/                 # JUnit XML (30/30 pass) and per-run logs
├── firebase/                     # Backend configuration & emulator tests
│   ├── firebase.json             # Emulator & hosting mapping
│   ├── firestore.rules           # Role-based security rules (Appendix A & B)
│   ├── firestore.indexes.json    # Composite indexes
│   ├── remote-config-defaults.json # AI parameters & runtime flags
│   └── tests/rules.test.js       # Security Rules unit tests (R-01, R-02, R-03)
├── docs/                         # Required Markdown deliverables
│   ├── gap-review.md             # Stage 1: Gap review of Lab 2 vs Lab 3 vs Final
│   ├── data-model.md             # Stage 2: Data model & rules specification (Appendix A)
│   ├── cross-role-flow.md        # Stage 5: Cross-role sequence diagram & timing (Appendix C)
│   ├── ai-feature.md             # Stage 5: Level 2 Gemini AI specification
│   └── test-report.md            # Stage 6: Test evidence & AI code review
├── evidence/                     # Screenshots: console, Crashlytics, Remote Config, FCM
├── report/
│   └── Final_DEVORGANIZE222.pdf  # 10–15 page comprehensive project report
└── slides/
    └── Final_DEVORGANIZE222_slides.pdf # 12–15 slide final presentation deck
```

---

## Mentor Selection (second cross-role flow)

1. An admin adds a lecturer in the web admin (**Giảng viên**) with their Google email. That creates `mentors/{id}` and sets `allowedEmails/{email}.mentorId`.
2. A team leader opens My Team → Mentor on mobile and sends a request.
3. The lecturer signs in to the same mobile app, lands on the Mentor Portal and accepts or declines. Web stays admin-only.
4. The team's Mentor card updates in real time and the leader gets an inbox message. The admin sees the result on **Giảng viên**.

---

## 3. How to Run Each Client & Emulators

### A. Run Mobile Client (Android)
```bash
cd mobile
flutter pub get
flutter run
```

### B. Run Web Admin Client (Web)
```bash
cd web
flutter pub get
flutter run -d chrome
```

### C. Run Firebase Emulator Suite & Security Rules Tests
```bash
# Start Emulators (Firestore on 8080, Auth on 9099, Hosting on 5000, UI on 4000)
firebase emulators:start --only firestore,auth

# In a separate terminal, run Security Rules unit tests (R-01, R-02, R-03):
firebase emulators:exec --only firestore "npm test --prefix firebase"
```

### D. Deploy Web Admin to Firebase Hosting
```bash
cd web
flutter build web --release
cd ..
firebase deploy --only hosting
```

---

## 4. Run the E2E Tests (Google ARTEMIS & Pytest)

The E2E test suite uses **Google ARTEMIS** to drive the real Android Flutter app via Accessibility & UIAutomator, alongside a Python backend fixture (`e2e_test/backend.py`) that manages Firestore state before and during test assertions.

### 1. Prerequisites: Firebase CLI Login
```bash
# Login to Firebase
npx firebase-tools login

# Verify authenticated account
npx firebase-tools projects:list
```

### 2. Configure & Start ARTEMIS Server
1. Set `GEMINI_API_KEY` in `artemis/.env`.
2. Configure active models in `artemis/config/artemis.jsonc`:
   ```jsonc
   "default": {
     "provider": "google",
     "model": "gemini-2.5-flash",
     "thinking_level": "medium",
     "fallback": {
       "provider": "google",
       "model": "gemini-2.5-flash-lite",
       "thinking_level": "medium"
     }
   }
   ```
3. Start the ARTEMIS server:
   ```bash
   cd artemis
   uv run python main.py
   ```

### 3. Execute Automated E2E Test Suite (30 Runs)
```bash
# Run all 10 test cases (3 runs each):
cd e2e_test
uv run pytest -v --junitxml=evidence/junit.xml

# Run a specific test case:
uv run pytest tests/test_tc03_search_and_filter.py -v
```

---

## 5. Versions and Tooling

| Component | Version / Identifier |
|---|---|
| Flutter | 3.47.0+ (Dart 3.13.3) |
| Firebase CLI | 15.x / 14.x |
| `cloud_firestore` | ^6.0.0 |
| `firebase_auth` | ^6.0.0 |
| `firebase_remote_config` | ^6.0.0 |
| `firebase_analytics` | ^12.0.0 |
| `firebase_crashlytics` | ^5.0.0 |
| `go_router` | 18.1.1 |
| Google ARTEMIS | commit `351ca8422f7b5b54e80a9c1ce03a222e02415b6b` |
| Pytest / Pytest-asyncio | 8.4.2 / 1.2.0 |
| LLM for ARTEMIS & AI Feature | `gemini-2.5-flash` (fallback `gemini-2.5-flash-lite`) |
| Test Device | Android Emulator Pixel API 36 (Android 16), 1080 × 2400 |

---

## 6. AI Tools Used

| Tool | Used For | Artifact & Verification |
|---|---|---|
| **Google Gemini Developer API** | Level 2 Structured in-app topic proposal & tags draft | `mobile/lib/services/ai_topic_advisor_service.dart`, `docs/ai-feature.md` |
| **Google ARTEMIS** | Autonomous mobile E2E test execution (10 test cases × 3 runs = 30 runs) | `e2e_test/evidence/junit.xml` (30/30 passed) |
| **Claude Code / Antigravity** | Architecture monorepo scaffolding, Security Rules, documentation | Git history and codebase commits |
| **Gemini AI Review** | Automated pull request code reviews and architecture analysis | `docs/test-report.md` (4 findings with concrete decisions) |

---

## 7. Cross-Role Live Demo Walkthrough (8–12 Minutes)

The demo video follows the exact flow outlined in Section 10 and Appendix C:

| Timestamp | Segment | Description & Visible Actions |
|---|---|---|
| **00:00 – 01:30** | **Mobile Student Flows** | • Roster login with `hoang@fpt.edu.vn`.<br>• Browse teams, filter tags, join team slot.<br>• Vote for leader with hidden tallies until cast. |
| **01:30 – 03:00** | **Gemini AI Feature (Level 2)** | • Open "Create Team". Tap "✨ Suggest with Gemini AI".<br>• Structured output populates refined topic, tags, and open roles.<br>• Banner shows `[AI Generated Draft · Editable]`. User modifies field.<br>• Console: Show Remote Config `enable_ai_feature` toggle live to demonstrate graceful fallback. |
| **03:00 – 05:30** | **Web Admin Screens** | • Sign-in at Web Admin portal (`https://prm393-final-exematching.web.app`).<br>• Screen 1: Dashboard with 3 aggregation figures + chart.<br>• Screen 2: Entity Management (Events & Topics list, search, archive).<br>• Screen 3: Review Queue. |
| **05:30 – 07:30** | **Cross-Role Live Workflow (Both Screens Visible)** | • Student submits registration on Mobile -> Status: `pending`.<br>• Staff on Web Admin immediately sees item in Review Queue (~180ms).<br>• Staff clicks "Approve" with note -> Mobile updates to `approved` in real time (~210ms).<br>• Staff posts announcement in Announcement Form -> Mobile Alerts inbox receives real-time broadcast notification. |
| **07:30 – 09:30** | **Security Rules & ARTEMIS E2E** | • Explain R-01 (denied self-approval), R-02 (staff approval allowed), and R-03 (role tampering blocked).<br>• Run ARTEMIS automated test suite -> Display `junit.xml` 30/30 passed. |
| **09:30 – 10:30** | **Conclusions & Wrap-up** | • Summary of learnings, zero-server Firebase architecture, App Check & Remote Config governance. |
