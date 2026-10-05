pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import qs.modules.bar.workspaces
import "Specials.js" as Specials

// Special workspaces at runtime (Hyprland scratchpads, config
// specials.workspaces; logic in Specials.js):
//   * opening a special (its bind, the dashboard, the launcher, the CLI)
//     launches its apps that are not running, straight into it, and moves
//     running ones in when the app says so; never twice while a launch is
//     pending (apps can take seconds to map a window, single-instance apps
//     fork: late windows are adopted and moved in);
//   * renaming a special moves its open windows to the new name;
//   * preload: at login the apps of specials with `preload` start hidden.
// On compositors without special workspaces everything is inert
// (`supported` false) and the UI hides itself.
Singleton {
    id: root

    readonly property bool supported: Specials.supported(YozdService.compositorName)
    readonly property bool ready: Config.specialsReady
    readonly property bool active: supported && ready && Config.specials.enabled
    readonly property var items: ready ? Array.from(Config.specials.workspaces || []).map(Specials.normalize) : []
    readonly property var names: Specials.hyprNames(items)
    // Plain `var` views of YozdService's list holders.
    readonly property var _clients: YozdService.clients
    readonly property var _workspaces: YozdService.workspaces
    readonly property var windows: Specials.windowsOf(_clients ? _clients.values : [], _workspaces ? _workspaces.values : [])
    readonly property var counts: Specials.counts(windows)
    // Hyprland names of the specials open on some monitor.
    readonly property var openNames: {
        const map = CompositorData.specialWorkspaceNames || {};
        return Object.keys(map).map(k => map[k]);
    }

    // appKey -> {deadline, name, match, known}
    property var pending: ({})
    property var _lastNames: ({})
    property var _lastOpen: []
    property bool _preloaded: false

    function nameOf(item) {
        return item ? (root.names[item.id] || "") : "";
    }

    function countOf(item) {
        return root.counts[root.nameOf(item)] || 0;
    }

    function isOpen(item) {
        return root.openNames.indexOf(root.nameOf(item)) !== -1;
    }

    // An item by id, display name or Hyprland name (case-insensitive).
    function find(ref) {
        const r = String(ref || "").replace(/^special:/, "");
        const byId = Specials.byId(root.items, r);
        if (byId)
            return byId;
        const lower = r.toLowerCase();
        return root.items.find(it => it.name.toLowerCase() === lower || root.nameOf(it).toLowerCase() === lower) || null;
    }

    // The item a Hyprland special name belongs to (bar indicator).
    function forHyprName(name) {
        return Specials.byHyprName(root.items, name);
    }

    function setItems(list) {
        Config.specials.workspaces = list;
    }

    // Opens (or closes) a special; its apps are made sure of first.
    function toggle(ref) {
        const item = root.find(ref);
        if (!item || !root.supported)
            return false;
        if (root.active && !root.isOpen(item))
            root.ensure(item);
        YozdService.toggleSpecial(root.nameOf(item));
        return true;
    }

    // Launch / move the item's apps per its plan (see Specials.plan).
    function ensure(item) {
        if (!root.active || !item)
            return;
        const name = root.nameOf(item);
        const now = Date.now();
        const steps = Specials.plan(item, name, root.windows, root.pending, now);
        if (steps.length === 0)
            return;
        const next = Object.assign({}, root.pending);
        steps.forEach(step => {
            if (step.kind === "move") {
                YozdService.moveToWorkspaceSilent(step.address, "special:" + name);
                return;
            }
            next[step.key] = {
                "deadline": now + Config.specials.launchTimeout,
                "name": name,
                "match": step.app.match,
                "known": root.windows.filter(w => Specials.classMatches(step.app.match, w.class)).map(w => w.address)
            };
            YozdService.execIn(step.app.command, "special:" + name + " silent");
        });
        root.pending = next;
        pendingSweep.restart();
    }

    function _adopt() {
        if (Object.keys(root.pending).length === 0)
            return;
        const res = Specials.adopt(root.pending, root.windows, Date.now());
        res.moves.forEach(m => YozdService.moveToWorkspaceSilent(m.address, "special:" + m.name));
        if (res.done.length === 0)
            return;
        const next = Object.assign({}, root.pending);
        res.done.forEach(k => delete next[k]);
        root.pending = next;
    }

    function _migrateRenames() {
        const now = root.names;
        if (root.active)
            Specials.renames(root._lastNames, now).forEach(r => {
                Specials.windowsOn(root.windows, r.from).forEach(a => YozdService.moveToWorkspaceSilent(a, "special:" + r.to));
            });
        root._lastNames = Object.assign({}, now);
    }

    function _openedChanged() {
        const before = root._lastOpen;
        root._lastOpen = root.openNames.slice();
        root.openNames.forEach(n => {
            if (before.indexOf(n) === -1)
                root.ensure(root.forHyprName(n));
        });
    }

    onWindowsChanged: root._adopt()
    onNamesChanged: root._migrateRenames()
    onOpenNamesChanged: root._openedChanged()
    onActiveChanged: {
        if (root.active && !root._preloaded)
            preloadTimer.restart();
    }

    property Timer pendingSweep: Timer {
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root._adopt();
            if (Object.keys(root.pending).length === 0)
                stop();
        }
    }

    // Preload once per session, after the compositor and the apps index
    // had time to settle.
    property Timer preloadTimer: Timer {
        interval: root.ready ? Config.specials.preloadDelay : 4000
        onTriggered: {
            if (!root.active || root._preloaded)
                return;
            root._preloaded = true;
            root.items.filter(it => it.preload).forEach(it => root.ensure(it));
        }
    }

    Component.onCompleted: {
        root._lastNames = Object.assign({}, root.names);
        if (root.active)
            preloadTimer.restart();
    }
}
