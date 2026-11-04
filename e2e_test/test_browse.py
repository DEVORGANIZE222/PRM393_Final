"""TC-03, TC-04, TC-05: Browse Teams (SCR_03), Flow 1 entry and its states, on live Firestore."""

import pytest

from conftest import ACCOUNT


@pytest.mark.flow1
async def test_tc03_search_and_filter(device, backend, me, artemis):
    backend.reset(me)  # a student with no team
    device.sign_in(ACCOUNT)

    run = await artemis(
        "Open the Browse tab. Turn on the 'AI/ML' filter chip and keep 'Open Slots' on. "
        "Then search for 'drone'. Report the number of teams the list says it found and the name of each team.",
        'Return JSON: {"result_count": int, "team_names": [string]}',
    )

    assert run.data["result_count"] == 1
    assert any("AI-04" in name for name in run.data["team_names"])
    assert "[browse_result_count] 1 team with open slots" in run.screen
    assert "search_teams" in device.analytics_events()


@pytest.mark.flow1
async def test_tc04_empty_state_and_clear_filters(device, backend, me, artemis):
    backend.reset(me)
    device.sign_in(ACCOUNT)
    open_teams = backend.open_team_count()  # ground truth from Firestore

    run = await artemis(
        "Open the Browse tab and search for 'quantum'. Read the message shown when nothing matches. "
        "Then use the button in that message to clear the filters, and count the teams listed afterwards.",
        'Return JSON: {"empty_title": string, "teams_after_clearing": int}',
    )

    assert run.data["empty_title"] == "No teams match your search"
    assert run.data["teams_after_clearing"] == open_teams
    # The agent may leave the list scrolled down; read the count line from the top.
    device.scroll_to_top()
    assert f"[browse_result_count] {open_teams} teams with open slots" in device.screen_text()


@pytest.mark.flow1
async def test_tc05_offline_error_and_retry(device, backend, me, artemis):
    backend.reset(me)
    device.sign_in(ACCOUNT)
    open_teams = backend.open_team_count()
    device.set_network(False)

    first = await artemis(
        "Open the Browse tab and wait for it to finish loading. Report the error title and message shown.",
        'Return JSON: {"error_title": string, "error_message": string, "has_try_again_button": bool}',
    )
    assert first.data["error_title"] == "Can't connect right now"
    assert first.data["has_try_again_button"] is True
    assert "[state_error]" in first.screen

    device.set_network(True)
    second = await artemis(
        "The phone is back online. On the Browse screen, tap 'Try Again' and report how many teams are listed.",
        'Return JSON: {"result_count": int}',
    )
    assert second.data["result_count"] == open_teams
    assert "[state_error]" not in second.screen
