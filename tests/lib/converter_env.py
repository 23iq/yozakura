"""Offscreen environment for the file converter window (modules/converter).

KitEnv (real kit, Config from config/defaults, Colors, I18n en) plus the
converter module mirrored as qs.modules.converter and a scripted
BackendService for the backend `convert` service:
  * convert.probe answers from PROBE (tests/fixtures/converter-probe.json,
    made by the real backend probe with ffmpeg, ImageMagick, LibreOffice
    and poppler but no pandoc), keyed by file name;
  * convert.start answers queued jobs c1, c2, ... (held until
    flushStart() while `deferStart`: a job event can beat the reply);
  * convert.paste answers `pasteReply`;
  * every call is recorded in `calls`; `emit(service, data)` pushes a
    subscription event (convert.job).

Used by tests/converter-ui.test.py and tools/render/converter_render.py.
"""
from __future__ import annotations

import json
import shutil

from qmlharness import REPO
from kit_env import KitEnv

PROBE = json.loads((REPO / "tests/fixtures/converter-probe.json").read_text())

BACKEND = """pragma Singleton
QtObject {
    property var calls: []
    property var probe: ({})
    property var pasteReply: ({ "paths": [] })
    property string pasteError: ""
    property int seq: 0
    property var subs: []
    // deferStart: hold the start reply until flushStart() (events may come first)
    property bool deferStart: false
    property var heldStart: null
    function flushStart() { const h = heldStart; heldStart = null; if (h) h.cb(h.r, null); }
    function call(method, params, cb) {
        calls = calls.concat([{ method: method, params: params }]);
        let r = {};
        let err = null;
        if (method === "convert.probe") {
            r = { files: params.paths.map(p => {
                const name = p.substring(p.lastIndexOf("/") + 1);
                return probe[name] ? Object.assign({}, probe[name], { path: p })
                    : { path: p, name: name, size: 0, targets: [], error: "unknown format" };
            }) };
        } else if (method === "convert.start") {
            r = { jobs: params.items.map(it => {
                seq++;
                return { id: "c" + seq, path: it.path, name: it.path.substring(it.path.lastIndexOf("/") + 1),
                         to: it.target, state: "queued", progress: -1 };
            }) };
        } else if (method === "convert.paste") {
            if (pasteError !== "") err = pasteError; else r = pasteReply;
        }
        if (method === "convert.start" && deferStart && cb) {
            heldStart = { cb: cb, r: r };
            return;
        }
        if (cb) cb(err ? null : r, err);
    }
    function callOk(method, params, onOk, tag) { call(method, params, (r, e) => { if (!e && onOk) onOk(r); }); }
    function addSubscription(services, cb) { subs = subs.concat([cb]); return subs.length; }
    function removeSubscription(key) {}
    function emit(service, data) { subs.forEach(cb => cb(service, data)); }
}"""


class ConverterEnv(KitEnv):
    def __init__(self, name: str = "converter", **kw):
        super().__init__(name, **kw)
        qs = self.root / "qs"
        shutil.copytree(REPO / "modules/converter", qs / "modules/converter", dirs_exist_ok=True)
        self._qmldir(qs / "modules/converter", "qs.modules.converter")
        self.h.module("qs.modules.services", {"BackendService": BACKEND.replace("property var probe: ({})", "property var probe: (" + json.dumps(PROBE) + ")", 1)})

    def scene(self, w: int = 560, h: int = 580):
        """A window holding the converter view (objectName "view")."""
        return self.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.converter
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    ConverterView {{ objectName: "view"; anchors.fill: parent; focus: true }}
}}""")
