"""Offscreen environment for the sentence bar (modules/bar/modules/Sentence).

IslandEnv (real bar, kit, islandchips popups, a playing player) with the
notch off, the real translations of one language (I18n with plural forms),
a network, three notifications and a GlobalShortcuts that records what it
ran. Used by tests/bar-sentence.test.py and tools/render/sentence_render.py.

    env, win, svc = sentence_scene("x", edge="top", width=1600, lang="ru")
"""
from __future__ import annotations

import json

from island_env import IslandEnv
from panels_env import PanelsEnv
from panels_stubs import GLOBAL_STATES
from PySide6.QtTest import QTest
from qmlharness import REPO


def i18n_qml(lang: str) -> str:
    en = json.loads((REPO / "translations/en.json").read_text())
    own = json.loads((REPO / f"translations/{lang}.json").read_text()) if lang != "en" else {}
    plural = (REPO / "modules/services/Plural.js").read_text().replace(".pragma library", "")
    return ("pragma Singleton\nimport QtQuick\nQtObject {\n"
            f"    property string resolvedLanguage: {json.dumps(lang)}\n"
            f"    property var strings: ({json.dumps(own, ensure_ascii=False)})\n"
            f"    property var fallback: ({json.dumps(en, ensure_ascii=False)})\n"
            f"    property var availableLanguages: ({(REPO / 'translations/languages.json').read_text()})\n"
            "    function detectSystemLanguage() { return resolvedLanguage }\n"
            "    function has(key) { return strings[key] !== undefined || fallback[key] !== undefined }\n"
            "    function t(key) { let s = strings[key] ?? fallback[key] ?? key;"
            " for (let i = 1; i < arguments.length; i++) s = s.replace('%' + i, arguments[i]); return s }\n"
            "    function tn(key, n) { const c = category(resolvedLanguage, n);"
            " const k = [key + '.' + c, key + '.other', key].find(x => has(x)) ?? key; return t(k, n) }\n"
            + "\n".join("    " + line for line in plural.strip().splitlines()) + "\n}\n")


SERVICES = {
    "NetworkService": """pragma Singleton
QtObject {
    property bool ethernet: false; property string wifiStatus: "connected"
    property string networkName: "Hanami"; property int networkStrength: 80
}""",
    "GlobalShortcuts": """pragma Singleton
QtObject {
    property var ran: []
    function run(c) { ran = ran.concat([c]) }
    function toggleSettings(s) { ran = ran.concat(["settings"]) }
}""",
    "Notifications": """pragma Singleton
QtObject {
    property var notchPopupList: []; property var popupList: []
    property var list: [{ id: 1 }, { id: 2 }, { id: 3 }]
    property bool silent: false; property var appNameList: ["Telegram"]
    property var groupsByAppName: ({ "Telegram": { appName: "Telegram", notifications: [
        { id: 1, appName: "Telegram", appIcon: "telegram", summary: "Mira Tanaka", body: "Sent the deck", image: "" }] } })
    function toggleDnd() { silent = !silent }
    function showsOnScreen(name) { return true }
    function activateNotification(id) {} function attemptInvokeAction(id, a) {}
    function discardNotification(id) {} function discardNotifications(ids) {} function discardAllNotifications() {}
    function notifyInternal() {} function timeoutNotification(id) {} function pauseTimeout(id) {}
    function resumeTimeout(id) {} function pauseAllTimers() {} function resumeAllTimers() {}
}""",
}

# The playing track of the fixture player (IslandEnv: M83, Midnight City)
TRACK = ("Nujabes", "Aruarian Dance")


def bar(edge: str, style: str = "classic", options: dict | None = None) -> dict:
    return {"frameEnabled": False, "containBar": False, "pinnedOnStartup": True,
            "moduleOptions": {**_defaults_options(), "sentence": {**_defaults_options()["sentence"], **(options or {})}},
            "panels": [{"id": "main", "edge": edge, "style": style,
                        "groups": {"start": ["launcher", "sentence"], "end": ["power"]}}]}


def _defaults_options() -> dict:
    from settings_env import load_defaults
    return load_defaults()["bar"]["moduleOptions"]


def sentence_panels_env(name: str, lang: str = "en", **kw) -> IslandEnv:
    """A PanelsEnv-compatible environment (same keyword arguments) with what
    a bar holding the sentence module reads: its popups, the fixture player,
    notifications and the real strings of `lang`. Draw it with
    PanelsEnv.scene(env, ...)."""
    env = IslandEnv(name, **kw)
    env.h.module("qs.modules.services", {**SERVICES, "I18n": i18n_qml(lang)})
    env.h.module("qs.modules.globals", {"GlobalStates": GLOBAL_STATES.replace(
        "QtObject {", "QtObject {\n    property string settingsCategory: \"\"\n    property bool settingsWindowVisible: false", 1)})
    return env


def uses_sentence(bar: dict) -> bool:
    """True when one of bar.panels holds the sentence module."""
    return any("sentence" in mods for p in bar.get("panels") or [] for mods in (p.get("groups") or {}).values())


def sentence_scene(name: str, *, edge: str = "top", width: int = 1600, height: int = 900, lang: str = "en",
                   language: str = "ink", palette: dict | None = None, style: str = "classic",
                   options: dict | None = None, notch: bool = False, art: str = "", type_cfg: dict | None = None):
    theme = {"language": language}
    if type_cfg:
        theme["type"] = type_cfg
    env = sentence_panels_env(name, lang, art=art, bar=bar(edge, style, options), theme=theme,
                              notch={"enabled": notch, "keepHidden": not notch, "position": "top"}, palette=palette)
    win = PanelsEnv.scene(env, width, height, windows=False)
    svc = env.h.load("import QtQuick\nimport qs.config\nimport qs.modules.services\nimport qs.modules.globals\nQtObject {}")
    env.h.eval(svc, f"MprisController.player.trackArtist = {json.dumps(TRACK[0])}; "
                    f"MprisController.player.trackTitle = {json.dumps(TRACK[1])}")
    QTest.qWait(700)
    return env, win, svc


def find(item, name: str):
    if item.objectName() == name:
        return item
    for child in item.childItems():
        hit = find(child, name)
        if hit is not None:
            return hit
    return None
