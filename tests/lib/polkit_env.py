"""Offscreen environment for the in-shell polkit agent (modules/polkit).

KitEnv (real kit, Config from config/defaults, Colors, I18n en) plus:
  * Quickshell.Services.Polkit - PolkitAgent / AuthFlow stubs with exactly
    the members of Quickshell's own types (POLKIT_MEMBERS, from
    quickshell-service-polkit.qmltypes; tests/polkit-agent.test.py checks
    them against the installed file when one is found). The stub flow
    changes state only through the methods the real AuthFlow has
    (request / completed / showError / showInfo, what the agent's
    listener calls) and reports submit / cancel to `PolkitLog`, a test
    singleton, never to members of its own.
  * Quickshell: Scope, Variants (an Instantiator), ShellScreen.
  * GlobalStates with lockscreenVisible and focusedScreenName().
  * BackendService: records notify() calls (`sent`), socketAvailable.
  * modules/polkit mirrored as qs.modules.polkit, the real PolkitService.

Used by tests/polkit-agent.test.py and tools/render/polkit_render.py.
"""
from __future__ import annotations

import os
import shutil
from pathlib import Path

from qmlharness import REPO, process_role_qml  # first: enters the headless platform
from kit_env import KitEnv
from settings_env import QUICKSHELL, global_states_qml

# Members of Quickshell 0.3.x's polkit types (qmltypes: properties,
# signals incl. *Changed, methods). The stubs below declare these and no
# others (QtObject's own objectName aside).
POLKIT_MEMBERS = {
    "AuthFlow": {
        "properties": ["message", "iconName", "actionId", "cookie", "identities", "selectedIdentity",
                       "isResponseRequired", "inputPrompt", "responseVisible", "supplementaryMessage",
                       "supplementaryIsError", "isCompleted", "isSuccessful", "isCancelled", "failed"],
        "signals": ["authenticationSucceeded", "authenticationFailed", "authenticationRequestCancelled"],
        "methods": ["request", "completed", "showError", "showInfo", "submit", "cancelAuthenticationRequest"],
    },
    "PolkitAgent": {
        "properties": ["path", "isRegistered", "isActive", "flow"],
        "signals": ["authenticationRequestStarted"],
        "methods": [],
    },
}

AUTH_FLOW = """import QtQuick
import qs.polkittest
QtObject {
    id: flow
    property string message
    property string iconName
    property string actionId
    property string cookie
    property var identities: []
    property var selectedIdentity: null
    property bool isResponseRequired: false
    property string inputPrompt
    property bool responseVisible: false
    property string supplementaryMessage
    property bool supplementaryIsError: false
    property bool isCompleted: false
    property bool isSuccessful: false
    property bool isCancelled: false
    property bool failed: false
    signal authenticationSucceeded
    signal authenticationFailed
    signal authenticationRequestCancelled

    // What the agent's listener calls (polkit's session asks / ends)
    function request(message, echo) {
        inputPrompt = message;
        responseVisible = echo;
        isResponseRequired = true;
    }
    function completed(gainedAuthorization) {
        isResponseRequired = false;
        if (gainedAuthorization) {
            isCompleted = true;
            isSuccessful = true;
            authenticationSucceeded();
        } else {
            failed = true;
            authenticationFailed();
        }
    }
    function showError(message) {
        supplementaryMessage = message;
        supplementaryIsError = true;
    }
    function showInfo(message) {
        supplementaryMessage = message;
        supplementaryIsError = false;
    }
    // Like Quickshell's setSelectedIdentity: a started session is ended
    // (completed(false) on the spot: `failed`) and a new one asks again.
    onSelectedIdentityChanged: {
        if (inputPrompt !== "" && !isCompleted) {
            completed(false);
            request(inputPrompt, responseVisible);
        }
    }
    // The QML API
    // Like Quickshell's: `failed` stays set for the rest of the flow and
    // polkit's last message stays until polkit sends another one.
    function submit(value) {
        isResponseRequired = false;
        PolkitLog.submitted(flow, value);
    }
    function cancelAuthenticationRequest() {
        if (isCompleted)
            return;
        PolkitLog.cancelled(flow);
        isResponseRequired = false;
        isCancelled = true;
        isCompleted = true;
        authenticationRequestCancelled();
    }
}"""

POLKIT_AGENT = """import QtQuick
QtObject {
    property string path: "/org/quickshell/PolkitAgent"
    property bool isRegistered: false
    property bool isActive: flow !== null
    property AuthFlow flow: null
    signal authenticationRequestStarted
    onFlowChanged: if (flow) authenticationRequestStarted()
}"""

# The test's record of what the code under test did to a flow.
POLKIT_LOG = """pragma Singleton
import QtQuick
QtObject {
    property int submits: 0
    property int cancels: 0
    property var lastFlow: null
    // Compared, never rendered or printed (a stand-in password in tests).
    property string lastValue: ""
    function submitted(flow, value) { submits++; lastFlow = flow; lastValue = value; }
    function cancelled(flow) { cancels++; lastFlow = flow; }
    function reset() { submits = 0; cancels = 0; lastFlow = null; lastValue = ""; }
}"""

QUICKSHELL_EXTRA = {
    "Scope": "QtObject { default property list<QtObject> data }",
    # Quickshell's Variants: one delegate per model entry, `modelData` set
    "Variants": "Instantiator { id: v; default property alias delegateComponent: v.delegate }",
    "ShellScreen": "QtObject { property string name; property int width: 1920; property int height: 1080 }",
}

# The daemon client: what the host reports is recorded.
BACKEND_SERVICE = """pragma Singleton
import QtQuick
QtObject {
    property bool socketAvailable: true
    property var sent: []
    function notify(method, params) { sent = sent.concat([{ method: method, params: params }]) }
    function call(method, params, cb) { notify(method, params) }
}"""

# Stand-in for the layer window: what the agent scope hands it is recorded.
WINDOW_STUB = """import QtQuick
import Quickshell
Item {
    objectName: "polkitWindow"
    property ShellScreen targetScreen
    property var flow
}"""


class PolkitEnv(KitEnv):
    def __init__(self, name: str = "polkit", *, window_stub: bool = True, role: str = "", **kw):
        super().__init__(name, **kw)
        h = self.h
        qs = self.root / "qs"
        qs_single = QUICKSHELL["Quickshell"].replace("QtObject { ", "QtObject { property int processId: 4242; ", 1)
        h.module("Quickshell", {**QUICKSHELL, **QUICKSHELL_EXTRA, "Quickshell": qs_single})
        h.module("Quickshell.Services.Polkit", {"AuthFlow": AUTH_FLOW, "PolkitAgent": POLKIT_AGENT})
        h.module("qs.polkittest", {"PolkitLog": POLKIT_LOG})
        gs = global_states_qml({}).replace(
            "    id: gs\n",
            "    id: gs\n    property bool lockscreenVisible: false\n    property string focused: \"\"\n"
            "    function focusedScreenName() { return focused }\n", 1)
        # `role`: the process (ProcessRole; "" = the main shell, "settings" /
        # "onboarding" = a separate window process of performance.separateWindows).
        h.module("qs.modules.globals", {"GlobalStates": gs, "ProcessRole": process_role_qml(role)})
        h.module("qs.modules.services", {"PolkitService": (REPO / "modules/services/PolkitService.qml").read_text(),
                                         "BackendService": BACKEND_SERVICE})
        cfg = qs / "config" / "Config.qml"
        cfg.write_text(cfg.read_text().replace("    property bool keyboardReady: true\n",
                                               "    property bool keyboardReady: true\n    property bool systemReady: true\n", 1))
        dst = qs / "modules/polkit"
        shutil.copytree(REPO / "modules/polkit", dst, dirs_exist_ok=True)
        if window_stub:
            (dst / "PolkitWindow.qml").write_text(WINDOW_STUB)
        self._qmldir(dst, "qs.modules.polkit")


def installed_qmltypes() -> Path | None:
    """Quickshell's polkit type metadata, where a Quickshell is installed
    (or QMLLINT_IMPORT_PATH points at one)."""
    rel = "Quickshell/Services/Polkit/quickshell-service-polkit.qmltypes"
    for d in [*os.environ.get("QMLLINT_IMPORT_PATH", "").split(":"), "/usr/lib/qt6/qml", "/usr/lib/qt-6/qml"]:
        if d and (Path(d) / rel).is_file():
            return Path(d) / rel
    return None
