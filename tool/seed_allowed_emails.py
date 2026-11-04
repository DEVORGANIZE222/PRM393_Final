#!/usr/bin/env python3
"""Seed the EXE201 Google-account allowlist in Cloud Firestore.

The script reads the roster directly and writes only an ``enabled: true`` flag
per document. It never copies the roster into the mobile application or logs
individual email addresses. Run it from an authenticated Google Cloud Shell:

  python3 tool/seed_allowed_emails.py "FA26_EXE201 _ Group List.xlsx"
  python3 tool/seed_allowed_emails.py "FA26_EXE201 _ Group List.xlsx" --apply

The first command is a dry run. ``--apply`` requires Cloud IAM permission to
write Firestore documents in the specified project.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from collections.abc import Iterable
from pathlib import Path


PROJECT_ID = "prm393-lab-3-exematching"
SHEET_NAME = "FA26_EXE201 | Group List"
EXTRA_EMAILS = {"nhanlhse184226@fpt.edu.vn", "lamhoangnhan20000@gmail.com"}
NS = {
    "main": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "rel": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "pkg": "http://schemas.openxmlformats.org/package/2006/relationships",
}
EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _column(cell_reference: str) -> int:
    letters = "".join(char for char in cell_reference if char.isalpha())
    result = 0
    for char in letters:
        result = result * 26 + ord(char) - ord("A") + 1
    return result - 1


def _shared_strings(archive: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in archive.namelist():
        return []
    root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    return ["".join(node.itertext()) for node in root.findall("main:si", NS)]


def _sheet_path(archive: zipfile.ZipFile, desired_name: str) -> str:
    workbook = ET.fromstring(archive.read("xl/workbook.xml"))
    relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    targets = {item.attrib["Id"]: item.attrib["Target"] for item in relationships.findall("pkg:Relationship", NS)}
    for sheet in workbook.findall("main:sheets/main:sheet", NS):
        if sheet.attrib.get("name") == desired_name:
            target = targets[sheet.attrib["{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"]]
            return "xl/" + target.lstrip("/")
    raise ValueError(f"Worksheet not found: {desired_name}")


def _rows(archive: zipfile.ZipFile, sheet_path: str, shared: list[str]) -> Iterable[dict[int, str]]:
    root = ET.fromstring(archive.read(sheet_path))
    for row in root.findall(".//main:sheetData/main:row", NS):
        result: dict[int, str] = {}
        for cell in row.findall("main:c", NS):
            value = cell.findtext("main:v", default="", namespaces=NS)
            if cell.attrib.get("t") == "s" and value:
                value = shared[int(value)]
            elif cell.attrib.get("t") == "inlineStr":
                value = "".join(cell.itertext())
            result[_column(cell.attrib["r"])] = value.strip()
        yield result


def roster_emails(workbook_path: Path) -> set[str]:
    with zipfile.ZipFile(workbook_path) as archive:
        shared = _shared_strings(archive)
        rows = iter(_rows(archive, _sheet_path(archive, SHEET_NAME), shared))
        email_column: int | None = None
        emails: set[str] = set()
        for row in rows:
            if email_column is None:
                for column, value in row.items():
                    if "Email (email trên FAP" in value:
                        email_column = column
                        break
                continue
            value = row.get(email_column, "").strip().lower()
            if EMAIL.fullmatch(value):
                emails.add(value)
    if email_column is None:
        raise ValueError("The roster's Email column was not found.")
    return emails | EXTRA_EMAILS


def access_token() -> str:
    return subprocess.check_output(["gcloud", "auth", "print-access-token"], text=True).strip()


def write_batch(token: str, emails: list[str]) -> int:
    writes = []
    for email in emails:
        document_id = urllib.parse.quote(email, safe="@._-+")
        writes.append({
            "update": {
                "name": f"projects/{PROJECT_ID}/databases/(default)/documents/allowedEmails/{document_id}",
                "fields": {"enabled": {"booleanValue": True}},
            }
        })
    request = urllib.request.Request(
        f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents:batchWrite",
        data=json.dumps({"writes": writes}).encode("utf-8"),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request) as response:  # nosec B310: fixed Google API URL
        result = json.load(response)
    if len(result.get("writeResults", [])) != len(writes):
        raise RuntimeError("Firestore did not confirm every document in the batch.")
    return len(writes)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("workbook", type=Path)
    parser.add_argument("--apply", action="store_true", help="write to Cloud Firestore")
    args = parser.parse_args()

    emails = sorted(roster_emails(args.workbook))
    print(f"Prepared {len(emails)} unique allowed-email records for {PROJECT_ID}.")
    if not args.apply:
        print("Dry run only. Re-run with --apply after Firestore Rules have been verified and published.")
        return 0

    token = access_token()
    written = 0
    for start in range(0, len(emails), 500):
        written += write_batch(token, emails[start : start + 500])
        print(f"Confirmed {written}/{len(emails)} records.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Seed failed: {error}", file=sys.stderr)
        raise SystemExit(1)
