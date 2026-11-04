"""Shared fixtures: the ARTEMIS client, the device, repeated runs and evidence.

Environment:
  ARTEMIS_BASE_URL   daemon URL (default http://127.0.0.1:8000, started by `uv run artemis ui`)
  ARTEMIS_PROFILE    flash (default) or pro
  DEVICE_SERIAL      adb serial (default emulator-5554)
  E2E_RUNS           runs per test case (default 3)
  E2E_COOLDOWN       seconds to wait before each ARTEMIS task (default 60), so the Gemini
                     free tier's per-minute request quota is not already spent
  E2E_ACCOUNT        Google account signed in on the device and in Firestore allowedEmails
                     (default megalit2578@gmail.com)
  FIREBASE_TOKEN     optional OAuth token for Firestore preconditions; defaults to the
                     Firebase CLI login (see backend.py)
"""

from __future__ import annotations

import json
import os
import re
import time
import urllib.request
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

# Automatically load .env from e2e_test/.env or project root .env
for _env_path in [Path(__file__).parent / ".env", Path(__file__).parent.parent / ".env"]:
    if _env_path.exists():
        for _line in _env_path.read_text(encoding="utf-8").splitlines():
            _line = _line.strip()
            if _line and not _line.startswith("#") and "=" in _line:
                _k, _v = _line.split("=", 1)
                _k, _v = _k.strip(), _v.strip().strip("'\"")
                if _k and _k not in os.environ:
                    os.environ[_k] = _v

import pytest
from artemis_client import ArtemisClient

from backend import Account, Backend
from device import PACKAGE, Device

BASE_URL = os.environ.get("ARTEMIS_BASE_URL", "http://127.0.0.1:8000")
PROFILE = os.environ.get("ARTEMIS_PROFILE", "flash")
SERIAL = os.environ.get("DEVICE_SERIAL", "emulator-5554")
RUNS = int(os.environ.get("E2E_RUNS", "3"))
COOLDOWN = float(os.environ.get("E2E_COOLDOWN", "60"))
EVIDENCE = Path(__file__).parent / "evidence"

# The real Google account added on the emulator. Each test case uses backend.reset()
# to give it the role it needs: Minh Le's seat in Team AI-04, or a student with no team.
ACCOUNT = os.environ.get("E2E_ACCOUNT", "megalit2578@gmail.com")


def pytest_generate_tests(metafunc: pytest.Metafunc) -> None:
    # Every test case runs RUNS times; each run is reported separately.
    if "attempt" in metafunc.fixturenames:
        metafunc.parametrize("attempt", range(1, RUNS + 1), ids=lambda n: f"run{n}")


@pytest.fixture(scope="session")
def device() -> Device:
    return Device(SERIAL)


@pytest.fixture(scope="session")
def backend() -> Backend:
    return Backend()


@pytest.fixture(scope="session")
def me(backend: Backend, device: Device) -> Account:
    accounts = device.shell("dumpsys", "account")
    assert ACCOUNT in accounts, f"Add the Google account {ACCOUNT} on {SERIAL} (Settings > Accounts) first"
    return backend.account(ACCOUNT)


@pytest.fixture(scope="session")
def client() -> ArtemisClient:
    return ArtemisClient(BASE_URL, device_serial=SERIAL, default_profile=PROFILE)


def parse_output(output: Any) -> dict[str, Any]:
    """The Outputter's answer as a dict: accepts a dict, JSON text or JSON inside prose/markdown."""
    if isinstance(output, dict):
        return output
    text = output if isinstance(output, str) else json.dumps(output)
    for candidate in re.findall(r"\{.*\}", text, flags=re.DOTALL):
        try:
            value = json.loads(candidate)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            return value
    raise AssertionError(f"ARTEMIS output has no JSON object: {text[:500]!r}")


def _get(path: str) -> Any:
    with urllib.request.urlopen(f"{BASE_URL}{path}", timeout=30) as response:
        return json.load(response)


def final_report(task_id: str, sdk_output: Any) -> Any:
    """The agent's answer for a finished task.

    Pro runs the Outputter, which saves `output.md` as a session note. Flash has no
    Outputter (ARTEMIS ignores `expected_output` for Flash), so its answer is the
    explanation of the final `report_task_status` step; the goal asks for JSON there.
    """
    if sdk_output:
        return sdk_output
    notes = _get(f"/api/sessions/{task_id}/notes").get("notes", {})
    if "output.md" in notes:
        return notes["output.md"]
    for step in reversed(_get(f"/api/sessions/{task_id}/steps")):
        action = step.get("action_taken") or {}
        if action.get("action") == "report_task_status":
            return action.get("args", {}).get("explanation")
    return None


@dataclass
class Run:
    result: Any
    data: dict[str, Any]
    screen: str
    folder: Path


@pytest.fixture
def artemis(client: ArtemisClient, device: Device, request: pytest.FixtureRequest, attempt: int):
    """Runs one goal, saves evidence, and returns the parsed output plus the real screen."""
    state = device.adb("get-state", check=False).strip()
    assert state == "device", f"{SERIAL} is {state or 'not connected'}: restart the emulator before running the suite"
    folder = EVIDENCE / request.node.originalname / f"run{attempt}"
    folder.mkdir(parents=True, exist_ok=True)

    async def run(goal: str, expected_output: str, *, timeout: float = 900) -> Run:
        time.sleep(COOLDOWN)
        started = datetime.now()
        result = await client.run(
            f"{goal}\nWhen you finish, report the task as completed. The explanation of that final report must be "
            f"only this JSON object with the values you observed, and no other words: "
            f"{expected_output.removeprefix('Return JSON: ')}",
            profile=PROFILE,
            device_serial=SERIAL,
            locked_app_package=PACKAGE,
            expected_output=expected_output,
            enable_outputter=True,
            timeout=timeout,
        )
        screen = device.screen_text()
        device.screenshot(folder / "final.png")
        (folder / "screen.txt").write_text(screen, encoding="utf-8")
        (folder / "analytics.txt").write_text("\n".join(device.analytics_events()), encoding="utf-8")
        record = {
            "test": request.node.nodeid,
            "attempt": attempt,
            "profile": PROFILE,
            "trace_id": result.trace_id,
            "status": result.status,
            "turns": result.turns,
            "started": started.isoformat(timespec="seconds"),
            "seconds": round((datetime.now() - started).total_seconds(), 1),
            "goal": goal,
            "expected_output": expected_output,
            "output": (output := final_report(result.trace_id, result.output)),
            "error": result.error,
        }
        (folder / "result.json").write_text(json.dumps(record, indent=2, ensure_ascii=False, default=str), "utf-8")
        assert result.succeeded, f"ARTEMIS task {result.trace_id} ended {result.status}: {result.error}"
        return Run(result=result, data=parse_output(output), screen=screen, folder=folder)

    yield run
    device.set_network(True)  # never leave the emulator offline after a failed test
