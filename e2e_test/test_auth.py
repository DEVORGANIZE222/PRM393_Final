"""TC-01, TC-02: Sign In (SCR_01) with Firebase Authentication and the allowedEmails roster."""

from conftest import ACCOUNT


async def test_tc01_account_not_on_roster_is_rejected(device, backend, me, artemis):
    backend.reset(me)
    backend.set_allowed(me, False)  # the same Google account, removed from the class roster
    try:
        device.reset_app()
        device.launch()
        device.wait_for(id="btn_google_sign_in", timeout=40)

        run = await artemis(
            f"Tap 'Continue with Google' and choose the account {ACCOUNT} in the Google account chooser. "
            "Then read the title of the error message that appeared after you chose the account "
            "(not the permanent hint card below the button).",
            'Return JSON: {"signed_in": bool, "error_title": string, "error_mentions_email": bool}',
        )
    finally:
        backend.set_allowed(me, True)

    assert run.data["signed_in"] is False
    assert "not on the class roster" in run.data["error_title"].lower()
    assert run.data["error_mentions_email"] is True
    # Ground truth: still on Sign In, with the roster banner naming the chosen account.
    assert "[sign_in_message] This account is not on the class roster" in run.screen
    assert ACCOUNT in run.screen
    assert "[btn_google_sign_in]" in run.screen


async def test_tc02_sign_in_with_roster_account(device, backend, me, artemis):
    backend.reset(me, team="team_ai04")
    device.reset_app()
    device.launch()
    device.wait_for(id="btn_google_sign_in", timeout=40)

    run = await artemis(
        f"Sign in with Google using the account {ACCOUNT}. "
        "When the Home screen opens, read the greeting, the registration deadline and the team name.",
        'Return JSON: {"greeting": string, "deadline_text": string, "team_name": string}',
    )

    assert run.data["greeting"].startswith(f"Hi, {me.first_name}")
    assert "left" in run.data["deadline_text"]
    assert "AI-04" in run.data["team_name"]
    assert "[nav_home]" in run.screen and "[card_deadline]" in run.screen
    assert "login" in device.analytics_events()
    # Ground truth: the Firebase user is the roster student whose profile Firestore holds.
    assert backend.get(f"students/{me.uid}")["email"] == ACCOUNT
