# Google ARTEMIS E2E evidence

The suite is in `e2e_test/` (13 cases, each run 3 times). ARTEMIS drives the app on the `Pixel_API_36` emulator
(Android 16) with a real Google account on the class roster. Pass/fail is decided by checks on the accessibility
tree, Logcat and Firestore/Storage, not by the agent's own SUCCESS status.

Results, trace IDs and the causes of every failed run are in `docs/test-plan.md` section 3. The PDF report and
slides read their numbers from `e2e_test/evidence/junit.xml`.

| Folder | Content |
|---|---|
| `e2e_test/evidence/` | The final result: `junit.xml`, `pytest-output*.txt` and one folder per test with `run1`…`run3`. |
| `e2e_test/evidence-final-session1/` | Final run session 1 (2026-11-03, build `81695c7`), all 13 cases. |
| `e2e_test/evidence-session2-aborted/` | The 22:04 retry that hit the Gemini quota again (not counted). |
| `e2e_test/evidence-attempt2/` | Attempt 2 (before the fixes listed in the test plan). |

Each `run<n>/` folder holds:

- `result.json`: test name, ARTEMIS trace ID, profile, time taken, the agent's goal and the JSON it returned.
- `final.png`: the screen when the run ended.
- `screen.txt`: the accessibility tree text at the end (Flutter `Semantics.identifier` appears as Android resource-id).
- `analytics.txt`: the Analytics events the app logged during the run, read from Logcat.

The full ARTEMIS log of a run is `C:\PRM393\artemis\traces\<trace_id>\stdout.log` on the test machine.
