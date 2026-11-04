"""ADB helpers for test preconditions and ground-truth checks.

ARTEMIS performs the steps under test. These helpers only put the app in a
known state before a run and read the device afterwards, so every test checks
the real UI (accessibility tree, Logcat) and not only what the agent reports.
"""

from __future__ import annotations

import os
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

PACKAGE = "com.devorganize222.exematching"
ACTIVITY = f"{PACKAGE}/.MainActivity"
ADB = os.environ.get("ADB", "adb")


@dataclass(frozen=True)
class Node:
    id: str
    text: str
    x: int
    y: int


class Device:
    def __init__(self, serial: str) -> None:
        self.serial = serial

    # --- shell -----------------------------------------------------------
    def adb(self, *args: str, check: bool = True) -> str:
        out = subprocess.run(
            [ADB, "-s", self.serial, *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=check,
        )
        return out.stdout

    def shell(self, *args: str) -> str:
        return self.adb("shell", *args)

    # --- app lifecycle ----------------------------------------------------
    def reset_app(self) -> None:
        """Clears the Firebase session and local caches: the app opens on Sign In."""
        self.shell("pm", "clear", PACKAGE)
        # `pm clear` also revokes the Android 13+ notification permission; FCM would ask
        # for it again right after sign-in and cover Home, which these cases do not test.
        self.shell("pm", "grant", PACKAGE, "android.permission.POST_NOTIFICATIONS")
        self.set_network(True)

    def launch(self) -> None:
        self.shell("am", "force-stop", PACKAGE)
        self.adb("logcat", "-c")
        self.shell("am", "start", "-n", ACTIVITY)
        time.sleep(1.5)

    def set_network(self, on: bool) -> None:
        state = "enable" if on else "disable"
        self.shell("svc", "wifi", state)
        self.shell("svc", "data", state)

    # --- UI tree -----------------------------------------------------------
    def nodes(self) -> list[Node]:
        paths = ["/data/local/tmp/ui.xml", "/sdcard/window_dump.xml", "/sdcard/ui.xml"]
        for attempt in range(4):
            # Try dumping to /data/local/tmp/ui.xml
            dump_out = self.shell("uiautomator", "dump", paths[0])
            if "dumped to" not in dump_out and "ui.xml" not in dump_out:
                # If not idle, retry with --compressed
                self.shell("uiautomator", "dump", "--compressed", paths[0])

            xml = ""
            for p in paths:
                raw = self.adb("exec-out", "cat", p)
                if "<hierarchy" in raw or "<node" in raw:
                    xml = raw
                    break

            if xml:
                try:
                    result: list[Node] = []
                    for el in ET.fromstring(xml).iter("node"):
                        bounds = [int(v) for v in re.findall(r"\d+", el.get("bounds", "[0,0][0,0]"))]
                        result.append(
                            Node(
                                id=el.get("resource-id", ""),
                                text=el.get("text") or el.get("content-desc") or "",
                                x=(bounds[0] + bounds[2]) // 2,
                                y=(bounds[1] + bounds[3]) // 2,
                            )
                        )
                    if result:
                        return result
                except ET.ParseError:
                    pass
            time.sleep(0.5)
        return []

    def find(self, *, id: str | None = None, text: str | None = None) -> Node | None:
        for n in self.nodes():
            if id is not None and n.id == id:
                return n
            if text is not None and (n.text == text or text in n.text.split("\n")):
                return n
        return None

    def wait_for(self, *, id: str | None = None, text: str | None = None, timeout: float = 20) -> Node:
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            node = self.find(id=id, text=text)
            if node:
                return node
            time.sleep(0.7)
        raise AssertionError(f"Timed out waiting for id={id!r} text={text!r}")

    def tap(self, *, id: str | None = None, text: str | None = None, timeout: float = 20) -> None:
        """Taps once the element stops moving (route transitions, banners pushing content)."""
        node = self.wait_for(id=id, text=text, timeout=timeout)
        for _ in range(10):
            time.sleep(0.4)
            again = self.wait_for(id=id, text=text, timeout=timeout)
            if (again.x, again.y) == (node.x, node.y):
                break
            node = again
        self.shell("input", "tap", str(node.x), str(node.y))

    def scroll_to_top(self, swipes: int = 4) -> None:
        """Scrolls the current list back to its top (the agent may have scrolled down)."""
        for _ in range(swipes):
            self.shell("input", "swipe", "540", "700", "540", "1900", "150")

    def screen_text(self) -> str:
        """Every id and label on screen, one per line (for assertions and evidence)."""
        return "\n".join(f"[{n.id}] {n.text}".strip() for n in self.nodes() if n.id or n.text)

    # --- evidence ------------------------------------------------------------
    def screenshot(self, path: Path) -> None:
        png = subprocess.run([ADB, "-s", self.serial, "exec-out", "screencap", "-p"], capture_output=True).stdout
        path.write_bytes(png)

    def analytics_events(self) -> list[str]:
        """`analytics_event <name> {...}` lines the debug analytics service printed."""
        log = self.adb("logcat", "-d", "-s", "flutter")
        return [m.group(1) for m in re.finditer(r"analytics_event (\S+)", log)]

    def foreground_activity(self, expect: str | None = None, timeout: float = 10) -> str:
        """The resumed activity (`package/.Activity`); waits until it contains `expect` when given."""
        end = time.monotonic() + timeout
        while True:
            out = self.shell("dumpsys", "activity", "activities")
            match = re.search(r"topResumedActivity=ActivityRecord\{\S+ \S+ (\S+)", out)
            current = match.group(1) if match else ""
            if expect is None or expect.lower() in current.lower() or time.monotonic() > end:
                return current
            time.sleep(0.5)

    # --- preconditions -------------------------------------------------------
    def sign_in(self, email: str) -> None:
        """Fresh app signed in with the Google account on the device, on Home."""
        self.reset_app()
        self.launch()
        # A tap during the first frames can be dropped, so retry until the
        # Google Play services account chooser opens.
        for _ in range(3):
            if self.find(id="nav_home"):
                return
            self.tap(id="btn_google_sign_in", timeout=40)
            try:
                self.tap(text=email, timeout=10)
                break
            except AssertionError:
                if self.find(id="nav_home"):
                    return
                continue
        else:
            if not self.find(id="nav_home"):
                raise AssertionError("The Google account chooser never opened")
        self.wait_for(id="nav_home", timeout=40)
