"""Offscreen environment for the launcher prefix tabs (clipboard, emoji, tmux,
notes in modules/widgets/dashboard/).

LauncherEnv with the real tabs in place of its stand-ins, plus fixtures:
a ClipboardService holding sample history (`CLIP_ITEMS`), a TerminalService,
and a fake Quickshell.Io Process that answers `tmux` from sample sessions,
keeps notes in an in-memory file system (`TabsFixture.files`) and reads any
other `cat` target from disk (the emoji table). Every command is recorded in
`TabsFixture.log`; service calls in `ClipboardService.calls`.

Used by tools/render/launcher_render.py (tab-* names).
"""
from __future__ import annotations

import json
import os
import shutil
import time

os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
from launcher_env import LauncherEnv  # noqa: E402
from qmlharness import REPO  # noqa: E402

TABS = {"clipboard": 1, "emoji": 2, "tmux": 3, "notes": 4}

_NOW = int(time.time() * 1000)
CLIP_ITEMS = [
    {"id": "1", "preview": "git rebase -i origin/main --autosquash", "mime": "text/plain", "createdAt": _NOW - 60_000},
    {"id": "2", "preview": "https://github.com/quickshell-mirror/quickshell", "mime": "text/plain",
     "createdAt": _NOW - 600_000},
    {"id": "3", "preview": "[Image]", "mime": "image/png", "isImage": True, "createdAt": _NOW - 3_600_000},
    {"id": "4", "preview": "file:///home/user/Documents/report-q3.pdf", "mime": "text/uri-list", "isFile": True,
     "createdAt": _NOW - 7_200_000},
    {"id": "5", "preview": "Meeting moved to Thursday 15:00, same room", "mime": "text/plain", "pinned": True,
     "alias": "Meeting", "createdAt": _NOW - 86_400_000},
    {"id": "6", "preview": "#e0af68", "mime": "text/plain", "createdAt": _NOW - 2 * 86_400_000},
    {"id": "7", "preview": "export PATH=\"$HOME/.local/bin:$PATH\"", "mime": "text/plain",
     "createdAt": _NOW - 3 * 86_400_000},
]

NOTES_INDEX = {"order": ["n1", "n2", "n3"], "notes": {
    "n1": {"title": "Design review", "created": "2026-10-01T10:00:00Z", "modified": "2026-10-06T18:20:00Z",
           "isMarkdown": True},
    "n2": {"title": "Groceries", "created": "2026-10-02T09:00:00Z", "modified": "2026-10-05T08:10:00Z"},
    "n3": {"title": "Ideas for the weekend", "created": "2026-10-03T21:00:00Z", "modified": "2026-10-03T21:30:00Z"},
}}
NOTES_FILES = {
    "n1.md": "# Design review\n\n- Launcher: grouped results, one divider\n- Tabs from the kit\n\n**Next:** polish",
    "n2.html": "<p>Milk, eggs, rice, green tea</p>",
    "n3.html": "<p>Hike to the lake, try the new ramen place</p>",
}

CLIPBOARD_SERVICE = """pragma Singleton
import QtQuick
QtObject {
    property var items: %s
    property var linkPreviewCache: ({})
    property int revision: 0
    property var calls: []
    property var images: ({})
    // list() answers with listCompleted (tests that drive it by hand: false)
    property bool autoComplete: true
    signal listCompleted()
    signal fullContentRetrieved(string itemId, string content)
    signal linkPreviewFetched(string url, var metadata, string itemId)
    function rec(name, a, b) { calls = calls.concat([[name, a === undefined ? null : a, b === undefined ? null : b]]); }
    function list() { rec("list"); if (autoComplete) Qt.callLater(listCompleted); }
    function getFullContent(id) { rec("getFullContent", id); }
    function fetchLinkPreview(url, id) { rec("fetchLinkPreview", url, id); }
    function deleteItem(id) { rec("deleteItem", id); }
    function clear() { rec("clear"); }
    function togglePin(id) { rec("togglePin", id); }
    function setAlias(id, a) { rec("setAlias", id, a); }
    function moveItemUp(id) { rec("moveItemUp", id); }
    function moveItemDown(id) { rec("moveItemDown", id); }
    function copyItem(id, mime) { rec("copyItem", id, mime); }
    function decodeToDataUrl(id, mime) { rec("decodeToDataUrl", id, mime); }
    function copyAndTypeEmoji(t) { rec("copyAndTypeEmoji", t); }
    function getImageData(id) { return images[id] || ""; }
    function requestImagePath(id) { rec("requestImagePath", id); }
    function getImagePath(id) { return ""; }
}"""

FIXTURE = """pragma Singleton
QtObject {
    property var log: []
    property var sessions: ["main", "work", "dotfiles"]
    property var files: (%s)
    function readDisk(path) {
        const x = new XMLHttpRequest();
        x.open("GET", "file://" + path, false);
        try { x.send(); } catch (e) { return null; }
        return x.responseText || null;
    }
    function respond(cmd) {
        log = log.concat([cmd.join(" ")]);
        if (cmd[0] === "tmux") {
            const sub = cmd[1];
            if (sub === "list-sessions")
                return { code: 0, out: sessions.join("\\n") + "\\n" };
            if (sub === "list-windows")
                return { code: 0, out: "0:zsh:0\\n1:nvim:1\\n2:logs:0\\n" };
            if (sub === "list-panes")
                return { code: 0, out: "0:80:24:0:0:1:nvim\\n1:79:24:0:81:0:zsh\\n" };
            return { code: 0, out: "" };
        }
        if (cmd[0] === "cat") {
            const path = cmd[cmd.length - 1];
            for (const k in files)
                if (path.endsWith("/" + k))
                    return { code: 0, out: files[k] };
            const disk = readDisk(path);
            return disk === null ? { code: 1, out: "" } : { code: 0, out: disk };
        }
        if (cmd[0] === "sh" && cmd[3] === "emoji-recent")
            return { code: 0, out: JSON.stringify(["\\u2728", "\\ud83c\\udf38", "\\ud83d\\udc4d", "\\ud83d\\ude02", "\\ud83d\\udd25", "\\ud83c\\udf75", "\\ud83c\\udf19"]
                .map(e => ({ emoji: e, name: e, slug: e, group: "", search: e }))) };
        if (cmd[0] === "sh" && cmd[3] === "notes-write") {
            const a = cmd.slice(4);
            files[a[0].split("/").pop()] = a[1];
        }
        return { code: 0, out: "" };
    }
}"""

# StdioCollector (text + streamFinished) and SplitParser (read per line).
PROCESS = """import QtQuick
import tabsfixture
QtObject {
    id: p
    property var command: []
    property bool running: false
    property var stdout: null
    property var stderr: null
    signal exited(int exitCode, int exitStatus)
    onRunningChanged: if (running) Qt.callLater(p.run)
    function run() {
        const r = TabsFixture.respond(p.command);
        if (p.stdout) {
            if (typeof p.stdout.read === "function") {
                const lines = r.out.split("\\n");
                if (lines.length > 1 && lines[lines.length - 1] === "")
                    lines.pop();
                for (let i = 0; i < lines.length && r.out !== ""; i++)
                    p.stdout.read(lines[i]);
            } else {
                p.stdout.text = r.out;
                p.stdout.streamFinished();
            }
        }
        p.running = false;
        p.exited(r.code, 0);
    }
}"""


class TabsEnv(LauncherEnv):
    def __init__(self, name: str = "tabs", *, clip_items: list[dict] | None = None,
                 tabs: list[str] | None = None, **kw):
        """`tabs`: the real tabs to load (default all; the others keep
        LauncherEnv's stand-ins)."""
        super().__init__(name, **kw)
        qs = self.root / "qs"
        for tab in TABS if tabs is None else tabs:
            rel = f"modules/widgets/dashboard/{tab}"
            shutil.copytree(REPO / rel, qs / rel, dirs_exist_ok=True)
        (qs / "assets").mkdir(exist_ok=True)
        shutil.copy(REPO / "assets/emojis.json", qs / "assets/emojis.json")
        files = {"index.json": json.dumps(NOTES_INDEX), **NOTES_FILES}
        self.h.module("tabsfixture", {"TabsFixture": FIXTURE % json.dumps(files)})
        items = [{"isImage": False, "isFile": False, "pinned": False, "alias": "", "binaryPath": "", **i}
                 for i in (CLIP_ITEMS if clip_items is None else clip_items)]
        self.h.module("qs.modules.services", {
            "ClipboardService": CLIPBOARD_SERVICE % json.dumps(items),
            "TerminalService": "pragma Singleton\nQtObject { property var ran: []; "
                               "function execDetached(c) { ran = ran.concat([c]); } }",
        })
        self.h.module("Quickshell.Io", {"Process": PROCESS,
                                        "SplitParser": "QtObject { signal read(string data) }"})
