"""TC-08, TC-10: Alerts (SCR_09) on Firestore and Profile export to Cloud Storage."""

import re

from conftest import ACCOUNT


async def test_tc08_export_and_upload_team_summary(device, backend, me, artemis):
    backend.reset(me, team="team_ai04")
    device.sign_in(ACCOUNT)
    before = backend.storage_objects(f"reports/{me.uid}/")

    run = await artemis(
        "Open your profile from the avatar at the top right. Under Team summary, tap 'Export & Upload PDF' "
        "and wait until the upload finishes. Report the uploaded file name and its size.",
        'Return JSON: {"uploaded": bool, "file_name": string, "size_kb": int}',
    )

    assert run.data["uploaded"] is True
    assert re.fullmatch(r"team-ai-04-\d{8}-\d{4}\.pdf", run.data["file_name"])
    assert run.data["size_kb"] > 0
    # The banner's accessible text is the download URL of reports/{uid}/{file}.
    assert "[export_done] Uploaded" in run.screen and "https://firebasestorage.googleapis.com/" in run.screen
    assert f"reports%2F{me.uid}%2F{run.data['file_name']}" in run.screen
    assert "export_report" in device.analytics_events()
    # Ground truth: a new object exists in Cloud Storage under the owner's folder.
    new = set(backend.storage_objects(f"reports/{me.uid}/")) - set(before)
    assert f"reports/{me.uid}/{run.data['file_name']}" in new


async def test_tc10_decline_invite_then_undo(device, backend, me, artemis):
    backend.reset(me)
    invite = backend.add_invite(me, "team_fin02", "FinTech Guard")
    device.sign_in(ACCOUNT)

    run = await artemis(
        "Tap the notification bell icon at the top right to open Alerts and switch to the Invites filter. Decline the invite from FinTech Guard, "
        "then use Undo in the message at the bottom of the screen. Report how many invites are listed "
        "right after declining and after undoing.",
        'Return JSON: {"invites_after_decline": int, "invites_after_undo": int, "invite_team": string}',
    )

    assert run.data["invites_after_decline"] == 0
    assert run.data["invites_after_undo"] == 1
    assert "FinTech Guard" in run.data["invite_team"]
    assert "Invites (1)" in run.screen
    # Ground truth: Undo restored the notification document in Firestore.
    assert backend.get(f"students/{me.uid}/notifications/{invite}") is not None

