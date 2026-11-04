"""TC-10, TC-11: Review & Lock (SCR_07), Flow 3 error, recovery and native share sheet, on live Firestore."""

import re

import pytest

from conftest import ACCOUNT


@pytest.mark.flow3
async def test_tc10_lock_blocked_then_recovered_from_pool(device, backend, me, artemis):
    # The test account is the elected leader of Team AI-04 (3 of 5); Khanh Vo waits in the pool.
    backend.reset(me, team="team_ai04", leader=True)
    device.sign_in(ACCOUNT)

    run = await artemis(
        "On My Team, open 'Review & Lock'. Note the title of the red error banner near the top of the screen "
        "(the bold first line of that red box, not the smaller hint under the Lock button). "
        "Recover from it: invite students from the Waiting Pool, then wait until a new member joins "
        "(it takes a few seconds). When every check is done, lock the roster and confirm. "
        "Report the error you saw first, the name of the student who joined, and the confirmation code.",
        'Return JSON: {"first_error": string, "joined_member": string, "locked": bool, "confirmation_code": string}',
    )

    assert run.data["first_error"].startswith("Can't lock yet")
    assert run.data["joined_member"] == "Khanh Vo"
    assert run.data["locked"] is True
    assert re.fullmatch(r"CM-AI04-[0-9A-F]{4}", run.data["confirmation_code"])
    assert "[state_locked]" in run.screen
    assert run.data["confirmation_code"] in run.screen
    events = device.analytics_events()
    assert "invite_pool" in events and "lock_roster" in events
    # Ground truth: pool assignment and lock are stored in Firestore.
    team = backend.get("teams/team_ai04")
    assert "s_khanh" in team["memberIds"] and team["locked"] is True
    assert team["lockCode"] == run.data["confirmation_code"]
    assert backend.get("waitingPool/s_khanh")["assigned"] is True


@pytest.mark.flow3
@pytest.mark.native
async def test_tc11_share_team_link_opens_android_share_sheet(device, backend, me, artemis):
    backend.reset(me, team="team_ai04", leader=True)
    device.sign_in(ACCOUNT)

    run = await artemis(
        "On My Team, open 'Review & Lock' and tap 'Share Team Link'. "
        "Stop when the Android share sheet is open and report what it shows. Do not share to any app.",
        'Return JSON: {"share_sheet_open": bool, "shared_text_mentions_team": bool}',
        timeout=600,
    )

    assert run.data["share_sheet_open"] is True
    assert run.data["shared_text_mentions_team"] is True
    # Ground truth: the system chooser (outside the app) is in the foreground.
    assert "intentresolver" in device.foreground_activity(expect="intentresolver")
    device.shell("input", "keyevent", "KEYCODE_BACK")  # close the sheet without sharing
