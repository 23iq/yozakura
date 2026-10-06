"""Offscreen environment for the terminal look UI (modules/terminal, the
Settings > Terminal & Apps prompt section).

Extends ExtrasEnv (real ExtrasService, settings components) with the real
TerminalLookService and a scripted BackendService whose `term.preview`
answers depend on the request: `previews` maps "engine:prompt" (or
"prompt", or "*") to a result. Calls are recorded in `calls`.

Used by tests/terminal-look-ui.test.py and tools/render/terminal_render.py.
"""
from __future__ import annotations

import json

from extras_env import ExtrasEnv
from qmlharness import REPO

BACKEND = """pragma Singleton
QtObject {
    property var calls: []
    property var replies: ({})
    property var previews: ({})
    property var subs: []
    function call(method, params, cb) {
        calls = calls.concat([{method: method, params: params}]);
        let r = replies[method];
        if (method === "term.preview") {
            const p = params || {};
            r = previews[p.engine + ":" + p.prompt] || previews[p.prompt] || previews["*"];
        }
        if (Array.isArray(r) && method !== "term.presets") {
            const rest = r.slice(1);
            const next = Object.assign({}, replies);
            next[method] = rest.length > 0 ? rest : r[0];
            replies = next;
            r = r[0];
        }
        if (!cb)
            return;
        if (r !== undefined && r !== null && r.error) cb(null, r.error);
        else cb(r === undefined ? null : r, null);
    }
    function addSubscription(services, cb) { subs = subs.concat([cb]); return subs.length; }
    function emit(service, data) { subs.forEach(cb => cb(service, data)); }
}"""

PRESETS = [
    {"id": "sakura-powerline", "name": "Sakura Powerline", "description": "term.prompt.sakura-powerline.desc",
     "nerdFont": True, "lines": 1},
    {"id": "two-line-box", "name": "Two-Line Box", "description": "term.prompt.two-line-box.desc",
     "nerdFont": True, "lines": 2},
    {"id": "plain", "name": "Plain", "description": "term.prompt.plain.desc", "nerdFont": False, "lines": 1},
]

STATUS = {"enabled": False, "engine": "starship", "fishInstalled": True, "fishIsLoginShell": True,
          "engineInstalled": {"starship": True, "ohmyposh": False}, "foreignPromptInit": False,
          "hookPath": "/home/user/.config/fish/conf.d/yozakura.fish", "hookPresent": False}


def span(text, fg="", bg="", bold=False):
    out = {"text": text}
    if fg:
        out["fg"] = fg
    if bg:
        out["bg"] = bg
    if bold:
        out["bold"] = True
    return out


def sample_previews(exact: bool = True, engine: str = "starship") -> dict:
    """Small hand-made previews of PRESETS (palette-like hex colors)."""
    reason = "" if exact else "engine_missing"

    def res(left, right=None):
        return {"left": left, "right": right or [], "exact": exact, "engine": engine, "reason": reason}

    return {
        "sakura-powerline": res([[span(" \uf303 ", "#520e62", "#f5adff"), span("\ue0b0", "#f5adff", "#e0bbe2"),
                                  span(" ~/yozakura ", "#412745", "#e0bbe2", True), span("\ue0b0", "#e0bbe2"),
                                  span(" "), span("❯", "#f5adff", bold=True), span(" ")]],
                                [span("3s", "#ffb2bd")]),
        "two-line-box": res([[span("╭─ ", "#9f8c8d"), span("~/yozakura", "#f5adff", bold=True)],
                             [span("╰─ ", "#9f8c8d"), span("❯ ", "#f5adff", bold=True)]]),
        "plain": res([[span("~/yozakura", "#f5adff"), span(" on "), span("main", "#ffb2bd"), span(" > ")]]),
    }


class TerminalEnv(ExtrasEnv):
    def __init__(self, name: str = "terminal", *, presets=None, previews=None, status=None, replies=None, **kw):
        replies = {"term.presets": PRESETS if presets is None else presets,
                   "term.status": STATUS if status is None else status,
                   "term.apply": STATUS if status is None else status,
                   "extras.setLoginShell": {"jobs": []},
                   **(replies or {})}
        super().__init__(name, replies=replies, **kw)
        # ExtrasEnv baked every reply (catalog, status, ours) into its
        # BackendService: keep them, add the request-dependent previews.
        baked = (self.root / "qs/modules/services/BackendService.qml").read_text()
        start = baked.index("property var replies: (") + len("property var replies: (")
        all_replies = baked[start:baked.index(")\n", start)]
        backend = (BACKEND.replace("property var replies: ({})", "property var replies: (" + all_replies + ")", 1)
                   .replace("property var previews: ({})",
                            "property var previews: (" + json.dumps(previews if previews is not None else sample_previews()) + ")", 1))
        self.h.module("qs.modules.services", {
            "BackendService": backend,
            "TerminalLookService": (REPO / "modules/services/TerminalLookService.qml").read_text()})
