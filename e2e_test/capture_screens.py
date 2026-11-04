"""Captures one screenshot per Figma frame into docs/screenshots from the Firebase build.

Uses the same preconditions as the E2E suite (backend.reset, a real Google sign-in), so it
needs the Firebase CLI login and the E2E account on the device:

  DEVICE_SERIAL=emulator-5556 uv run python capture_screens.py

Flutter errors printed while the screens are visited are saved to
docs/screenshots/capture-flutter-errors.txt (empty when every screen laid out cleanly).
SCR_08 (Random Pool) needs registration closed: publish registration_closed=true in Remote
Config, then run `uv run python capture_screens.py pool`.
"""

import os
import re
import sys
import time
from pathlib import Path

from backend import Backend
from conftest import ACCOUNT
from device import PACKAGE, Device

OUT = Path(__file__).resolve().parent.parent / "docs" / "screenshots"
d = Device(os.environ.get("DEVICE_SERIAL", "emulator-5554"))
b = Backend()
me = b.account(ACCOUNT)
errors: list[str] = []


def shot(name: str) -> None:
    time.sleep(1.5)  # let transitions and snackbars settle
    d.screenshot(OUT / f"{name}.png")
    log = d.adb("logcat", "-d", "-s", "flutter")
    found = re.findall(r"(EXCEPTION CAUGHT BY [^\n]*|A RenderFlex overflowed[^\n]*|The relevant error-causing widget was:?[^\n]*\n[^\n]*)", log)
    for e in found:
        errors.append(f"{name}: {e.strip()}")
    d.adb("logcat", "-c")
    print("saved", name, f"({len(found)} errors)" if found else "")


def scroll_down() -> None:
    d.shell("input", "swipe", "540", "1800", "540", "700", "300")


def back() -> None:
    d.shell("input", "keyevent", "KEYCODE_BACK")


def search(term: str) -> None:
    """Replaces the Browse search text; other students' teams can push a team below the fold."""
    d.tap(id="browse_search_field")
    d.shell("input", "keyevent", "KEYCODE_MOVE_END", *["KEYCODE_DEL"] * 20)
    if term:
        d.shell("input", "text", term)
    time.sleep(1.5)  # search is debounced
    back()  # hides the keyboard, which otherwise covers the result cards
    time.sleep(1)


def newcomer() -> None:
    """A student without a team: Flow 1, Alerts."""
    b.reset(me)
    b.add_invite(me, "team_fin02", "FinTech Guard")
    d.reset_app()
    d.launch()
    d.wait_for(id="btn_google_sign_in", timeout=40)
    shot("scr01_sign_in")
    d.tap(id="btn_google_sign_in")
    d.wait_for(text=ACCOUNT, timeout=15)
    shot("scr01_account_picker")
    d.tap(text=ACCOUNT)
    d.wait_for(id="nav_home", timeout=40)
    shot("scr02_home_no_team")

    d.tap(id="nav_browse")
    d.wait_for(id="browse_result_count")
    shot("scr03_browse")
    search("FinTech")
    d.tap(id="btn_view_FIN-02")
    d.wait_for(id="btn_join_team")
    shot("scr04_team_detail")
    d.tap(id="btn_join_team")
    d.wait_for(id="dialog_join_confirm")
    shot("scr04_join_dialog")
    d.tap(id="dialog_join_cancel")
    time.sleep(1)
    back()
    search("quantum")
    d.wait_for(id="state_empty")
    shot("scr03_browse_empty")
    search("")
    d.tap(text="Create")  # the "Want to lead a startup?" banner button has no identifier
    d.wait_for(text="Launch a new startup team")  # the submit button is below the fold
    shot("create_team")
    back()
    d.wait_for(id="browse_result_count")
    alerts_and_tabs()


def hide_keyboard() -> None:
    # Browse gives the search field its focus back after a pushed route closes, and the
    # keyboard then covers the tab bar.
    if "mInputShown=true" in d.shell("dumpsys", "input_method"):
        back()
        time.sleep(1)


def alerts_and_tabs() -> None:
    hide_keyboard()
    d.tap(id="nav_home")
    d.tap(id="btn_open_alerts")
    d.wait_for(id="alert_filters")
    shot("scr09_alerts")
    back()
    hide_keyboard()
    d.tap(id="nav_team")
    shot("scr05_no_team")
    d.tap(id="nav_settings")
    shot("settings")


def tabs() -> None:
    """Only the Alerts, My Team (no team) and Settings shots."""
    b.reset(me)
    b.add_invite(me, "team_fin02", "FinTech Guard")
    d.sign_in(ACCOUNT)
    alerts_and_tabs()


def member_then_leader() -> None:
    """Flows 2 and 3 in Minh Le's seat of Team AI-04."""
    b.reset(me, team="team_ai04")
    d.sign_in(ACCOUNT)
    shot("scr02_home")
    d.tap(id="nav_team")
    d.wait_for(id="btn_vote_leader")
    shot("scr05_my_team")
    d.tap(id="btn_vote_leader")
    d.tap(id=f"candidate_{me.uid}")
    shot("scr06_voting_selected")
    d.tap(id="btn_submit_vote")
    d.wait_for(id="banner_leader_elected")
    time.sleep(4)  # let the snackbar close
    shot("scr06_voting_elected")
    d.tap(id="btn_back_to_team")
    d.wait_for(id="btn_review_lock")
    shot("scr05_my_team_leader")
    d.tap(id="btn_review_lock")
    d.wait_for(id="banner_lock_error")
    shot("scr07_lock_error")
    d.tap(id="btn_invite_pool")
    d.wait_for(id="banner_pool_joined", timeout=40)
    time.sleep(2)
    shot("scr07_pool_member_joined")
    scroll_down()
    d.tap(id="btn_lock_roster")
    d.wait_for(id="dialog_lock_confirm")
    shot("scr07_lock_dialog")
    d.tap(id="dialog_lock_confirm")
    d.wait_for(id="state_locked", timeout=30)
    shot("scr07_locked")
    d.tap(id="btn_back_to_team")
    time.sleep(1)
    d.tap(id="btn_open_profile")
    d.wait_for(id="card_account")
    shot("profile")
    d.tap(id="btn_export_upload")
    d.wait_for(id="export_done", timeout=40)
    shot("profile_export_done")
    scroll_down()
    shot("profile_config_diagnostics")


def pool() -> None:
    b.reset(me)
    b.place_in_pool(me)
    d.sign_in(ACCOUNT)
    shot("scr02_home_registration_closed")
    d.tap(id="btn_view_matching_status")
    d.wait_for(id="card_pool_progress")
    shot("scr08_random_pool")


def crash() -> None:
    """Sends the Profile non-fatal, then the test crash; the crash report goes up on the next launch."""
    b.reset(me, team="team_ai04")
    d.sign_in(ACCOUNT)
    d.tap(id="btn_open_profile")
    d.wait_for(id="card_account")
    for _ in range(3):
        scroll_down()
    d.tap(id="btn_send_non_fatal")
    d.wait_for(id="crash_message", timeout=30)
    shot("profile_non_fatal_sent")
    d.tap(id="btn_test_crash")
    d.wait_for(id="dialog_test_crash_confirm")
    shot("profile_test_crash_dialog")
    d.tap(id="dialog_test_crash_confirm")
    time.sleep(5)
    print("foreground after crash:", d.foreground_activity())
    d.launch()  # Crashlytics uploads the stored crash when the app starts again
    d.wait_for(id="nav_home", timeout=40)
    time.sleep(10)


FCM_OUT = OUT.parent.parent / "evidence" / "fcm"


def fcm_shot(name: str) -> None:
    time.sleep(1.5)
    d.screenshot(FCM_OUT / f"{name}.png")
    print("saved", name)


def open_push_from_shade(title: str) -> None:
    d.shell("cmd", "statusbar", "expand-notifications")
    d.wait_for(text=title, timeout=60)
    fcm_shot(title.split(" · ")[1].replace(" ", "_"))
    d.tap(text=title)


def fcm() -> None:
    """One test message per app state; each one names its state in the title."""
    FCM_OUT.mkdir(parents=True, exist_ok=True)
    b.reset(me)
    d.sign_in(ACCOUNT)

    b.send_push(me, "FCM test · foreground", "Sent while the app is open.", "team_fin02")
    d.tap(id="btn_open_alerts")
    d.wait_for(text="FCM test · foreground", timeout=60)
    fcm_shot("foreground_alerts")
    back()

    d.shell("input", "keyevent", "KEYCODE_HOME")
    time.sleep(2)
    b.send_push(me, "FCM test · background", "Sent while the app is in the background.", "team_fin02")
    open_push_from_shade("FCM test · background")
    d.wait_for(id="btn_join_team", timeout=30)  # the teamId opens FinTech Guard
    fcm_shot("background_opened")

    d.shell("input", "keyevent", "KEYCODE_HOME")
    time.sleep(2)
    d.shell("am", "kill", PACKAGE)  # ends the process without the force-stop that blocks FCM
    time.sleep(2)
    print("process after kill:", d.adb("shell", "pidof", PACKAGE, check=False).strip() or "none")
    b.send_push(me, "FCM test · terminated", "Sent while the app is not running.", "team_fin02")
    open_push_from_shade("FCM test · terminated")
    d.wait_for(id="btn_join_team", timeout=60)
    fcm_shot("terminated_opened")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        if sys.argv[1:] == ["pool"]:
            pool()
        elif sys.argv[1:] == ["crash"]:
            crash()
        elif sys.argv[1:] == ["tabs"]:
            tabs()
        elif sys.argv[1:] == ["fcm"]:
            fcm()
        else:
            newcomer()
            member_then_leader()
    finally:
        b.reset(me)
        report = OUT / "capture-flutter-errors.txt"
        report.write_text("\n".join(errors) + ("\n" if errors else ""), encoding="utf-8")
        print(f"{len(errors)} Flutter errors -> {report}")


if __name__ == "__main__":
    main()
