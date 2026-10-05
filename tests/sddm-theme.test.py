"""SDDM theme (assets/sddm/<app>): every lock screen style logs in.

Part 1 runs scripts/sddm-sync.sh against a fake home (config, palette,
wallpaper) into a temp data dir and checks the exported style, resolved
tone, blur, fonts and palette roles.
Part 2 loads Main.qml offscreen with stubbed SDDM context properties
(tests/lib/sddm_env.py) for every style of Styles.js plus an unknown id:
no QML errors, the password field has focus, Enter calls sddm.login(user,
password, session), loginFailed shakes and clears, Escape clears, Caps Lock
and the safety hints show, loginSucceeded fades out, secondary screens show
no field.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402,F401  (offscreen, never the live session)

from PySide6.QtCore import Qt, qInstallMessageHandler  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from sddm_env import THEME, SddmEnv, read_conf  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts" / "lib"))
import brand  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
STYLES = re.findall(r'^    "(\w+)": \{', (THEME / "Styles.js").read_text(), re.M)
SHELL_STYLES = re.findall(r'^\s*id: "(\w+)"', (REPO / "modules/lockscreen/styles/LockStyleRegistry.js").read_text(), re.M)
assert STYLES and sorted(STYLES) == sorted(SHELL_STYLES), f"SDDM styles {STYLES} != shell styles {SHELL_STYLES}"
for s in STYLES:
    assert (THEME / "styles" / (s[0].upper() + s[1:] + "Style.qml")).exists(), f"styles/ file for {s}"


def fail(msg: str) -> None:
    print("FAIL:", msg, file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------- sync script

def run_sync(lock: dict, theme: dict) -> dict:
    with tempfile.TemporaryDirectory(prefix="sddm-sync-test-") as tmp:
        t = Path(tmp)
        home, target = t / "home", t / "target"
        cfg = home / ".config" / brand.APP_ID / "config"
        cache = home / ".cache" / brand.APP_ID
        cfg.mkdir(parents=True)
        cache.mkdir(parents=True)
        target.mkdir()
        wall = t / "wall.png"
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=pink:s=64x36",
                        "-frames:v", "1", str(wall)], check=True)
        (cache / "wallpapers.json").write_text(json.dumps({"currentWall": str(wall)}))
        (cache / "colors.json").write_text(json.dumps({
            "background": "#120c0f", "primary": "#ffafd7", "primaryFixed": "#ffd8e9", "secondaryFixed": "#ffd8e9",
            "overSecondaryFixed": "#330d24", "red": "#ffb2b9", "shadow": "#000000"}))
        (cfg / "theme.json").write_text(json.dumps(theme))
        (cfg / "lockscreen.json").write_text(json.dumps(lock))
        env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", brand.ENV_PREFIX, brand.LEGACY_ENV_PREFIX))}
        env.update(HOME=str(home))
        r = subprocess.run(["bash", str(REPO / "scripts/sddm-sync.sh"), "--target", str(target), "--quiet"],
                           env=env, capture_output=True, text=True)
        if r.returncode != 0:
            fail("sddm-sync.sh failed: " + r.stderr)
        conf = read_conf(target / "theme.conf")
        conf["_fonts"] = sorted(p.name for p in (target / "fonts").iterdir())
        conf["_wallpaper"] = (target / "wallpaper-blur.jpg").exists()
        return conf


c = run_sync({"style": "paper", "tone": "theme", "blur": 0.4, "showStatus": False, "position": "top"},
             {"lightMode": True, "monoFont": "Iosevka"})
if c.get("style") != "paper" or c.get("tone") != "light":
    fail(f"paper + theme tone in light mode -> paper/light, got {c.get('style')}/{c.get('tone')}")
if c.get("blur") != "0.4" or c.get("showStatus") != "false" or c.get("position") != "top":
    fail(f"blur/showStatus/position exported: {c.get('blur')} {c.get('showStatus')} {c.get('position')}")
for f in ("clock-mincho-medium.ttf", "clock-mincho-regular.ttf", "clock-mincho-bold.ttf", "clock-gothic.ttf",
          "clock-grotesk-medium.otf", "clock-grotesk-bold.otf"):
    if f not in c["_fonts"]:
        fail(f"clock font {f} not synced: {c['_fonts']}")
    key = {"clock-mincho-medium.ttf": "minchoFile", "clock-gothic.ttf": "gothicFile"}.get(f)
    if key and not c.get(key, "").endswith(f):
        fail(f"{key} points at the synced font: {c.get(key)}")
for role in ("color_primaryFixed", "color_secondaryFixed", "color_overSecondaryFixed", "color_red", "color_shadow"):
    if not c.get(role, "").startswith("#"):
        fail(f"palette role {role} exported")
if c.get("monoFont") != "Iosevka" or not c["_wallpaper"]:
    fail("monoFont and the blurred wallpaper are exported")

c = run_sync({"style": "bogus", "tone": "dark", "blur": 5}, {})
if c.get("style") != "glass" or c.get("tone") != "dark" or c.get("blur") != "-1" or c.get("showStatus") != "true":
    fail(f"invalid style/blur fall back to glass/-1: {c.get('style')} {c.get('tone')} {c.get('blur')}")
c = run_sync({"style": "neon", "tone": "light"}, {})
if c.get("tone") != "dark":
    fail("neon has no light tone: forced light resolves to dark")
c = run_sync({"style": "aurora"}, {"lightMode": False})
if c.get("tone") != "light":
    fail("tone 'style' (default) uses the style's own tone (aurora: light)")
print("sddm-sync.sh: style, tone, blur, fonts and palette exported")

# ------------------------------------------------------------------- theme

errors: list[str] = []
_prev = qInstallMessageHandler(None)


def _capture(mode, ctx, msg):
    errors.append(msg)
    if _prev:
        _prev(mode, ctx, msg)


qInstallMessageHandler(_capture)


def type_text(view, text: str) -> None:
    for ch in text:
        QTest.keyClick(view, ch)


def check_style(style: str, expect: str) -> None:
    env = SddmEnv({"style": style, "tone": "dark", "fontSize": "14", "roundness": "16"}, size=(1280, 720))
    QTest.qWait(250)
    ev = env.eval
    if ev("styleId") != expect or ev("styleFailed") or ev("style === null"):
        fail(f"{style}: loads as {expect}")
    if not ev("passwordField !== null && passwordField.activeFocus"):
        fail(f"{style}: password field has focus")
    if ev("style.hint") != "":
        fail(f"{style}: no hint at rest")
    env.stub('keyboard.capsLock = true')
    if ev("style.hint") != "Caps Lock is on":
        fail(f"{style}: caps lock hint")
    env.stub('keyboard.capsLock = false')

    # Escape clears the field.
    type_text(env.view, "abc")
    if ev("passwordField.text") != "abc":
        fail(f"{style}: typing reaches the field")
    QTest.keyClick(env.view, Qt.Key_Escape)
    if ev("passwordField.text") != "":
        fail(f"{style}: Escape clears the field")

    # Empty Enter does nothing; Enter logs in with user, password, session.
    QTest.keyClick(env.view, Qt.Key_Return)
    if env.stub("sddm.logins.length") != 0:
        fail(f"{style}: empty password must not log in")
    type_text(env.view, "hunter2")
    QTest.keyClick(env.view, Qt.Key_Return)
    logins = env.stub("JSON.stringify(sddm.logins)")
    if json.loads(logins) != [["lazy", "hunter2", 0]]:
        fail(f"{style}: sddm.login(user, password, session), got {logins}")
    if not ev("authenticating") or ev("style.hint") != "Signing in…":
        fail(f"{style}: authenticating state")

    # Wrong password: error hint, shake, then the field is cleared and usable.
    env.stub("sddm.loginFailed()")
    if not ev("showError") or ev("style.hint") != "Wrong password" or not ev("style.errorShown"):
        fail(f"{style}: wrong password hint")
    QTest.qWait(500)
    if ev("passwordField.text") != "" or ev("authenticating") or ev("style.shakeOffset") != 0:
        fail(f"{style}: shake end clears the field and unlocks it")
    if not ev("passwordField.activeFocus"):
        fail(f"{style}: focus back on the field")
    type_text(env.view, "x")
    if ev("showError"):
        fail(f"{style}: typing again hides the error")

    env.stub('sddm.informationMessage("Account expires soon")')
    if ev("style.hint") != "Account expires soon":
        fail(f"{style}: information message shown")

    env.stub("sddm.loginSucceeded()")
    QTest.qWait(800)
    if not ev("loginOk") or ev("startAnim") or ev("reveal") > 0.05:
        fail(f"{style}: success fades the chrome out")
    env.view.close()

    # Secondary screen: clock only.
    env2 = SddmEnv({"style": style}, size=(1280, 720), primary=False)
    QTest.qWait(150)
    if env2.eval("style.cluster.visible"):
        fail(f"{style}: no password field on secondary screens")
    env2.view.close()
    print(f"{style}: focus, typing, Escape, login, wrong password, messages, success and secondary screen passed")


for s in STYLES:
    check_style(s, s)
check_style("nope", "glass")

# A style file that fails to load falls back to glass (and still logs in).
with tempfile.TemporaryDirectory(prefix="sddm-broken-") as tmp:
    broken = Path(tmp) / "theme"
    shutil.copytree(THEME, broken)
    (broken / "styles" / "PaperStyle.qml").write_text("import QtQuick\nNotAType {}\n")
    env = SddmEnv({"style": "paper"}, size=(1280, 720), theme=broken)
    QTest.qWait(200)
    if not env.eval("styleFailed") or env.eval("styleId") != "glass" or not env.eval("passwordField.activeFocus"):
        fail("a broken style falls back to glass with a focused field")
    env.view.close()
if not any("NotAType" in e for e in errors):
    fail("QML warnings are captured (the broken style must have reported one)")
errors[:] = [e for e in errors if "NotAType" not in e and "PaperStyle" not in e and "failed to load" not in e]
print("broken style file falls back to glass")

own = [e for e in errors if "Cannot open" not in e]
if own:
    fail("QML errors/warnings:\n  " + "\n  ".join(own))
print("SDDM theme: all styles passed")
sys.stdout.flush()
os._exit(0)
