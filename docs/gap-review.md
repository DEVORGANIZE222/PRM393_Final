# Gap Review: Lab 2 vs Lab 3 vs Final Scope

This document reviews the evolution of EXEMatching from Lab 2 design to Lab 3 mobile implementation, and the bridge to the Final Assignment.

## 1. Evolution Summary

| Dimension | Lab 2 (Design) | Lab 3 (Mobile App) | Final Assignment |
|---|---|---|---|
| **Clients** | Figma Mobile Screens | Flutter Android App (Single Role) | Flutter Mobile + Flutter Web Admin |
| **Backend** | Conceptual | Firebase (Auth, Firestore, Storage, FCM, Analytics, Remote Config, Crashlytics) | Unified Firestore + Role-Based Security Rules + Firebase Hosting |
| **Roles** | Student | Student (Roster Allowlist) | Student (`user`), Mentor/Staff (`staff`), Admin (`admin`) |
| **AI Feature** | None | ARTEMIS Agentic Testing & Gemini PR Review | In-App Gemini Feature (Streamed / Structured Output) |

## 2. Lab 3 Review Findings Closure

All 5 findings identified in the Lab 3 Gemini code review (`docs/code-review.md`) have been addressed:
- **GR-01 (Security)**: Team document mutations restricted strictly to roster fields (`memberIds`, `members`, `votes`, `leaderId`, `locked`).
- **GR-02 (Reliability)**: Waiting Pool concurrency lock with atomic batch transitions.
- **GR-03 (Performance)**: Firestore query index optimization and offline persistence.
- **GR-04 (Architecture)**: Separation of models into `packages/core/`.
- **GR-05 (Observability)**: Standardized error logging in Crashlytics and Analytics.

## 3. New Final Scope Additions
- Shared Dart package: `packages/core/`.
- Web Admin Portal (`web/`) on Firebase Hosting: Entity Management, Review Queue, Dashboard, Announcement Broadcast.
- Real-time mobile inbox for announcements.
- Cross-role workflow: Mobile submission $\rightarrow$ Web Admin approval $\rightarrow$ Real-time mobile update.

