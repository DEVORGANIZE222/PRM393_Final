"""Gemini pull request review in one API request (PRM393 Lab 3 AI code review).

Reads the pull request's code diff, asks Gemini for findings tied to changed
lines, and posts them as one GitHub review with inline comments. Findings on
lines outside the diff go into the review body instead, because GitHub rejects
inline comments there.

Environment: GEMINI_API_KEY, GITHUB_TOKEN, GITHUB_REPOSITORY, PR_NUMBER,
GEMINI_MODEL (default gemini-3.5-flash-lite), and for pushes EVENT_ACTION and
HEAD_SHA (a push is reviewed only if its commit message has "[gemini-review]").
"""

from __future__ import annotations

import fnmatch
import json
import os
import re
import sys
import urllib.error
import urllib.request

REPO = os.environ["GITHUB_REPOSITORY"]
PR = os.environ["PR_NUMBER"]
MODEL = os.environ.get("GEMINI_MODEL") or "gemini-3.5-flash-lite"
GITHUB = f"https://api.github.com/repos/{REPO}"

# Source the review should cover; generated evidence, lock files and images are skipped.
INCLUDE = ["lib/*", "firebase/*", "e2e_test/*.py", "tool/*.py", ".github/*", "android/app/build.gradle.kts"]
MAX_DIFF_CHARS = 400_000

PROMPT = """You are a senior Flutter / Firebase reviewer. Review this pull request diff
for an Android Flutter app (MVVM + Provider) backed by Firebase Auth, Cloud
Firestore (with security rules), Storage, FCM, Analytics, Crashlytics and Remote
Config, plus a Python ARTEMIS end-to-end test suite.

Report only real, specific problems in the CHANGED lines: correctness bugs,
security (Firestore/Storage rules, secrets), concurrency/transactions, error
handling and reliability, performance, accessibility, maintainability. No praise,
no style nits a formatter would fix. Give 5 to 10 findings, most severe first.

Return ONLY a JSON array. Each item:
{"path": "<file path as in the diff>", "line": <line number in the NEW file>,
 "category": "security|correctness|concurrency|reliability|performance|accessibility|maintainability",
 "severity": "high|medium|low", "title": "<short>", "explanation": "<why it is a problem>",
 "suggestion": "<concrete fix>"}
"""


def http(method: str, url: str, body: dict | None = None, headers: dict | None = None, accept: str = "application/json"):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method, headers={"Accept": accept, **(headers or {})})
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {url} failed: {error.code} {error.read().decode('utf-8', 'replace')[:2000]}")
    return json.loads(raw) if accept == "application/json" else raw


def github(method: str, path: str, body: dict | None = None, accept: str = "application/vnd.github+json"):
    headers = {"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}", "X-GitHub-Api-Version": "2022-11-28"}
    return http(method, f"{GITHUB}{path}", body, headers, accept if accept != "application/vnd.github+json" else "application/json")


def source_diff() -> str:
    """Unified diff of the files matching INCLUDE.

    Built from the "list pull request files" API, because the .diff media type is
    refused for pull requests that touch more than 300 files (evidence screenshots
    easily exceed that); the files API pages through up to 3000.
    """
    parts, page = [], 1
    while True:
        files = github("GET", f"/pulls/{PR}/files?per_page=100&page={page}")
        for f in files:
            path = f["filename"]
            # GitHub leaves out the patch of binary and very large files.
            if "patch" not in f or not any(fnmatch.fnmatch(path, pattern) for pattern in INCLUDE):
                continue
            old = f.get("previous_filename", path)
            parts.append(f"diff --git a/{old} b/{path}\n--- a/{old}\n+++ b/{path}\n{f['patch']}\n")
        if len(files) < 100:
            break
        page += 1
    return "".join(parts)[:MAX_DIFF_CHARS]


def commentable_lines(diff: str) -> dict[str, set[int]]:
    """New-file line numbers that appear in the diff (added or context), per path."""
    lines: dict[str, set[int]] = {}
    path, new_line = None, 0
    for row in diff.splitlines():
        if row.startswith("+++ b/"):
            path = row[6:]
            lines.setdefault(path, set())
        elif row.startswith("@@"):
            new_line = int(re.search(r"\+(\d+)", row).group(1))
        elif path and not row.startswith(("---", "diff --git", "index ", "\\")):
            if row.startswith("-"):
                continue
            lines[path].add(new_line)
            new_line += 1
    return lines


# With a schema Gemini must return this exact shape; "application/json" alone still
# let it emit unescaped quotes inside an explanation (PR #10, JSONDecodeError).
FINDINGS_SCHEMA = {
    "type": "ARRAY",
    "items": {
        "type": "OBJECT",
        "properties": {
            "path": {"type": "STRING"},
            "line": {"type": "INTEGER"},
            "category": {
                "type": "STRING",
                "enum": ["security", "correctness", "concurrency", "reliability", "performance", "accessibility", "maintainability"],
            },
            "severity": {"type": "STRING", "enum": ["high", "medium", "low"]},
            "title": {"type": "STRING"},
            "explanation": {"type": "STRING"},
            "suggestion": {"type": "STRING"},
        },
        "required": ["path", "line", "category", "severity", "title", "explanation", "suggestion"],
    },
}


def ask_gemini(diff: str, attempts: int = 3) -> list[dict]:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
    body = {
        "contents": [{"role": "user", "parts": [{"text": PROMPT + "\n\nDIFF:\n" + diff}]}],
        "generationConfig": {
            "temperature": 0.2,
            "responseMimeType": "application/json",
            "responseSchema": FINDINGS_SCHEMA,
        },
    }
    for attempt in range(1, attempts + 1):
        reply = http("POST", url, body, {"x-goog-api-key": os.environ["GEMINI_API_KEY"]})
        text = reply["candidates"][0]["content"]["parts"][0]["text"]
        try:
            findings = json.loads(text)
        except json.JSONDecodeError as error:
            print(f"Attempt {attempt}: Gemini returned invalid JSON ({error}); near: {text[max(0, error.pos - 200):error.pos + 50]!r}")
            continue
        return findings if isinstance(findings, list) else findings.get("findings", [])
    sys.exit(f"Gemini returned invalid JSON {attempts} times; no review posted.")


def main() -> None:
    if not os.environ.get("GEMINI_API_KEY"):
        print("::notice::Skipped: add the repository secret GEMINI_API_KEY to enable the Gemini review.")
        return
    if os.environ.get("EVENT_ACTION") == "synchronize":
        message = github("GET", f"/commits/{os.environ['HEAD_SHA']}")["commit"]["message"]
        if "[gemini-review]" not in message:
            print("Push without [gemini-review] in the head commit message: no review.")
            return
    diff = source_diff()
    if not diff:
        sys.exit("No reviewable source changes in this pull request.")
    findings = ask_gemini(diff)
    allowed = commentable_lines(diff)

    inline, outside = [], []
    for i, f in enumerate(findings, 1):
        tag = f"GR-{i:02d}"
        text = (
            f"**{tag} · {f.get('severity', '?')} · {f.get('category', '?')}: {f.get('title', '')}**\n\n"
            f"{f.get('explanation', '')}\n\n**Suggestion:** {f.get('suggestion', '')}"
        )
        path, line = f.get("path", ""), f.get("line")
        if isinstance(line, int) and line in allowed.get(path, set()):
            inline.append({"path": path, "line": line, "side": "RIGHT", "body": text})
        else:
            outside.append(f"- `{path}:{line}` — {text}")

    summary = [
        f"## Gemini code review (`{MODEL}`)",
        f"{len(findings)} findings, {len(inline)} posted inline. Generated by `.github/scripts/gemini_review.py` "
        "in one Gemini API request over the source diff (`lib/`, `firebase/`, `e2e_test/*.py`, `tool/`, `.github/`).",
    ]
    if outside:
        summary += ["", "### Findings outside the changed lines", *outside]
    github("POST", f"/pulls/{PR}/reviews", {"event": "COMMENT", "body": "\n".join(summary), "comments": inline})
    print(json.dumps(findings, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
