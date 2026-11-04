#!/usr/bin/env python3
"""Seed all Cloud Firestore collections for PRM393 Lab 3.

Populates:
  - configuration/registration (semester, opensAt, closesAt, windowHours)
  - allowedEmails (FPT student accounts and test accounts)
  - teams (5 teams matching Lab 2 UI/UX, with memberIds, members, votes, locked, invitesSent)
  - waitingPool (pool candidate s_khanh with assigned: false for Flow 3 recovery)
  - students (pre-seeded metadata for test accounts)

Usage:
  1. Using Google Cloud access token:
       python tool/seed_firestore_lab3.py --token <OAUTH_ACCESS_TOKEN>

  2. Using Service Account Key JSON:
       python tool/seed_firestore_lab3.py --key path/to/serviceAccountKey.json

  3. Dry run / view payload:
       python tool/seed_firestore_lab3.py
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone, timedelta
from pathlib import Path

PROJECT_ID = "prm393-lab-3-exematching"
DOC_PREFIX = f"projects/{PROJECT_ID}/databases/(default)/documents"
ENDPOINT_URL = f"https://firestore.googleapis.com/v1/{DOC_PREFIX}"
BASE_URL = DOC_PREFIX

ALLOWED_EMAILS = [
    "minh.le@fpt.edu.vn",
    "an.tran@fpt.edu.vn",
    "hoang.tran@fpt.edu.vn",
    "quynh.nguyen@fpt.edu.vn",
    "lam.pham@fpt.edu.vn",
    "vy.dang@fpt.edu.vn",
    "bao.pham@fpt.edu.vn",
    "nhi.ho@fpt.edu.vn",
    "tuan.do@fpt.edu.vn",
    "mai.vu@fpt.edu.vn",
    "long.nguyen@fpt.edu.vn",
    "thao.le@fpt.edu.vn",
    "duc.bui@fpt.edu.vn",
    "hai.dang@fpt.edu.vn",
    "kim.tran@fpt.edu.vn",
    "phat.ly@fpt.edu.vn",
    "quang.ha@fpt.edu.vn",
    "bich.ngo@fpt.edu.vn",
    "khanh.vo@fpt.edu.vn",
    "nhanlhse184226@fpt.edu.vn",
    "lamhoangnhan20000@gmail.com",
    "megalit2578@gmail.com",
]

POOL_EXTRA = [
    ("s_pool_linh", "Linh Nguyen", "SE171105", "DevOps", ["Docker", "GitHub Actions"]),
    ("s_pool_nam", "Nam Tran", "SE171118", "QA Engineer", ["Appium", "Pytest"]),
    ("s_pool_trang", "Trang Le", "SE171124", "Mobile Developer", ["Flutter", "Kotlin"]),
]
POOL_IDS = ["s_khanh", *(p[0] for p in POOL_EXTRA)]


def build_seed_writes() -> list[dict]:
    writes = []
    now = datetime.now(timezone.utc)
    opens_at = (now - timedelta(days=7)).isoformat()
    closes_at = (now + timedelta(days=30)).isoformat()
    expected_result = (now + timedelta(days=2)).isoformat()

    # 1. configuration/registration
    writes.append({
        "update": {
            "name": f"{BASE_URL}/configuration/registration",
            "fields": {
                "semester": {"stringValue": "Spring 2026"},
                "opensAt": {"timestampValue": opens_at},
                "closesAt": {"timestampValue": closes_at},
                "windowHours": {"integerValue": "230"},
            },
        }
    })

    # 2. allowedEmails
    for email in ALLOWED_EMAILS:
        doc_id = urllib.parse.quote(email.lower(), safe="@._-+")
        writes.append({
            "update": {
                "name": f"{BASE_URL}/allowedEmails/{doc_id}",
                "fields": {
                    "enabled": {"booleanValue": True},
                },
            }
        })

    # 3. waitingPool / s_khanh
    writes.append({
        "update": {
            "name": f"{BASE_URL}/waitingPool/s_khanh",
            "fields": {
                "fullName": {"stringValue": "Khanh Vo"},
                "studentCode": {"stringValue": "SE171002"},
                "role": {"stringValue": "Embedded / IoT"},
                "skills": {
                    "arrayValue": {
                        "values": [
                            {"stringValue": "C++"},
                            {"stringValue": "ROS2"},
                            {"stringValue": "Raspberry Pi"},
                        ]
                    }
                },
                "assigned": {"booleanValue": False},
                "queueId": {"stringValue": "RP-2026-0142"},
                "progress": {"doubleValue": 0.84},
                "stage": {"stringValue": "Stage 3 of 4 · Skill matching"},
                "expectedResult": {"timestampValue": expected_result},
                "preferredRoles": {
                    "arrayValue": {
                        "values": [{"stringValue": "Embedded / IoT"}]
                    }
                },
                "studentsInPool": {"integerValue": "38"},
                "contactEmail": {"stringValue": "academic@fpt.edu.vn"},
            },
        }
    })

    # 3b. More unmatched students, so a newly created team (1 member) can still
    # reach the 4-member minimum from the pool in the Flow 3 demo. Their ids sort
    # after s_khanh, so AI-04's pool invite still picks Khanh Vo first.
    for pool_id, name, code, role, skills in POOL_EXTRA:
        writes.append({
            "update": {
                "name": f"{BASE_URL}/waitingPool/{pool_id}",
                "fields": {
                    "fullName": {"stringValue": name},
                    "studentCode": {"stringValue": code},
                    "role": {"stringValue": role},
                    "skills": {"arrayValue": {"values": [{"stringValue": s} for s in skills]}},
                    "assigned": {"booleanValue": False},
                    "queueId": {"stringValue": f"RP-2026-{code[-4:]}"},
                    "progress": {"doubleValue": 0.6},
                    "stage": {"stringValue": "Stage 2 of 4 · Role balancing"},
                    "expectedResult": {"timestampValue": expected_result},
                    "preferredRoles": {"arrayValue": {"values": [{"stringValue": role}]}},
                    "studentsInPool": {"integerValue": "38"},
                    "contactEmail": {"stringValue": "academic@fpt.edu.vn"},
                },
            }
        })

    # 4. teams
    teams_data = [
        {
            "id": "team_ai04",
            "code": "AI-04",
            "name": "Team AI-04",
            "topic": "Autonomous Campus Delivery Drone with Vision AI",
            "description": "An AI-driven delivery drone for FPT University campus that reads landmarks with on-board computer vision and plans safe routes between buildings.",
            "category": "AI/ML",
            "tags": ["Python", "PyTorch", "ROS2", "Flutter"],
            "supervisor": "Dr. Nguyen Thanh (AI Lab)",
            "capacity": 5,
            "leaderId": None,
            "locked": False,
            "invitesSent": 0,
            "members": [
                {
                    "studentId": "s_minh",
                    "fullName": "Minh Le",
                    "studentCode": "SE160234",
                    "role": "Frontend Lead",
                    "skills": ["Flutter", "React", "UI/UX"],
                },
                {
                    "studentId": "s_hoang",
                    "fullName": "Hoang Tran",
                    "studentCode": "SE170456",
                    "role": "AI / Vision Specialist",
                    "skills": ["Python", "TensorFlow", "OpenCV"],
                },
                {
                    "studentId": "s_quynh",
                    "fullName": "Quynh Nguyen",
                    "studentCode": "SE170189",
                    "role": "Backend Developer",
                    "skills": ["FastAPI", "Docker", "PostgreSQL"],
                },
            ],
            "memberIds": ["s_minh", "s_hoang", "s_quynh"],
            "openRoles": ["Embedded / IoT", "DevOps"],
            "votes": {"s_quynh": "s_minh", "s_hoang": "s_hoang"},
        },
        {
            "id": "team_fin02",
            "code": "FIN-02",
            "name": "FinTech Guard",
            "topic": "Blockchain Student Credential Verification",
            "description": "Tamper-proof academic records that employers can verify with a QR code, backed by a permissioned blockchain.",
            "category": "Web/Cloud",
            "tags": ["Solidity", "React", "Node.js"],
            "supervisor": "MSc. Le Hoang Long",
            "capacity": 5,
            "leaderId": None,
            "locked": False,
            "invitesSent": 0,
            "members": [
                {
                    "studentId": "s_lam",
                    "fullName": "Lam Pham",
                    "studentCode": "SE170311",
                    "role": "Blockchain Developer",
                    "skills": ["Solidity", "Go"],
                },
                {
                    "studentId": "s_vy",
                    "fullName": "Vy Dang",
                    "studentCode": "SE170522",
                    "role": "Frontend Developer",
                    "skills": ["React", "TypeScript"],
                },
            ],
            "memberIds": ["s_lam", "s_vy"],
            "openRoles": ["Backend", "Mobile & Frontend"],
            "votes": {},
        },
        {
            "id": "team_edu07",
            "code": "EDU-07",
            "name": "EduSmart Analytics",
            "topic": "Adaptive Learning Recommendation Engine for STEM Students",
            "description": "Recommends study paths from LMS activity and quiz results, with a dashboard for lecturers.",
            "category": "AI/ML",
            "tags": ["Python", "React", "PostgreSQL"],
            "supervisor": "Dr. Tran Minh Chau",
            "capacity": 5,
            "leaderId": None,
            "locked": False,
            "invitesSent": 0,
            "members": [
                {
                    "studentId": "s_bao",
                    "fullName": "Bao Pham",
                    "studentCode": "SE170777",
                    "role": "Data Scientist",
                    "skills": ["Python", "scikit-learn"],
                },
                {
                    "studentId": "s_nhi",
                    "fullName": "Nhi Ho",
                    "studentCode": "SE170812",
                    "role": "Frontend Developer",
                    "skills": ["React"],
                },
                {
                    "studentId": "s_tuan",
                    "fullName": "Tuan Do",
                    "studentCode": "SE170845",
                    "role": "Backend Developer",
                    "skills": ["Django"],
                },
                {
                    "studentId": "s_mai",
                    "fullName": "Mai Vu",
                    "studentCode": "SE170901",
                    "role": "QA Engineer",
                    "skills": ["Selenium"],
                },
            ],
            "memberIds": ["s_bao", "s_nhi", "s_tuan", "s_mai"],
            "openRoles": ["Backend"],
            "votes": {},
        },
        {
            "id": "team_web11",
            "code": "WEB-11",
            "name": "GreenRoute",
            "topic": "Smart Campus Parking and Shuttle Planner",
            "description": "Live parking availability and shuttle times for the Hoa Lac campus, with a booking flow for staff.",
            "category": "Web/Cloud",
            "tags": ["React", "Spring Boot", "MySQL"],
            "supervisor": "MSc. Pham Van Hai",
            "capacity": 5,
            "leaderId": None,
            "locked": False,
            "invitesSent": 0,
            "members": [
                {
                    "studentId": "s_long",
                    "fullName": "Long Nguyen",
                    "studentCode": "SE170120",
                    "role": "Backend Developer",
                    "skills": ["Spring Boot"],
                },
                {
                    "studentId": "s_thao",
                    "fullName": "Thao Le",
                    "studentCode": "SE170133",
                    "role": "Frontend Developer",
                    "skills": ["React"],
                },
                {
                    "studentId": "s_duc",
                    "fullName": "Duc Bui",
                    "studentCode": "SE170146",
                    "role": "DevOps",
                    "skills": ["AWS"],
                },
            ],
            "memberIds": ["s_long", "s_thao", "s_duc"],
            "openRoles": ["Backend", "Mobile"],
            "votes": {},
        },
        {
            "id": "team_mob03",
            "code": "MOB-03",
            "name": "Campus Bite",
            "topic": "Canteen Pre-order and Pickup App",
            "description": "Order canteen meals ahead of class and pick them up with a QR code.",
            "category": "Mobile",
            "tags": ["Flutter", "Firebase", "Node.js"],
            "supervisor": "MSc. Nguyen Thu Ha",
            "capacity": 5,
            "leaderId": "s_hai",
            "locked": False,
            "invitesSent": 0,
            "members": [
                {"studentId": "s_hai", "fullName": "Hai Dang", "studentCode": "SE170201", "role": "Mobile Developer", "skills": ["Flutter"]},
                {"studentId": "s_kim", "fullName": "Kim Tran", "studentCode": "SE170214", "role": "Backend Developer", "skills": ["Node.js"]},
                {"studentId": "s_phat", "fullName": "Phat Ly", "studentCode": "SE170227", "role": "UI/UX Designer", "skills": ["Figma"]},
                {"studentId": "s_quang", "fullName": "Quang Ha", "studentCode": "SE170240", "role": "QA Engineer", "skills": ["Appium"]},
                {"studentId": "s_bich", "fullName": "Bich Ngo", "studentCode": "SE170253", "role": "Business Analyst", "skills": ["UML"]},
            ],
            "memberIds": ["s_hai", "s_kim", "s_phat", "s_quang", "s_bich"],
            "openRoles": [],
            "votes": {"s_hai": "s_hai", "s_kim": "s_hai", "s_phat": "s_hai"},
        },
    ]

    for team in teams_data:
        team_id = team["id"]
        members_val = []
        for m in team["members"]:
            members_val.append({
                "mapValue": {
                    "fields": {
                        "studentId": {"stringValue": m["studentId"]},
                        "fullName": {"stringValue": m["fullName"]},
                        "studentCode": {"stringValue": m["studentCode"]},
                        "role": {"stringValue": m["role"]},
                        "skills": {"arrayValue": {"values": [{"stringValue": s} for s in m["skills"]]}},
                    }
                }
            })

        member_ids_val = [{"stringValue": mid} for mid in team["memberIds"]]
        open_roles_val = [{"stringValue": r} for r in team["openRoles"]]
        tags_val = [{"stringValue": t} for t in team["tags"]]
        votes_map = {k: {"stringValue": v} for k, v in team["votes"].items()}

        fields = {
            "code": {"stringValue": team["code"]},
            "name": {"stringValue": team["name"]},
            "topic": {"stringValue": team["topic"]},
            "description": {"stringValue": team["description"]},
            "category": {"stringValue": team["category"]},
            "tags": {"arrayValue": {"values": tags_val}},
            "supervisor": {"stringValue": team["supervisor"]},
            "capacity": {"integerValue": str(team["capacity"])},
            "locked": {"booleanValue": team["locked"]},
            "invitesSent": {"integerValue": str(team["invitesSent"])},
            "memberIds": {"arrayValue": {"values": member_ids_val}},
            "members": {"arrayValue": {"values": members_val}},
            "openRoles": {"arrayValue": {"values": open_roles_val}},
            "votes": {"mapValue": {"fields": votes_map}},
        }
        if team["leaderId"]:
            fields["leaderId"] = {"stringValue": team["leaderId"]}
        else:
            fields["leaderId"] = {"nullValue": None}

        writes.append({
            "update": {
                "name": f"{BASE_URL}/teams/{team_id}",
                "fields": fields,
            }
        })

    return writes


def token_from_service_account(key_path: Path) -> str:
    """Generate an OAuth2 access token from a service account JSON using cryptography."""
    try:
        from cryptography.hazmat.primitives import serialization, hashes
        from cryptography.hazmat.primitives.asymmetric import padding
    except ImportError:
        raise RuntimeError("Install cryptography: pip install cryptography")

    with open(key_path, "r", encoding="utf-8") as f:
        sa = json.load(f)

    private_key_pem = sa["private_key"].encode("utf-8")
    private_key = serialization.load_pem_private_key(private_key_pem, password=None)

    now = int(time.time())
    header = {"alg": "RS256", "typ": "JWT"}
    claim_set = {
        "iss": sa["client_email"],
        "scope": "https://www.googleapis.com/auth/datastore",
        "aud": "https://oauth2.googleapis.com/token",
        "exp": now + 3600,
        "iat": now,
    }

    def b64url(data: bytes) -> str:
        return base64.urlsafe_b64encode(data).rstrip(b"=").decode("utf-8")

    unsigned_jwt = f"{b64url(json.dumps(header).encode('utf-8'))}.{b64url(json.dumps(claim_set).encode('utf-8'))}"
    signature = private_key.sign(unsigned_jwt.encode("utf-8"), padding.PKCS1v15(), hashes.SHA256())
    signed_jwt = f"{unsigned_jwt}.{b64url(signature)}"

    # Exchange JWT for access token
    post_data = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": signed_jwt,
    }).encode("utf-8")
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=post_data, method="POST")
    with urllib.request.urlopen(req) as resp:
        res = json.load(resp)
        return res["access_token"]


def commit_writes(token: str, writes: list[dict]) -> None:
    batch_size = 400
    for i in range(0, len(writes), batch_size):
        chunk = writes[i:i + batch_size]
        req = urllib.request.Request(
            f"{ENDPOINT_URL}:batchWrite",
            data=json.dumps({"writes": chunk}).encode("utf-8"),
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req) as resp:
            data = json.load(resp)
            results = data.get("writeResults", [])
            print(f"Batch {i//batch_size + 1}: successfully committed {len(results)}/{len(chunk)} writes.")


def main():
    parser = argparse.ArgumentParser(description="Seed Cloud Firestore for Lab 3")
    parser.add_argument("--key", type=Path, help="Path to Firebase Service Account Key JSON")
    parser.add_argument("--token", type=str, help="Google OAuth2 Access Token")
    parser.add_argument("--dump", action="store_true", help="Dump JSON payload to seed_output.json")
    args = parser.parse_args()

    writes = build_seed_writes()
    print(f"Constructed {len(writes)} total Firestore documents across 4 collections.")

    if args.dump:
        out_file = Path("seed_output.json")
        with open(out_file, "w", encoding="utf-8") as f:
            json.dump({"writes": writes}, f, indent=2)
        print(f"Payload dumped to {out_file.resolve()}")
        return

    token = args.token
    if not token and args.key:
        print(f"Deriving OAuth token from Service Account Key: {args.key}")
        token = token_from_service_account(args.key)

    if not token:
        # Check ~/.config/configstore/firebase-tools.json from firebase login
        try:
            cfg_path = Path.home() / ".config" / "configstore" / "firebase-tools.json"
            if cfg_path.exists():
                cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
                tokens = cfg.get("tokens", {})
                if "access_token" in tokens:
                    token = tokens["access_token"]
                    print("Obtained access token from Firebase CLI login!")
                elif "refresh_token" in tokens:
                    post_data = urllib.parse.urlencode({
                        "client_id": "563584335869-fgrhgmd47bqnekij5i8b5pr03ho859e1.apps.googleusercontent.com",
                        "grant_type": "refresh_token",
                        "refresh_token": tokens["refresh_token"],
                    }).encode("utf-8")
                    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=post_data, method="POST")
                    with urllib.request.urlopen(req) as resp:
                        token = json.load(resp)["access_token"]
                        print("Obtained fresh access token from Firebase CLI login!")
        except Exception:
            pass

    if not token:
        # Check gcloud if installed
        try:
            import subprocess
            token = subprocess.check_output(["gcloud", "auth", "print-access-token"], text=True).strip()
            print("Obtained access token via local gcloud CLI.")
        except Exception:
            pass

    if not token:
        print("\n[!] No access token or service account key provided.")
        print("To apply changes to Firestore:")
        print("  1. In Firebase Console: Project Settings -> Service accounts -> Generate new private key")
        print("     Then run: python tool/seed_firestore_lab3.py --key path/to/key.json")
        print("  2. Or run with an access token:")
        print("     python tool/seed_firestore_lab3.py --token <TOKEN>")
        print("  3. Or inspect the payload:")
        print("     python tool/seed_firestore_lab3.py --dump\n")
        return

    print(f"Applying writes to project {PROJECT_ID}...")
    commit_writes(token, writes)
    print("\n[SUCCESS] Cloud Firestore seeding completed successfully!")


if __name__ == "__main__":
    main()

