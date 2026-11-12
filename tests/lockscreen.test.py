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
from waits import pump, wait_until  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
STYLES = re.findall(r'^\s*id: "(\w+)"', (REPO / "modules/lockscreen/styles/LockStyleRegistry.js").read_text(), re.M)
assert len(STYLES) >= 6, STYLES
en = json.loads((REPO / "translations/en.json").read_text())

env = LockscreenEnv("lockscreen", overrides={"theme": {"animDuration": 100}})
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
    wait_until(lambda: ev("passwordPill.field.text") == "cleared")
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
    lev('passwordInput.text = ""; passwordInput.accepted()')
    pump(50)  # nothing may start: give a deferred PAM start the chance to show
    assert lev("pamAuth.starts") == 0, f"{style}: empty submit must not start PAM"
    lev('passwordInput.text = " wrong  "; passwordInput.accepted()')
    assert lev("passwordInput.text") == "", "field clears immediately on submit"
    assert lev("authenticating"), "submit marks authenticating"
    wait_until(lambda: lev("pamAuth.starts") == 1 and lev("errorMessage") != "")
    assert lev("pamAuth.starts") == 1 and lev("pamAuth.received") == " wrong  ", "PAM receives the typed password verbatim"
    assert lev("pamAuth.startedWith").endswith("/config/pam|password.conf"), "default: the bundled PAM config"
    assert lev("authPasswordHolder.password") == "", "holder cleared after PAM completes"
    assert lev("errorMessage") == "Authentication failed"
    assert lev("passwordInputBox.showError"), f"{style}: failure shakes the field"
    wait_until(lambda: not lev("authenticating") and not lev("passwordInputBox.showError"))
    assert not lev("authenticating") and not lev("passwordInputBox.showError"), "shake end resets state"
    assert lev("GlobalStates.lockscreenVisible"), "wrong password must keep the session locked"
    lev('passwordInput.text = "correct"; passwordInput.accepted()')
    wait_until(lambda: lev("pamAuth.received") == "correct")
    assert lev("pamAuth.received") == "correct"
    assert not lev("startAnim") and lev("errorMessage") == "", "success starts the exit animation"
    wait_until(lambda: not lev("GlobalStates.lockscreenVisible"))
    assert not lev("GlobalStates.lockscreenVisible"), f"{style}: success unlocks after the exit animation"
    print(f"{style}: view, media/cava gating, password hints/shake and auth flow passed")


for s in STYLES:
    check_style(s)

# Spaces are legal in a password: a whitespace-only one reaches PAM as typed.
lock = env.lock_screen()


def lev(expr):
    return h.eval(lock, expr)


lev("GlobalStates.lockscreenVisible = true")  # the last style's check unlocked


def submit(text: str) -> str:
    """Submit a (wrong) password, wait for the shake to end; the PAM target used."""
    before = lev("pamAuth.starts")
    lev(f"passwordInput.text = {json.dumps(text)}; passwordInput.accepted()")
    wait_until(lambda: lev("pamAuth.starts") == before + 1 and lev("errorMessage") != "")
    assert lev("pamAuth.received") == text, f"PAM must receive {text!r} verbatim"
    wait_until(lambda: not lev("authenticating"))
    assert lev("GlobalStates.lockscreenVisible"), "a wrong password keeps the session locked"
    return lev("pamAuth.startedWith")


submit("   ")
submit("\t")
print("whitespace-only passwords reach PAM verbatim")

# lockscreen.pamService: the system stack only for a plain name whose
# /etc/pam.d file was found to be a usable password stack; the bundled
# config otherwise. The check is grep for `auth ... pam_permit.so`:
# exit 1 = read, none found (usable), 0 = found (refused), 2 = unreadable.
USABLE, PERMIT, UNREADABLE = 1, 0, 2


def check_cmd(name):
    return json.dumps(["grep", "-Eiqs", "-e", "^[[:space:]]*-?auth[[:space:]].*pam_permit\\.so", "--", "/etc/pam.d/" + name],
                      separators=(",", ":"))


BUNDLED = lev("pamTarget.bundledDir") + "|password.conf"
assert lev("Config.lockscreen.pamService") == "", "default: no service"
assert not lev("pamTarget.check.running"), "default: no service check"
assert submit("a") == BUNDLED
lev('Config.lockscreen.pamService = "system-auth"')
assert lev("JSON.stringify(pamTarget.check.command)") == check_cmd("system-auth")
assert lev("pamTarget.check.running")
assert submit("b") == BUNDLED, "until the check answers, the bundled config is used"
lev(f"pamTarget.check.running = false; pamTarget.check.exited({USABLE}, 0)")
assert submit("c") == "/etc/pam.d|system-auth", "a usable service file selects the system stack"
# A failure re-checks the file; the result for that path stands meanwhile.
assert lev("pamTarget.check.running"), "a failed attempt re-checks the service file"
lev(f"pamTarget.check.running = false; pamTarget.check.exited({UNREADABLE}, 0)")
assert submit("d") == BUNDLED, "a missing or unreadable service file falls back to the bundled config"
assert lev("pamTarget.check.running")
lev(f"pamTarget.check.running = false; pamTarget.check.exited({PERMIT}, 0)")
assert submit("d2") == BUNDLED, "a service whose auth uses pam_permit.so is refused"
lev("pamTarget.check.running = false")
lev('Config.lockscreen.pamService = "login"')
lev('Config.lockscreen.pamService = "sddm"')  # changed while the check for "login" runs
lev(f"pamTarget.check.running = false; pamTarget.check.exited({USABLE}, 0)")
assert submit("e") == BUNDLED, "a result for another name does not count"
wait_until(lambda: lev("JSON.stringify(pamTarget.check.command)") == check_cmd("sddm"))
lev(f"pamTarget.check.running = false; pamTarget.check.exited({USABLE}, 0)")
assert submit("f") == "/etc/pam.d|sddm"
lev("pamTarget.check.running = false")
for bad in ("../shadow", "/etc/shadow", "pam.d/login", ".hidden", "-x", "a b", "gdm-autologin", "sddm-autologin"):
    lev(f"Config.lockscreen.pamService = {json.dumps(bad)}")
    assert not lev("pamTarget.check.running"), f"{bad!r}: no file check for an invalid or refused name"
    assert submit("g") == BUNDLED, f"{bad!r}: invalid and autologin names use the bundled config"
lev('Config.lockscreen.pamService = ""')
assert submit("h") == BUNDLED
print("lockscreen.pamService selects the PAM stack conservatively")

# Unknown ids fall back to the default style instead of an empty screen.
root = env.load('import QtQuick\nimport qs.modules.lockscreen\nItem { width: 640; height: 360\n LockView { objectName: "lv"; anchors.fill: parent; styleId: "nope" } }')
lv = h.find(root, "lv")
assert h.eval(lv, "styleEntry.id") == "glass" and h.eval(lv, "passwordField !== null")
print("unknown style falls back to glass")

# The submit spinner turns once per kit progress cycle while busy, and
# stays still with motion off.
sp = env.load('import QtQuick\nimport qs.config\nimport qs.modules.lockscreen\nLockSpinner { busy: true; function motionOff() { Config.theme.animDuration = 0 } }')
assert h.eval(sp, "cycle > 0 && text !== idleIcon"), "busy spinner shows the notch"
h.eval(sp, "busy = false")
assert h.eval(sp, "text === idleIcon && rotation === 0"), "idle spinner rests on the arrow"
h.eval(sp, "motionOff()")
assert h.eval(sp, "cycle === 0"), "no spin with motion off"
print("spinner follows the kit motion")

assert not env.errors, "QML errors in the lock screen:\n  " + "\n  ".join(env.errors)
h.exit(0)
