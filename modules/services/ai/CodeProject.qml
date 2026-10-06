import QtQuick
import Quickshell
import qs.config
import qs.modules.services

// The Code space's project folder: one first-class value (persisted as
// StateService `aiCodeProject`) read by the project bar, the task board,
// TasksService calls and every new agent session of the Code space. It is
// not an agent override, so switching agents keeps it.
QtObject {
    id: root
    property var owner
    property string stored: ""
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dir: stored || Config.ai.agents.defaultCwd || ((Config.ai.agents.recentDirs || [])[0] || "") || home

    // "~/x", trailing slashes and empty input normalised to an absolute path.
    function normalize(path) {
        let p = String(path || "").trim();
        if (p === "~" || p.indexOf("~/") === 0)
            p = home + p.substring(1);
        while (p.length > 1 && p.endsWith("/"))
            p = p.substring(0, p.length - 1);
        return p.indexOf("/") === 0 ? p : "";
    }

    function init() {
        if (StateService.initialized)
            stored = StateService.get("aiCodeProject", "") || "";
    }

    // Makes `path` the project (persisted, first in the recent folders).
    // Returns the normalised path ("" when it is not a usable path).
    function set(path) {
        const p = normalize(path);
        if (!p)
            return "";
        if (p !== stored) {
            stored = p;
            if (StateService.initialized)
                StateService.set("aiCodeProject", p);
        }
        if (owner && owner.agents)
            owner.agents.rememberDir(p);
        return p;
    }

    readonly property Connections stateConnection: Connections {
        target: StateService
        function onInitializedChanged() {
            if (StateService.initialized && !root.stored)
                root.init();
        }
    }
}
