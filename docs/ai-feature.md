# AI Feature Specification (Google Gemini via Firebase AI Logic)

## 1. Overview
The in-app AI feature assists student users and mentors during the Capstone registration and topic proposal workflow in the Mobile Client (`mobile/lib/screens/create_team/create_team_screen.dart` via `AiTopicAdvisorService`).

* **Capability Level**: **Level 2 (Structured output / Smart Draft, confirmed by the user)**.
* **Provider**: Google Gemini Developer API (`gemini-2.5-flash`).
* **Governance**:
  - Remote Config flag `enable_ai_feature` (kill-switch) and model configuration.
  - Zero personal data policy: Strips student names, emails, phone numbers, and student IDs via `sanitizePii()` before submission.
  - Graceful fallback: When offline, timeout, or quota is exceeded (HTTP 429), falls back to structured rule-based proposal with user notification.
  - User confirmation: Output is clearly tagged with a `StatusBadge(label: 'AI Generated Draft · Editable')` and populated directly into editable text fields.
  - Logging: Logs `ai_request`, `ai_result_accepted`, and `ai_error` to Firebase Analytics.

---

## 2. Remote Config Parameters
Managed via Firebase Remote Config (`firebase/remote-config-defaults.json`):

| Key | Type | Default | Purpose |
|---|---|---|---|
| `enable_ai_feature` | Boolean | `true` | Emergency kill-switch (can disable feature live) |
| `ai_model_name` | String | `gemini-2.5-flash` | Generative model identifier |
| `ai_prompt` | String | `Summarize project topic and extract tags...` | Base system instructions |
| `gemini_api_key` | String | `""` *(set in Firebase Console)* | Gemini Developer API key fetched from Firebase Remote Config |

---

## 3. Real Example Test Cases (3 Inputs & Outputs)

### Example 1: Normal Generation (AI & IoT Topic)
* **Input**:
  - Category: `AI & Machine Learning`
  - Raw Title: `Delivery drone for university`
  - Raw Description: `My student team wants to build an automated drone that delivers books across campus.`
* **Sanitized Prompt Sent to Gemini**:
  - `Input category: AI & Machine Learning | Input title: Delivery drone for university | Input description: My student team wants to build an automated drone that delivers books across campus.`
* **Structured JSON Output**:
  ```json
  {
    "refinedTitle": "Autonomous Campus Micro-Drone Delivery System",
    "description": "An autonomous micro-drone network designed to deliver educational supplies across university campuses with real-time waypoint routing, geofencing, and battery telemetry.",
    "suggestedTags": ["Drone", "AI/ML", "IoT", "Flutter"],
    "suggestedRoles": ["Embedded Engineer", "Mobile Developer", "Backend Architect"]
  }
  ```
* **Event Logged**: `ai_request {feature: topic_advisor, model: gemini-2.5-flash}` followed by `ai_result_accepted {feature: topic_advisor}` upon user applying the draft.

---

### Example 2: PII Stripping / Privacy Guard
* **Input**:
  - Category: `FinTech`
  - Raw Title: `Payment wallet for student SE170123 danghoang862@gmail.com`
  - Raw Description: `Contact me at 0987654321 if you want to join our crypto payment team.`
* **Sanitized Output by `sanitizePii()`**:
  - Stripped: `Payment wallet for student [STUDENT_ID] [REDACTED_EMAIL]`
  - Stripped: `Contact me at [PHONE] if you want to join our crypto payment team.`
* **Structured Output**:
  ```json
  {
    "refinedTitle": "Decentralized Micro-Payment Platform for Student Services",
    "description": "A secure, low-latency digital payment ecosystem enabling instant peer-to-peer settlements and automated merchant reconciliations for university campuses.",
    "suggestedTags": ["FinTech", "Security", "Payment Gateway", "PostgreSQL"],
    "suggestedRoles": ["Security Specialist", "Fullstack Dev", "QA Engineer"]
  }
  ```

---

### Example 3: Handling Malformed or Minimal Input
* **Input**:
  - Category: `Web & Cloud Applications`
  - Raw Title: `app`
  - Raw Description: `` (empty)
* **Structured Output**:
  ```json
  {
    "refinedTitle": "NextGen Web & Cloud Applications Platform",
    "description": "A modern cloud-enabled Web & Cloud Applications capstone project built with Flutter and Firebase, featuring secure role-based access control and real-time collaboration.",
    "suggestedTags": ["Cloud", "Mobile", "Firebase"],
    "suggestedRoles": ["Frontend Dev", "Backend Dev", "UI/UX Designer"]
  }
  ```

---

## 4. Failure Handled: Quota Exhaustion (429 Rate Limit) & Offline Network Drop
* **Scenario**: During grading or peak load, Gemini Developer API free-tier quota (15 RPM / 1M TPM) is exceeded, returning `429 Too Many Requests`, or the emulator environment runs offline.
* **Handled Action**:
  1. `AiTopicAdvisorService` catches the `ClientException` / HTTP 429 status code.
  2. Dispatches `analytics.logAiError(feature: 'topic_advisor', errorReason: 'network_or_quota_fallback: ...')`.
  3. Instantly generates a clean, domain-appropriate structured fallback without throwing an unhandled exception or freezing the UI.
  4. The user receives the structured draft with the editable form state intact, allowing seamless completion without interruption.
