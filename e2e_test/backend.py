"""Cloud Firestore preconditions and ground-truth reads for the E2E suite.

The app signs in with a real Google account, so every test case first puts
Firestore into a known state for that account (which team it is in, who
leads it, which invites it has) and afterwards reads Firestore back to
check that the UI change really reached the cloud.

Authentication reuses the Firebase CLI login (`firebase login`) of the
project owner, or an access token in FIREBASE_TOKEN. Requests go through
the Firestore REST API, so Security Rules do not apply to these helpers.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

# Automatically load .env if present
for _env_path in [Path(__file__).parent / ".env", Path(__file__).parent.parent / ".env"]:
    if _env_path.exists():
        for _line in _env_path.read_text(encoding="utf-8").splitlines():
            _line = _line.strip()
            if _line and not _line.startswith("#") and "=" in _line:
                _k, _v = _line.split("=", 1)
                _k, _v = _k.strip(), _v.strip().strip("'\"")
                if _k and _k not in os.environ:
                    os.environ[_k] = _v

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tool"))
from seed_firestore_lab3 import POOL_IDS, PROJECT_ID, build_seed_writes  # noqa: E402

DOCS = f"projects/{PROJECT_ID}/databases/(default)/documents"
API = f"https://firestore.googleapis.com/v1/{DOCS}"
# Public OAuth client of firebase-tools; it is what `firebase login` stored the refresh token for.
CLI_CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
CLI_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi"
SEEDED_TEAMS = ["team_ai04", "team_fin02", "team_edu07", "team_web11", "team_mob03"]


def _access_token() -> str:
    if token := os.environ.get("FIREBASE_TOKEN"):
        return token
    config = Path.home() / ".config" / "configstore" / "firebase-tools.json"
    # GR-03: a missing or logged-out CLI store must say what to do, not raise KeyError.
    stored = json.loads(config.read_text(encoding="utf-8")) if config.exists() else {}
    refresh = (stored.get("tokens") or {}).get("refresh_token")
    if not refresh:
        raise AssertionError(f"No Firebase CLI login in {config}: run `firebase login` or set FIREBASE_TOKEN")
    body = urllib.parse.urlencode(
        {
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": CLI_CLIENT_ID,
            "client_secret": CLI_CLIENT_SECRET,
        }
    ).encode()
    with urllib.request.urlopen("https://oauth2.googleapis.com/token", body, timeout=30) as response:
        return json.load(response)["access_token"]


# --- value encoding -----------------------------------------------------------
def encode(value: Any) -> dict[str, Any]:
    if value is None:
        return {"nullValue": None}
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    if isinstance(value, datetime):
        return {"timestampValue": value.astimezone(timezone.utc).isoformat()}
    if isinstance(value, list):
        return {"arrayValue": {"values": [encode(v) for v in value]}}
    if isinstance(value, dict):
        return {"mapValue": {"fields": {k: encode(v) for k, v in value.items()}}}
    return {"stringValue": str(value)}


def decode(value: dict[str, Any]) -> Any:
    kind, raw = next(iter(value.items()))
    if kind == "integerValue":
        return int(raw)
    if kind == "arrayValue":
        return [decode(v) for v in raw.get("values", [])]
    if kind == "mapValue":
        return {k: decode(v) for k, v in raw.get("fields", {}).items()}
    if kind == "nullValue":
        return None
    return raw


@dataclass(frozen=True)
class Account:
    uid: str
    email: str
    full_name: str

    @property
    def first_name(self) -> str:
        return self.full_name.split(" ")[0]

    def as_member(self, role: str) -> dict[str, Any]:
        return {
            "studentId": self.uid,
            "fullName": self.full_name,
            "studentCode": self.email.split("@")[0],
            "role": role,
            "skills": ["Flutter", "Firebase"],
        }


class Backend:
    def __init__(self) -> None:
        self._token = _access_token()

    # --- REST ------------------------------------------------------------------
    def _call(self, method: str, url: str, body: Any = None, *, retry: bool = True) -> Any:
        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={"Authorization": f"Bearer {self._token}", "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code == 401 and retry:
                # Access tokens last one hour; a full 3-run suite takes longer.
                self._token = _access_token()
                return self._call(method, url, body, retry=False)
            if error.code == 404 and method == "GET":
                return None
            raise AssertionError(f"Firestore {method} {url} failed: {error.code} {error.read()[:300]!r}") from error

    def get(self, path: str) -> dict[str, Any] | None:
        doc = self._call("GET", f"{API}/{path}")
        return None if doc is None else {k: decode(v) for k, v in doc.get("fields", {}).items()}

    def list(self, collection: str) -> dict[str, dict[str, Any]]:
        out = self._call("GET", f"{API}/{collection}?pageSize=300") or {}
        return {
            d["name"].rsplit("/", 1)[1]: {k: decode(v) for k, v in d.get("fields", {}).items()}
            for d in out.get("documents", [])
        }

    def commit(self, writes: list[dict[str, Any]]) -> None:
        self._call("POST", f"{API}:commit", {"writes": writes})

    def set(self, path: str, fields: dict[str, Any]) -> dict[str, Any]:
        return {"update": {"name": f"{DOCS}/{path}", "fields": {k: encode(v) for k, v in fields.items()}}}

    def patch(self, path: str, fields: dict[str, Any]) -> dict[str, Any]:
        write = self.set(path, fields)
        write["updateMask"] = {"fieldPaths": [f"`{k}`" if not k.isidentifier() else k for k in fields]}
        return write

    def delete(self, path: str) -> dict[str, Any]:
        return {"delete": f"{DOCS}/{path}"}

    # --- test data ---------------------------------------------------------------
    def account(self, email: str) -> Account:
        for uid, student in self.list("students").items():
            if student.get("email") == email.lower():
                return Account(uid=uid, email=email.lower(), full_name=student["fullName"])
        raise AssertionError(f"{email} has never signed in to the app: sign in once on the emulator first")

    def reset(self, me: Account, *, team: str | None = None, leader: bool = False) -> None:
        """Restores the Lab 3 seed, then places `me` in `team` (replacing Minh Le) or in no team.

        The test account is removed from every other team, its notifications are
        cleared, and the waiting-pool candidate is unassigned again.
        """
        # Reuse the seed script's own documents so the suite never drifts from it.
        writes = build_seed_writes()
        writes.append(self.set(f"allowedEmails/{me.email}", {"enabled": True}))

        # Other teams the account joined or created during earlier manual testing,
        # and pool students invited into them (the seed puts those back in the pool).
        gone = {me.uid, *POOL_IDS}
        for team_id, data in self.list("teams").items():
            if team_id not in SEEDED_TEAMS and not set(data.get("memberIds", [])) - gone:
                writes.append(self.delete(f"teams/{team_id}"))  # nobody would be left in it
            elif team_id not in SEEDED_TEAMS and gone & set(data.get("memberIds", [])):
                members = [m for m in data.get("members", []) if m.get("studentId") not in gone]
                writes.append(
                    self.patch(
                        f"teams/{team_id}",
                        {
                            "memberIds": [m for m in data["memberIds"] if m not in gone],
                            "members": members,
                            "leaderId": None if data.get("leaderId") in gone else data.get("leaderId"),
                            "votes": {k: v for k, v in (data.get("votes") or {}).items() if not gone & {k, v}},
                        },
                    )
                )
        for notification_id in self.list(f"students/{me.uid}/notifications"):
            writes.append(self.delete(f"students/{me.uid}/notifications/{notification_id}"))
        # A pool record left by place_in_pool would be the first candidate a leader invites.
        writes.append(self.delete(f"waitingPool/{me.uid}"))
        self.commit(writes)

        if team == "team_ai04":
            ai04 = self.get("teams/team_ai04")
            members = [me.as_member("Frontend Lead") if m["studentId"] == "s_minh" else m for m in ai04["members"]]
            votes = {k: (me.uid if v == "s_minh" else v) for k, v in ai04["votes"].items()}
            self.commit(
                [
                    self.patch(
                        "teams/team_ai04",
                        {
                            "memberIds": [me.uid if m == "s_minh" else m for m in ai04["memberIds"]],
                            "members": members,
                            "votes": {**votes, me.uid: me.uid} if leader else votes,
                            "leaderId": me.uid if leader else None,
                        },
                    )
                ]
            )
        elif team is not None:
            raise ValueError(f"unsupported team precondition {team!r}")

    def set_allowed(self, me: Account, enabled: bool) -> None:
        self.commit([self.set(f"allowedEmails/{me.email}", {"enabled": enabled})])

    def add_invite(self, me: Account, team_id: str, team_name: str) -> str:
        notification_id = f"invite_{team_id}"
        self.commit(
            [
                self.set(
                    f"students/{me.uid}/notifications/{notification_id}",
                    {
                        "kind": "invite",
                        "title": f"Invite from {team_name}",
                        "body": f"{team_name} invited you to join as Backend developer.",
                        "createdAt": datetime.now(timezone.utc),
                        "read": False,
                        "teamId": team_id,
                        "actionLabel": "View team",
                    },
                )
            ]
        )
        return notification_id

    def send_push(self, me: Account, title: str, body: str, team_id: str) -> str:
        """Sends one FCM message to the device token the app saved for `me` (FCM HTTP v1, like the
        Console's "Send test message"). Returns the message name FCM assigned."""
        token = (self.get(f"students/{me.uid}") or {}).get("fcmToken")
        if not token:
            raise AssertionError("No fcmToken saved: sign in on the device and allow notifications first")
        message = {
            "token": token,
            "notification": {"title": title, "body": body},
            # recipientId lets the background handler store the message without a signed-in isolate.
            "data": {"kind": "system", "teamId": team_id, "actionLabel": "View team", "recipientId": me.uid},
            "android": {"priority": "high"},
        }
        url = f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"
        return self._call("POST", url, {"message": message})["name"]

    def place_in_pool(self, me: Account) -> None:
        """Puts `me` in the Waiting Pool, as the Academic Office does for students left without a
        team at the deadline. The app has no job that does this, so the demo needs it."""
        self.commit(
            [
                self.set(
                    f"waitingPool/{me.uid}",
                    {
                        "fullName": me.full_name,
                        "studentCode": me.email.split("@")[0],
                        "role": "Mobile Developer",
                        "skills": ["Flutter", "Firebase"],
                        "assigned": False,
                        "queueId": "RP-2026-0157",
                        "progress": 0.35,
                        "stage": "Stage 2 of 4 · Role balancing",
                        "expectedResult": datetime.now(timezone.utc) + timedelta(days=2),
                        "preferredRoles": ["Mobile Developer"],
                        "studentsInPool": 38,
                        "contactEmail": "academic@fpt.edu.vn",
                    },
                )
            ]
        )

    def fill_team(self, team_id: str) -> None:
        """Another student takes the last open slot (the race TC-07 recovers from)."""
        team = self.get(f"teams/{team_id}")
        newcomer = {
            "studentId": "s_kim_race",
            "fullName": "Kim Race",
            "studentCode": "SE179999",
            "role": "Backend",
            "skills": ["Go"],
        }
        self.commit(
            [
                self.patch(
                    f"teams/{team_id}",
                    {"memberIds": [*team["memberIds"], newcomer["studentId"]], "members": [*team["members"], newcomer]},
                )
            ]
        )

    def open_team_count(self) -> int:
        return sum(
            1
            for data in self.list("teams").values()
            if not data.get("locked") and len(data.get("memberIds", [])) < int(data.get("capacity", 5))
        )

    def storage_objects(self, prefix: str) -> dict[str, int]:
        """Cloud Storage objects under `prefix`, name -> size in bytes."""
        bucket = f"{PROJECT_ID}.firebasestorage.app"
        query = urllib.parse.urlencode({"prefix": prefix})
        out = self._call("GET", f"https://storage.googleapis.com/storage/v1/b/{bucket}/o?{query}") or {}
        return {item["name"]: int(item["size"]) for item in out.get("items", [])}
