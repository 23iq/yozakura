"""Construct the lock screen offscreen with shell services stubbed, once per
style in modules/lockscreen/styles/LockStyleRegistry.js.

For every style: the view loads without QML errors, the media card follows
the player (and lockscreen.showMedia), cava runs only while shown + playing
(and lockscreen.showVisualizer), the password field shows the hints and hands
the wrong-password shake back to LockScreen, and LockScreen.qml's auth flow
(unchanged by the styles) handles blank, wrong and correct passwords against
a fake PamContext.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lockscreen_env import LockscreenEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
STYLES = re.findall(r'^\s*id: "(\w+)"', (REPO / "modules/lockscreen/styles/LockStyleRegistry.js").read_text(), re.M)
assert len(STYLES) >= 6, STYLES
en = json.loads((REPO / "translations/en.json").read_text())

env = LockscreenEnv("lockscreen", overrides={"theme": {"animDuration": 20}})
h = env.h


def check_style(style: str) -> None:
    root = env.load('import QtQuick\nimport qs.modules.lockscreen\nimport qs.config\nimport qs.modules.services\nimport qs.modules.globals\n'
                    'Item { width: 1280; height: 720\n'
                    ' function reset(s) { Config.lockscreen.style = s; Config.lockscreen.showMedia = true;'
                    ' Config.lockscreen.showVisualizer = true; MprisController.activePlayer = null;'
                    ' GlobalStates.lockscreenVisible = true }\n'
                    f' Component.onCompleted: reset("{style}")\n'
                    ' Loader { id: l; anchors.fill: parent; active: false; sourceComponent: LockView { objectName: "lv"; username: "user"; hostname: "host" } }\n'
                    ' function show() { l.active = true; return l.item } }')
    h.eval(root, "show()")
    lv = h.find(root, "lv")

    def ev(expr):
        return h.eval(lv, expr)

    assert ev("styleEntry.id") == style, f"{style}: registry entry"
    assert ev("style !== null"), f"{style}: style must load"
    for slot in ("backdrop", "clock", "passwordField", "mediaCard", "status"):
        assert ev(f"style.{slot} !== null"), f"{style}: slot {slot} missing"
    assert ev("passwordPill !== null && passwordField !== null"), f"{style}: password field must load"

    # Media card: hidden without a player; cava only while shown and playing.
    assert not ev("mediaCard.visible"), f"{style}: no player -> no media card"
    ev("MprisController.activePlayer = " + env.player())
    assert ev("mediaCard.visible"), f"{style}: player -> media card"
    count = lambda: ev("CavaService.consumerCount")  # noqa: E731
    assert count() == 0, f"{style}: locked-out view (startAnim false) must not run cava"
    ev("startAnim = true")
    assert count() == 1, f"{style}: visible + playing must request cava"
    ev("Config.lockscreen.showVisualizer = false")
    assert count() == 0, f"{style}: lockscreen.showVisualizer off releases cava"
    ev("Config.lockscreen.showVisualizer = true")
    assert count() == 1
    ev("MprisController.activePlayer = " + env.player(playing=False))
    assert count() == 0, f"{style}: paused must release cava"
    ev("MprisController.activePlayer = " + env.player())
    assert count() == 1
    ev("Config.lockscreen.showMedia = false")
    assert not ev("mediaCard.visible") and count() == 0, f"{style}: lockscreen.showMedia off hides the card"
    ev("Config.lockscreen.showMedia = true")
    ev("mediaCard.toggle()")
    assert ev("MprisController.toggles") >= 1
    ev("startAnim = false")
    assert count() == 0, f"{style}: unlocking must release cava"

    # Password field: hints and the wrong-password hand-off to LockScreen.
    assert ev("passwordPill.hint") == ""
    ev("capsLock = true")
    assert ev("passwordPill.hint") == en["lockscreen.caps_lock"]
    ev('errorMessage = "Authentication failed"')
    assert ev("passwordPill.hint") == en["lockscreen.wrong_password"]
    assert ev("passwordPill.errorShown")
    ev('passwordPill.field.text = "x"')
    assert ev("passwordPill.hint") == en["lockscreen.caps_lock"], f"{style}: typing again hides the stale error"
    ev('passwordPill.wrongPasswordFinished.connect(function() { passwordPill.field.text = "cleared" }); passwordPill.playWrongPassword()')
    assert ev("passwordPill.showError"), f"{style}: shake shows the error state"
    QTest.qWait(600)
    assert ev("passwordPill.field.text") == "cleared", f"{style}: shake must hand off to LockScreen when done"
    assert ev("passwordPill.shakeOffset") == 0
    ev('passwordPill.field.accepted.connect(function() { passwordPill.field.text = "accepted" })')
    ev('passwordPill.field.text = "pw"; passwordPill.field.accepted()')
    assert ev("passwordPill.field.text") == "accepted"
    ev("MprisController.activePlayer = null")

    # Auth flow in LockScreen.qml (presentation only: must not change it).
    lock = env.lock_screen()

    def lev(expr):
        return h.eval(lock, expr)

    assert lev("lockView.styleEntry.id") == style
    assert lev("startAnim"), "lock starts its entry animation"
    assert lev("passwordInput !== null")
    lev('passwordInput.text = "   "; passwordInput.accepted()')
    QTest.qWait(50)
    assert lev("pamAuth.starts") == 0, f"{style}: blank submit must not start PAM"
    lev('passwordInput.text = "wrong"; passwordInput.accepted()')
    assert lev("passwordInput.text") == "", "field clears immediately on submit"
    assert lev("authenticating"), "submit marks authenticating"
    QTest.qWait(50)
    assert lev("pamAuth.starts") == 1 and lev("pamAuth.received") == "wrong", "PAM receives the typed password"
    assert lev("authPasswordHolder.password") == "", "holder cleared after PAM completes"
    assert lev("errorMessage") == "Authentication failed"
    assert lev("passwordInputBox.showError"), f"{style}: failure shakes the field"
    QTest.qWait(600)
    assert not lev("authenticating") and not lev("passwordInputBox.showError"), "shake end resets state"
    assert lev("GlobalStates.lockscreenVisible"), "wrong password must keep the session locked"
    lev('passwordInput.text = "correct"; passwordInput.accepted()')
    QTest.qWait(50)
    assert lev("pamAuth.received") == "correct"
    assert not lev("startAnim") and lev("errorMessage") == "", "success starts the exit animation"
    QTest.qWait(200)
    assert not lev("GlobalStates.lockscreenVisible"), f"{style}: success unlocks after the exit animation"
    print(f"{style}: view, media/cava gating, password hints/shake and auth flow passed")


for s in STYLES:
    check_style(s)

# Unknown ids fall back to the default style instead of an empty screen.
root = env.load('import QtQuick\nimport qs.modules.lockscreen\nItem { width: 640; height: 360\n LockView { objectName: "lv"; anchors.fill: parent; styleId: "nope" } }')
lv = h.find(root, "lv")
assert h.eval(lv, "styleEntry.id") == "glass" and h.eval(lv, "passwordField !== null")
print("unknown style falls back to glass")

assert not env.errors, "QML errors in the lock screen:\n  " + "\n  ".join(env.errors)
h.exit(0)
