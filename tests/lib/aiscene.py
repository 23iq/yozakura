"""Offscreen scene builder for the AI center UI (tests + preset renders).

Copies the real `modules/` tree into a temp `qs` import root (with qmldir
files like Quickshell synthesises), then replaces the system-facing pieces
with stubs: Config (theme from an assets/presets/<name>/theme.json), Colors
(palette from tests/fixtures/aicenter-palettes.json), the services the AI
center talks to (Ai with scripted conversations, I18n from en.json,
BackendService, KeyStore), GlobalStates and Quickshell's own modules.
Everything else (StyledRect, Styling, Icons, every AI center component,
ChatSession, AgentTimeline.js, the markdown/diff/highlight libs) is real.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SINGLETON = re.compile(r"^\s*pragma\s+Singleton\b", re.M)


def _qmldirs(root: Path) -> None:
    for d in [root, *[p for p in root.rglob("*") if p.is_dir()]]:
        types = []
        for f in sorted(d.glob("*.qml")):
            if f.stem[:1].isupper():
                types.append((f.stem, bool(SINGLETON.search(f.read_text(errors="replace")[:4000]))))
        if types:
            rel = d.relative_to(root.parent)
            body = ["module " + ".".join(rel.parts)]
            body += [f"{'singleton ' if s else ''}{n} 1.0 {n}.qml" for n, s in types]
            (d / "qmldir").write_text("\n".join(body) + "\n")


def _module(root: Path, name: str, files: dict[str, str]) -> None:
    d = root / Path(*name.split("."))
    d.mkdir(parents=True, exist_ok=True)
    lines = ["module " + name]
    for n, body in files.items():
        if not re.search(r"^\s*import\s+QtQuick\b", body, re.M):
            body = ("pragma Singleton\n" if body.startswith("pragma Singleton") else "") + "import QtQuick\n" + body.replace("pragma Singleton\n", "")
        (d / f"{n}.qml").write_text(body)
        lines.append(("singleton " if "pragma Singleton" in body else "") + f"{n} 1.0 {n}.qml")
    (d / "qmldir").write_text("\n".join(lines) + "\n")


def _theme_defaults() -> dict:
    script = "console.log(JSON.stringify(require(process.argv[1]).loadLibrary(process.argv[2]).data))"
    out = subprocess.run(["node", "-e", script, str(REPO / "tests/lib/qmljs.cjs"), str(REPO / "config/defaults/theme.js")],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def _theme_config(preset: str) -> str:
    theme = json.loads((REPO / "assets/presets" / preset / "theme.json").read_text())
    # Like the shell's validator: surface variants the preset leaves out (or
    # only partly sets) come from config/defaults/theme.js.
    defaults = _theme_defaults()
    props = []
    for key, base in defaults.items():
        if key.startswith("sr") and isinstance(base, dict):
            val = {**base, **theme.get(key, {})}
            props.append(f"        property var {key}: ({json.dumps(val)})")
    for key in ("shadowXOffset", "shadowYOffset", "shadowBlur", "shadowOpacity"):
        props.append(f"        property real {key}: {theme.get(key, defaults[key])}")
    props.append(f"        property string shadowColor: {json.dumps(theme.get('shadowColor', defaults['shadowColor']))}")
    font = theme.get("font", "Roboto Condensed")
    mono = theme.get("monoFont", "monospace")
    return f"""
    property QtObject theme: QtObject {{
        property string font: {json.dumps(font)}
        property int fontSize: {int(theme.get("fontSize", 14))}
        property string monoFont: {json.dumps(mono)}
        property int monoFontSize: {int(theme.get("monoFontSize", 14))}
        property bool lightMode: {str(bool(theme.get("lightMode", False))).lower()}
{chr(10).join(props)}
    }}
    property int roundness: {int(theme.get("roundness", 16))}
"""


AI_CONFIG = """
    property QtObject ai: QtObject {
        property bool enabled: true
        property bool showThinking: true
        property bool chatTools: true
        property int maxToolRounds: 8
        property int wideWidth: 1100
        property int sidebarWidth: 400
        property int unloadAfterMinutes: 10
        property string defaultModel: ""
        property string sidebarPosition: "right"
        property string systemPrompt: ""
        property list<var> extraModels: []
        property list<var> prompts: []
        property list<var> automations: []
        property QtObject quickAsk: QtObject { property bool enabled: true; property string model: ""; property int width: 560 }
        property QtObject appearance: QtObject {
            property string defaultSize: "compact"; property string messageStyle: "bubble"; property string density: "comfortable"
            property real fontScale: 1; property bool showAvatars: false; property bool showTimestamps: false
            property bool animations: true; property bool glass: true; property real opacity: 1
        }
        property QtObject behavior: QtObject {
            property string defaultSpace: "last"; property bool enterToSend: true; property bool suggestions: true
            property list<string> suggestionKinds: ["clipboard", "selection", "media", "timer", "window", "desktop", "time"]
            property bool restoreLastSession: true; property bool autoScroll: true; property bool thinkingExpanded: false; property bool collapseTools: true
        }
        property QtObject strip: QtObject { property bool engine: true; property bool context: true; property bool cost: true; property bool limit: true }
        property QtObject mcp: QtObject { property bool yozakura: true; property bool importClaude: true; property bool importCodex: true; property bool importOpencode: true; property list<var> disabled: [] }
        property QtObject selection: QtObject {
            property bool enabled: true; property string language: "English"; property string output: "replace"
            property list<var> actions: []
        }
        property QtObject agents: QtObject {
            property string defaultAgent: "claude"; property string defaultCwd: "/home/user/src/yozakura"
            property list<var> recentDirs: ["/home/user/src/yozakura", "/home/user/notes"]
            property list<var> autoApprove: ["read"]
            property QtObject claude: QtObject { property bool enabled: true; property string binary: ""; property string model: ""; property bool yolo: false; property list<var> extraArgs: [] }
            property QtObject codex: QtObject { property bool enabled: true; property string binary: ""; property string model: ""; property bool yolo: false; property list<var> extraArgs: [] }
            property QtObject opencode: QtObject { property bool enabled: true; property string binary: ""; property string model: "ollama/qwen3.5:9b"; property bool yolo: true; property list<var> extraArgs: [] }
        }
    }
    property QtObject bar: QtObject { property bool frameEnabled: false }
"""


def build(preset: str, mode: str, ai_stub: str) -> Path:
    """Returns the import root; caller loads scenes with addImportPath(root)."""
    tmp = Path(tempfile.mkdtemp(prefix="aiscene-"))
    qs = tmp / "qs"
    for src in (REPO / "modules").rglob("*"):
        if src.is_file() and src.suffix in (".qml", ".js", ".qsb"):
            dst = qs / "modules" / src.relative_to(REPO / "modules")
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(src, dst)
    palette = json.loads((REPO / "tests/fixtures/aicenter-palettes.json").read_text())[mode]
    colors = "pragma Singleton\nimport QtQuick\nQtObject {\n" + "\n".join(f'    property color {k}: "{v}"' for k, v in palette.items()) + "\n}\n"
    (qs / "modules/theme/Colors.qml").write_text(colors)
    _qmldirs(qs)
    # Config (qs.config)
    shutil.rmtree(qs / "config", ignore_errors=True)
    _module(tmp, "qs.config", {"Config": "pragma Singleton\nimport QtQuick\nimport qs.modules.theme\nQtObject {\n"
                               "    property int animDuration: 0\n    property string defaultFont: theme.font\n"
                               + _theme_config(preset) + AI_CONFIG +
                               "    function resolveColor(v) { if (!v) return 'transparent'; if (String(v).startsWith('#')) return v; return Colors[v] || 'transparent'; }\n}\n"})
    en = json.loads((REPO / "translations/en.json").read_text())
    services = qs / "modules/services"
    (services / "I18n.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject {\n    readonly property var table: (" + json.dumps(en) + ")\n"
                                       "    function t(k) { return table[k] !== undefined ? table[k] : k; }\n}\n")
    (services / "BackendService.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { property bool socketAvailable: true; function call(m, p, cb) {} function addSubscription(s, cb) { return 1; } }\n")
    (services / "KeyStore.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { function getKey(p) { return ''; } function getCustomCurl(p) { return ''; } }\n")
    (services / "Ai.qml").write_text(ai_stub)
    (services / "qmldir").write_text("module qs.modules.services\nsingleton Ai 1.0 Ai.qml\nsingleton I18n 1.0 I18n.qml\nsingleton BackendService 1.0 BackendService.qml\nsingleton KeyStore 1.0 KeyStore.qml\n")
    (qs / "modules/globals/GlobalStates.qml").write_text("""pragma Singleton
import QtQuick
QtObject {
    property bool assistantWide: false
    property bool assistantFullscreen: false
    property int assistantWidth: 400
    readonly property int assistantEffectiveWidth: assistantWide ? 1100 : assistantWidth
    property string assistantPosition: "right"
    property string assistantScreenName: "one"
    property bool assistantPinned: false
    property bool assistantVisible: true
    property string quickAskKind: "chat"
    property string aiSpace: "assistant"
    property string settingsCategory: ""
    property bool settingsWindowVisible: false
    property var quickAskAttachments: []
    property bool quickAskVisible: true
    signal assistantFocusRequested(bool wasAlreadyOpen)
    function hideQuickAsk() { quickAskVisible = false; }
    function hideAssistant() { assistantVisible = false; }
    function toggleAssistant() { assistantVisible = !assistantVisible; }
}
""")
    (qs / "modules/globals/qmldir").write_text("module qs.modules.globals\nsingleton GlobalStates 1.0 GlobalStates.qml\n")
    _module(tmp, "Quickshell", {
        "Quickshell": "pragma Singleton\nQtObject { property var screens: []; function env(n) { return n === 'HOME' ? '/home/user' : (n === 'USER' ? 'yuki' : ''); } }",
        "Singleton": "QtObject {}",
        "ShellScreen": "QtObject { property string name }",
    })
    _module(tmp, "Quickshell.Io", {
        "Process": "QtObject { property var command; property bool running; property var stdout; property var stderr; property var environment; signal exited(int exitCode, int exitStatus); signal started(); function signal(s) {} }",
        "SplitParser": "QtObject { signal read(string data) }",
        "StdioCollector": "QtObject { property string text; signal streamFinished() }",
        "FileView": "QtObject { property string path; property bool blockWrites; property bool atomicWrites; property bool printErrors; function setText(t) {} }",
    })
    _module(tmp, "Quickshell.Widgets", {"ClippingRectangle": "Rectangle { property bool contentUnderBorder }"})
    return tmp
