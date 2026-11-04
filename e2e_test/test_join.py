"""TC-06, TC-07: Team Detail and join (SCR_04), Flow 1 happy and alternative paths, on live Firestore."""

import pytest

from conftest import ACCOUNT


@pytest.mark.flow1
async def test_tc06_join_team_with_open_slot(device, backend, me, artemis):
    backend.reset(me)  # FinTech Guard has 2 of 5 members
    device.sign_in(ACCOUNT)

    run = await artemis(
        "Find the team 'FinTech Guard' on the Browse tab, open its details and join it, "
        "confirming in the dialog. After joining, report the team shown on My Team and its member count.",
        'Return JSON: {"joined": bool, "my_team_name": string, "members_text": string}',
    )

    assert run.data["joined"] is True
    assert run.data["my_team_name"] == "FinTech Guard"
    assert "3 of 5" in run.data["members_text"]
    assert "[card_my_team_header]" in run.screen
    # The new member card is below the fold (uiautomator lists visible nodes only);
    # membership is checked in Firestore below.
    assert "join_team" in device.analytics_events()
    # Ground truth: the join transaction reached Firestore.
    team = backend.get("teams/team_fin02")
    assert me.uid in team["memberIds"] and len(team["memberIds"]) == 3


@pytest.mark.flow1
async def test_tc07_team_fills_before_confirming(device, backend, me, artemis):
    backend.reset(me)  # EduSmart Analytics has 4 of 5 members
    device.sign_in(ACCOUNT)

    await artemis(
        "Open 'EduSmart Analytics' from the Browse tab and tap 'Join Team'. "
        "Stop as soon as the confirmation dialog is open. Do not confirm.",
        'Return JSON: {"dialog_open": bool}',
    )
    backend.fill_team("team_edu07")  # another student takes the last slot meanwhile

    run = await artemis(
        "A join confirmation dialog for 'EduSmart Analytics' is open. Confirm it. "
        "Report what the app says happened and whether the Join Team button is still available.",
        'Return JSON: {"joined": bool, "message_title": string, "join_button_enabled": bool, "member_count_text": string}',
    )

    assert run.data["joined"] is False
    assert "just filled up" in run.data["message_title"]
    assert run.data["join_button_enabled"] is False
    assert "[banner_team_filled]" in run.screen
    assert "[join_blocked_reason] This team is full (5/5)." in run.screen
    # Ground truth: the transaction refused the sixth member.
    assert me.uid not in backend.get("teams/team_edu07")["memberIds"]
