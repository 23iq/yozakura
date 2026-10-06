"""App theme generators emit Yozakura-named files and switch legacy setups.

Each generator is loaded with a recording Process stub; generate() runs on a
fake palette, then the exact command it built runs in a throwaway HOME that
holds a legacy (Ambxst) setup: Discord clients with enabledThemes
["ambxst.css"], a Firefox profile importing ambxst.css, spicetify with
current_theme = ambxst, qt6ct pointing at ambxst.colors. The generators must
write yozakura-named files, switch those references and leave the old files
alone.
"""
import atexit
import json
import os
import shutil
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO, Harness, brand_qml  # noqa: E402

sys.path.insert(0, str(REPO / "scripts" / "lib"))
from brand import DAEMON  # noqa: E402

home = Path(tempfile.mkdtemp(prefix="yozakura-generators-"))
atexit.register(shutil.rmtree, home, True)
cfg = home / ".config"
failures = []


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else f": {detail}"))
    if not ok:
        failures.append(name)


def text(path):
    return path.read_text() if path.is_file() else ""


def write(rel, text):
    path = home / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


# Legacy setup.
write(".config/Equicord/settings/settings.json", json.dumps({"enabledThemes": ["ambxst.css", "other.css"]}))
write(".config/Equicord/themes/ambxst.css", "/* old */")
write(".config/vesktop/settings/settings.json", json.dumps({"enabledThemes": ["ambxst.css"]}))
write(".mozilla/firefox/profiles.ini", "[Profile0]\nName=default\nPath=abc.default\nDefault=1\n")
user_chrome = write(".mozilla/firefox/abc.default/chrome/userChrome.css", '@import url("ambxst.css");\n#nav-bar { color: red; }\n')
user_content = write(".mozilla/firefox/abc.default/chrome/userContent.css", '@import url("ambxst-content.css");\n')
spice_conf = write(".config/spicetify/config-xpui.ini", "[Setting]\ncurrent_theme          = ambxst\ncolor_scheme           = ambxst\n")
write(".config/spicetify/Themes/ambxst/color.ini", "; old")
qt6 = write(".config/qt6ct/qt6ct.conf", f"[Appearance]\ncolor_scheme_path={cfg}/qt6ct/colors/ambxst.colors\ncustom_palette=true\n")

# Fake spicetify: answers -c with our config, logs everything else.
stub_bin = home / "bin"
stub_bin.mkdir()
spice_log = home / "spicetify.log"
(stub_bin / "spicetify").write_text(
    f'#!/bin/sh\nif [ "$1" = "-c" ]; then echo "{spice_conf}"; exit 0; fi\necho "$@" >> "{spice_log}"\n')
(stub_bin / "spicetify").chmod(0o755)
for tool in ("pywalfox", "walogram", "gsettings", DAEMON, "pkill"):  # never touch the real browser/telegram
    (stub_bin / tool).write_text("#!/bin/sh\nexit 0\n")
    (stub_bin / tool).chmod(0o755)
pwned = home / "pwned"
# A wallpaper file name is data: it must never be expanded by a shell.
evil_wall = f"{home}/walls/a\"$(touch {pwned})`touch {pwned}`'$HOME\\n.jpg"

roles = re.search(r"var roleNames = \[([^\]]*)\]", text(REPO / "modules/theme/ColorUtils.js")).group(1)
role_names = re.findall(r'"(\w+)"', roles) + ["blue", "yellow", "error", "red", "green"] + [
    "lightRed", "lightGreen", "lightYellow", "lightBlue", "magenta", "lightMagenta", "cyan", "lightCyan",
    "primaryFixed", "primaryFixedDim", "secondaryFixedDim", "tertiaryFixed", "overPrimaryContainer"]
palette_qml = "QtObject {\n" + "\n".join(
    f'    property color {n}: "{"#101014" if "background" in n.lower() or "surface" in n.lower() else "#e0a0c0"}"'
    for n in dict.fromkeys(role_names)) + "\n}"

h = Harness("theme-generators")
h.singleton("Quickshell", "Quickshell", f'''QtObject {{
    property string shellDir: "{REPO}"
    function env(n) {{ return n === "HOME" ? "{home}" : ""; }}
}}''')
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command: []; property bool running: false; "
               "property QtObject stdout; property QtObject stderr; signal exited(int exitCode) }",
    "StdioCollector": "QtObject { property string text; signal streamFinished(string text) }",
})
h.singleton("qs.config", "Config", 'QtObject { property QtObject theme: QtObject { property string font: "Sans"; '
            'property bool lightMode: false; property var srBg: ({ opacity: 0.9 }) }; '
            'property QtObject terminal: QtObject { property bool enabled: false; property string cursorShape: "beam"; property real padding: 12; '
            'property bool cursorBlink: true } }')
h.module("qs.modules.globals", {"Brand": brand_qml(str(home)),
                                "GlobalStates": "pragma Singleton\nQtObject { property var wallpaperManager: null }"})
h.module("wallstub", {"Wall": "QtObject { property string currentWallpaper }"})
colors = h.load(palette_qml)

env = {**{k: v for k, v in os.environ.items() if not k.startswith("XDG_")}, "HOME": str(home),
       "PATH": f"{stub_bin}:{os.environ.get('PATH', '/usr/bin:/bin')}"}


h.engine.rootContext().setContextProperty("fakeColors", colors)


def as_list(value):
    value = value.toVariant() if hasattr(value, "toVariant") else value
    return [str(v) for v in value]


def run_generator(name):
    gen = h.load(h.copy(f"modules/theme/{name}.qml", siblings=False))
    h.eval(gen, "root.generate(fakeColors)")
    return as_list(h.eval(gen, "root.writerProcess.command"))


for gen_name in ("DiscordGenerator", "FirefoxGenerator", "SpicetifyGenerator", "QtCtGenerator"):
    cmd = run_generator(gen_name)
    check(f"{gen_name}: no legacy name in the script or argv0", not any("ambxst" in a for a in cmd[:4]),
          str([a[:60] for a in cmd[:4]]))
    r = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=60)
    check(f"{gen_name}: script exits 0", r.returncode == 0, r.stderr[-400:])

themes = cfg / "Equicord/themes"
check("discord: yozakura.css written", (themes / "yozakura.css").is_file())
check("discord: vesktop yozakura.css written", (cfg / "vesktop/themes/yozakura.css").is_file())
check("discord: old ambxst.css left alone", text(themes / "ambxst.css") == "/* old */")
enabled = json.loads(text(cfg / "Equicord/settings/settings.json"))["enabledThemes"]
check("discord: enabledThemes switched", enabled == ["yozakura.css", "other.css"], str(enabled))
enabled = json.loads(text(cfg / "vesktop/settings/settings.json"))["enabledThemes"]
check("discord: vesktop enabledThemes switched", enabled == ["yozakura.css"], str(enabled))

chrome_dir = user_chrome.parent
check("firefox: yozakura.css written", (chrome_dir / "yozakura.css").is_file())
check("firefox: yozakura-content.css written", (chrome_dir / "yozakura-content.css").is_file())
uc = user_chrome.read_text()
check("firefox: one yozakura import, no ambxst import",
      uc.count('@import url("yozakura.css");') == 1 and "ambxst" not in uc and "#nav-bar" in uc, uc)
ucont = user_content.read_text()
check("firefox: userContent import switched",
      ucont.count('@import url("yozakura-content.css");') == 1 and "ambxst" not in ucont, ucont)

spice_theme = cfg / "spicetify/Themes/yozakura"
check("spicetify: theme dir written", (spice_theme / "color.ini").is_file() and (spice_theme / "user.css").is_file())
check("spicetify: color.ini section", "[yozakura]" in text(spice_theme / "color.ini"))
conf = spice_conf.read_text()
check("spicetify: config switched", re.search(r"^current_theme\s*=\s*yozakura$", conf, re.M) is not None
      and re.search(r"^color_scheme\s*=\s*yozakura$", conf, re.M) is not None, conf)
log = spice_log.read_text() if spice_log.exists() else ""
check("spicetify: applied after switching", "apply" in log, log)
check("spicetify: old theme dir left alone", text(cfg / "spicetify/Themes/ambxst/color.ini") == "; old")

check("qtct: yozakura.colors written", (cfg / "qt6ct/colors/yozakura.colors").is_file())
check("qtct: scheme name", "Name=Yozakura" in text(cfg / "qt6ct/colors/yozakura.colors"))
check("qtct: color_scheme_path switched", "colors/yozakura.colors" in qt6.read_text() and "ambxst" not in qt6.read_text(),
      qt6.read_text())

tg_cmd = run_generator("TelegramGenerator")
check("telegram: output is yozakura.tdesktop-theme",
      any(str(a).endswith("/.cache/yozakura/yozakura.tdesktop-theme") for a in tg_cmd), str(tg_cmd[:5]))

# #10: pywal writes the wallpaper path verbatim, without shell expansion.
wall = h.load(f'import wallstub\nWall {{ currentWallpaper: {json.dumps(evil_wall)} }}')
h.engine.rootContext().setContextProperty("fakeWall", wall)
gen = h.load(h.copy("modules/theme/PywalGenerator.qml", siblings=False))
h.eval(gen, "GlobalStates.wallpaperManager = fakeWall")
h.eval(gen, "root.generate(fakeColors)")
cmd = as_list(h.eval(gen, "root.writerProcess.command"))
h.eval(gen, "GlobalStates.wallpaperManager = null")
check("pywal: wallpaper path not in the shell script", not any(evil_wall in a for a in cmd[:3]), str(cmd[:3]))
r = subprocess.run(cmd or ["false"], env=env, capture_output=True, text=True, timeout=60)
check("pywal: script exits 0", r.returncode == 0, r.stderr[-400:])
wal = home / ".cache/wal"
check("pywal: no command substitution ran", not pwned.exists())
check("pywal: wal file holds the exact path", text(wal / "wal").rstrip("\n") == evil_wall, repr(text(wal / "wal")))
try:
    wal_json = json.loads(text(wal / "colors.json"))
except ValueError as e:
    wal_json = {"error": str(e)}
check("pywal: colors.json is valid JSON with the path", wal_json.get("wallpaper") == evil_wall, str(wal_json)[:200])
check("pywal: colors has 16 lines", len(text(wal / "colors").split()) == 16, text(wal / "colors")[:200])
check("pywal: colors.sh defines color15", 'color15="#' in text(wal / "colors.sh"), text(wal / "colors.sh")[:200])

# Every generator passes paths and contents as positional args: the sandbox
# HOME path must never be spliced into the script itself.
for gen_name, out in (("GtkGenerator", ".config/gtk-3.0/gtk.css"), ("NvChadGenerator", ".cache/wal/base46-dark.lua"),
                      ("PywalZenGenerator", ".cache/yozakura/pywalzen.css"),
                      ("QtCtGenerator", ".config/qt5ct/colors/yozakura.colors")):
    cmd = run_generator(gen_name)
    check(f"{gen_name}: no paths or contents in the script", cmd[:2] == ["sh", "-c"] and str(home) not in cmd[2],
          str(cmd[:3])[:300])
    r = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=60)
    check(f"{gen_name}: script exits 0", r.returncode == 0, r.stderr[-400:])
    check(f"{gen_name}: wrote {out}", (home / out).is_file() and len(text(home / out)) > 20)

# Kitty: the terminal look keys follow Config.terminal.
h.singleton("qs.modules.theme", "Glass", "QtObject { property real terminalOpacity: 0.9 }")
kitty = h.load(h.copy("modules/theme/KittyGenerator.qml", siblings=False))
h.engine.rootContext().setContextProperty("fakeColors", colors)
h.eval(kitty, "root.generate(fakeColors)")
kconf = h.eval(kitty, "root.writer.text")
kconf = str(kconf)
# terminal.enabled is false until the user picks a look: kitty's own
# padding and cursor stay untouched
check("kitty: no look keys while the terminal look is off", not any(k in kconf for k in (
    "cursor_shape", "window_padding_width", "cursor_blink_interval")), kconf[:300])
check("kitty: cursor_text_color kept", "cursor_text_color " in kconf)
h.eval(kitty, "Config.terminal.enabled = true")
h.eval(kitty, "root.generate(fakeColors)")
kconf = str(h.eval(kitty, "root.writer.text"))
check("kitty: default cursor and padding", all(k in kconf for k in (
    "cursor_shape beam\n", "window_padding_width 12\n", "cursor_blink_interval -1\n")), kconf[:300])
h.eval(kitty, "Config.terminal.cursorBlink = false; Config.terminal.cursorShape = 'block'; Config.terminal.padding = 4")
h.eval(kitty, "root.generate(fakeColors)")
kconf = str(h.eval(kitty, "root.writer.text"))
check("kitty: blink off, block, padding 4", all(k in kconf for k in (
    "cursor_shape block\n", "window_padding_width 4\n", "cursor_blink_interval 0\n")), kconf[:300])

if failures:
    print(f"theme-generators: {len(failures)} failure(s)")
    sys.exit(1)
print("theme-generators: PASS")
