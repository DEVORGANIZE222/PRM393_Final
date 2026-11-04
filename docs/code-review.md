# AI Code Review — PRM393 Lab 3

| | |
|---|---|
| **Pull request** | [DEVORGANIZE222/Lab3_Cloud-Enabled_Mobile_App#8](https://github.com/DEVORGANIZE222/Lab3_Cloud-Enabled_Mobile_App/pull/8) `feat/lab3-firebase-fixes` → `main` |
| **AI tool** | Google Gemini (`gemini-3.5-flash-lite`, free API key from Google AI Studio), run by GitHub Actions: [`.github/workflows/gemini-review.yml`](../.github/workflows/gemini-review.yml) + [`.github/scripts/gemini_review.py`](../.github/scripts/gemini_review.py) |
| **Review run** | Actions run #6 (2026-11-02, commit `0f8c2d5`), posted as a review with inline comments on PR #8 |
| **Scope sent to the model** | Source diff only: `lib/`, `firebase/`, `e2e_test/*.py`, `tool/*.py`, `.github/` (36 files, ~159 KB). Images, evidence and lock files are excluded. |
| **Human decision** | Every finding was checked against the code before it was accepted, adjusted or rejected. |

## 1. How the tool was chosen (and what failed)

The lab allows "Copilot, CodeRabbit or an equivalent tool". The repository is private and the team wanted a free tool:

| Attempt | Result |
|---|---|
| **Gemini Code Assist for GitHub** (GitHub App) | Installed on the organisation after the owner approved it, but it never reviewed: its setup now goes through Google Cloud *Developer Connect*, which needs a billing-enabled project. Three `/gemini review` comments on PR #8 got no response. |
| **`google-github-actions/run-gemini-cli`** with the official `code-review` extension (runs #1–#5) | Agentic: one API request per step. The CLI kept calling `gemini-3.8-flash`, whose free tier allows **20 requests/day**, so every run ended with `429 exhausted your daily quota` before posting a review (run #2 also hit `404` for `gemini-2.5-flash`, closed to new keys). |
| **One-request Gemini review script** (run #6) | Sends the source diff to `gemini-3.5-flash-lite` in a single request and posts the JSON findings as a GitHub review. **Succeeded in 14 s.** |

> An earlier version of this file listed six "Gemini Code Assist" findings (GCA-01…06). No pull request existed at that time, so no AI tool had reviewed the code; those entries were removed (commit `ebd793f`). The findings below come from run #6.

## 2. Findings and decisions

5 findings in **3 categories** (security, concurrency, reliability). 3 accepted and fixed, 2 rejected.

| ID | Category · severity | Location | Gemini finding | Decision | Technical reasoning | Fix commit |
|---|---|---|---|---|---|---|
| **GR-01** | security · high | `firebase/firestore.rules:57` (`isSelfJoin`) | The join rule checks only roster fields, so a joining user could also overwrite `supervisor`, `capacity`, `tags`… | **Accepted (widened)** | Confirmed: none of the five update paths (join, leave, vote, lock, pool invite) restricted team metadata. Instead of per-path equality checks, every team update must now satisfy `after.diff(before).affectedKeys().hasOnly([...])` with the eight fields `FirestoreTeamRepository._teamUpdate` writes. Deployed to `prm393-lab-3-exematching` after confirming the live ruleset equalled the repository HEAD. | [`c9543a3`](https://github.com/DEVORGANIZE222/Lab3_Cloud-Enabled_Mobile_App/commit/c9543a3) |
| **GR-02** | concurrency · medium | `lib/firebase/firestore_team_repository.dart:269` (`inviteFromPool`) | Querying the pool outside the transaction lets two teams target the same candidate. | **Rejected** | The query only *proposes* a candidate. Inside the transaction the candidate is re-read with `tx.get(candidateDoc.reference)` and skipped if `assigned == true`; Firestore aborts and retries a transaction whose read document changed before commit, so two teams cannot both assign the same student. The suggested fix (query inside the transaction) is not possible: the client SDKs do not support queries in transactions. | — |
| **GR-03** | reliability · medium | `e2e_test/backend.py:42` | `["tokens"]["refresh_token"]` raises a bare `KeyError` when the Firebase CLI store is missing or logged out. | **Accepted** | A missing login should tell the tester what to do. Now raises an assertion naming `firebase login` / `FIREBASE_TOKEN`. | [`ee6ec78`](https://github.com/DEVORGANIZE222/Lab3_Cloud-Enabled_Mobile_App/commit/ee6ec78) |
| **GR-04** | reliability · low | `lib/firebase/firebase_remote_config_service.dart:24` | Empty catch block hides Remote Config start-up errors. | **Accepted (adjusted)** | The block was not empty, but its `debugPrint` dropped the exception (`"…using in-app defaults: "`), so the effect was the same. The error and the top of the stack are now printed; start-up still continues with the in-app defaults, as the lab requires. | [`d6926d1`](https://github.com/DEVORGANIZE222/Lab3_Cloud-Enabled_Mobile_App/commit/d6926d1) |
| **GR-05** | reliability · medium | `.github/scripts/gemini_review.py:61` | Slicing the error body to 2000 characters may split UTF-8 bytes and raise `UnicodeDecodeError`. | **Rejected** | False positive: the body is decoded with `errors='replace'` *before* slicing, and slicing a Python `str` cannot split a code point. | — |

## 3. Assessment

- **Useful:** GR-01 found a real authorization gap in the Security Rules that the earlier manual hardening missed; it was the most valuable finding.
- **Limits:** two of five findings were wrong (GR-02 ignored the in-transaction re-read; GR-05 misread the order of decode and slice). One accepted finding (GR-04) overstated the problem. AI review output needs the same verification as any other review comment.
- **Cost:** the free tier made the agentic tools unusable for a 36-file diff; a single structured request was enough to produce line-anchored findings.
