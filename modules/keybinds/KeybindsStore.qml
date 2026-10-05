pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.services
import "BindModel.js" as BindModel
import "../../config/CoreBinds.js" as CoreBinds
import "../../config/KeybindActions.js" as KeybindActions
import "../globals/BrandActions.js" as BrandActions
import "../specials/Specials.js" as Specials

// binds.json for the cheatsheet and the settings editor: rows (BindModel),
// conflicts (incl. the compositor's own binds from `hyprctl binds -j`) and
// the edits. Writes go to Config.keybindsLoader.adapter, which saves
// binds.json; the compositor TOML is then regenerated (CompositorTomlWriter
// -> backend -> yozd), so changes apply live.
Singleton {
    id: root

    // Bumped on every write and file reload: the adapter's list/var
    // properties do not always notify on in-place changes.
    property int revision: 0

    readonly property var adapter: Config.keybindsLoader ? Config.keybindsLoader.adapter : null
    readonly property var data: {
        root.revision;
        return root.snapshot();
    }
    // Rows carry the installed app's name/icon on "Open app" actions;
    // re-read when the desktop entries change.
    readonly property var rows: {
        AppSearch.list;
        return BindModel.withApps(BindModel.buildRows(data), root.appInfo);
    }
    property var hyprBinds: []
    readonly property var nativeBinds: BindModel.nativeBinds(hyprBinds, rows)
    readonly property var conflicts: BindModel.findConflicts(rows, nativeBinds)
    readonly property int conflictCount: Object.keys(conflicts).length

    // Row the editor should open (set by the cheatsheet's "Edit").
    property string pendingEdit: ""
    signal editRequested(string uid)

    // Settings editor state shared by its group cards: search filter and
    // the one expanded row.
    property string editorQuery: ""
    property string expandedUid: ""
    // Only conflicting rows (the toolbar's conflict chip).
    property bool conflictFilter: false
    // Rows the group cards show: search, then the conflict filter.
    function visibleRows(groupId) {
        const all = BindModel.filterRows(root.rows.filter(r => r.group === groupId), root.editorQuery, root.tr);
        return root.conflictFilter ? all.filter(r => !!root.conflicts[r.uid]) : all;
    }

    // Installed app by desktop id: {name, icon}, or null.
    function appInfo(id) {
        if (!id)
            return null;
        const e = DesktopEntries.byId ? DesktopEntries.byId(id) : null;
        if (e)
            return {
                "name": e.name || id,
                "icon": e.icon || ""
            };
        const hit = Array.from(AppSearch.list || []).find(a => a && a.id === id);
        return hit ? {
            "name": hit.name || id,
            "icon": hit.icon || ""
        } : null;
    }

    function tr(key) {
        return I18n.t(key);
    }

    // Special workspace binds (specials.json), as rows of kind "special".
    function specialRows() {
        if (!Config.specialsReady || !Config.specials.enabled)
            return [];
        return Specials.bindRows(Config.specials.workspaces);
    }

    function snapshot() {
        const a = root.adapter;
        if (!a)
            return {
                "root": null,
                "custom": [],
                "disabled": [],
                "specials": root.specialRows()
            };
        const appRoot = a[BrandActions.appId];
        const out = {};
        CoreBinds.BINDS.forEach(entry => {
            const bind = CoreBinds.lookup(appRoot, entry);
            if (!bind)
                return;
            const holder = entry.section ? (out[entry.section] = out[entry.section] || {}) : out;
            holder[entry.name] = {
                "modifiers": bind.modifiers ? Array.from(bind.modifiers) : [],
                "key": bind.key || "",
                "action": bind.action ? JSON.parse(JSON.stringify(bind.action)) : null
            };
        });
        return {
            "root": out,
            "custom": a.custom ? Array.from(a.custom).map(b => JSON.parse(JSON.stringify(b))) : [],
            "disabled": a.disabled ? Array.from(a.disabled) : [],
            "specials": root.specialRows()
        };
    }

    // Stand-in for a row that is going away (views sync after `rows`).
    readonly property var emptyRow: ({
            "uid": "",
            "kind": "custom",
            "path": "",
            "index": -1,
            "keys": [],
            "actions": [],
            "enabled": false,
            "name": "",
            "group": ""
        })

    function row(uid) {
        return rows.find(r => r.uid === uid) || null;
    }

    function title(r) {
        return r ? BindModel.title(r, root.tr) : "";
    }

    function conflictsOf(uid) {
        return conflicts[uid] || [];
    }

    // Human-readable conflict list for a row.
    function conflictText(uid) {
        return conflictsOf(uid).map(c => c.kind === "bind" ? root.title(root.row(c.uid)) : I18n.t("binds.conflict_native", c.text)).join("\n");
    }

    function isModified(r) {
        return !!r && r.kind === "core" && BindModel.isCoreModified(r);
    }

    // --- Writes --------------------------------------------------------

    function _changed() {
        root.revision++;
        CompositorTomlWriter.callWrite();
        nativeRefresh.restart();
    }

    function _coreObject(path) {
        const entry = CoreBinds.byPath(path);
        const a = root.adapter;
        if (!entry || !a)
            return null;
        return CoreBinds.lookup(a[BrandActions.appId], entry);
    }

    function _setCustomList(list) {
        if (!root.adapter)
            return;
        root.adapter.custom = list;
        root._changed();
    }

    function _custom() {
        return root.adapter && root.adapter.custom ? root.adapter.custom : [];
    }

    // A special workspace bind is stored on its item in specials.json.
    function _setSpecialKey(r, k) {
        const patch = {};
        patch[r.role] = {
            "modifiers": k && k.modifiers ? k.modifiers : [],
            "key": k && k.key ? k.key : ""
        };
        Config.specials.workspaces = Specials.withItem(Config.specials.workspaces, r.specialId, patch);
        root._changed();
    }

    // keys: [{modifiers, key}] (core binds keep the first one).
    function setKeys(uid, keys) {
        const r = root.row(uid);
        if (!r)
            return;
        if (r.kind === "special") {
            root._setSpecialKey(r, keys[0]);
        } else if (r.kind === "core") {
            const obj = root._coreObject(r.path);
            const k = keys[0] || {
                "modifiers": [],
                "key": ""
            };
            if (!obj)
                return;
            obj.modifiers = k.modifiers || [];
            obj.key = k.key || "";
            root._changed();
        } else {
            root._setCustomList(BindModel.withCustom(root._custom(), r.index, {
                "keys": keys.map(k => ({
                            "modifiers": k.modifiers || [],
                            "key": k.key || ""
                        }))
            }));
        }
    }

    // actions: [{id, args, layouts}] (core binds keep the first one).
    function setActions(uid, actions) {
        const r = root.row(uid);
        if (!r || !actions.length || r.kind === "special")
            return;
        if (r.kind === "core") {
            const obj = root._coreObject(r.path);
            if (!obj)
                return;
            obj.action = {
                "id": actions[0].id,
                "args": actions[0].args || {}
            };
            root._changed();
        } else {
            root._setCustomList(BindModel.withCustom(root._custom(), r.index, {
                "actions": BindModel.customBind("", [], actions).actions
            }));
        }
    }

    function setEnabled(uid, on) {
        const r = root.row(uid);
        if (!r || !root.adapter)
            return;
        // Switching a special bind off clears it (the row disappears; set
        // it again in the special workspaces settings).
        if (r.kind === "special") {
            if (!on)
                root._setSpecialKey(r, null);
            return;
        }
        if (r.kind === "core") {
            root.adapter.disabled = BindModel.withDisabled(root.adapter.disabled, r.path, on);
            root._changed();
        } else {
            root._setCustomList(BindModel.withCustom(root._custom(), r.index, {
                "enabled": on
            }));
        }
    }

    function setName(uid, name) {
        const r = root.row(uid);
        if (r && r.kind === "custom")
            root._setCustomList(BindModel.withCustom(root._custom(), r.index, {
                "name": name
            }));
    }

    function reset(uid) {
        const r = root.row(uid);
        if (!r || r.kind !== "core")
            return;
        const entry = CoreBinds.byPath(r.path);
        const obj = root._coreObject(r.path);
        if (!entry || !obj)
            return;
        const def = CoreBinds.defaultBind(entry);
        obj.modifiers = def.modifiers;
        obj.key = def.key;
        obj.action = def.action;
        if (!r.enabled)
            root.adapter.disabled = BindModel.withDisabled(root.adapter.disabled, r.path, true);
        root._changed();
    }

    // New custom bind running `actionId` (default: open an app); returns its uid.
    function addCustom(actionId) {
        const list = root._custom();
        root._setCustomList(BindModel.withAddedCustom(list, BindModel.newCustom(actionId)));
        return "custom:" + (Array.from(root._custom()).length - 1);
    }

    function remove(uid) {
        const r = root.row(uid);
        if (r && r.kind === "custom") {
            root.expandedUid = "";
            root._setCustomList(BindModel.withoutCustom(root._custom(), r.index));
        }
    }

    function reload() {
        if (Config.keybindsLoader)
            Config.keybindsLoader.reload();
        root.revision++;
        root.refreshNative();
    }

    // Opens the settings editor on a row (cheatsheet "Edit in settings").
    function requestEdit(uid) {
        root.pendingEdit = uid;
        root.editRequested(uid);
    }

    function actionGroup(id) {
        return KeybindActions.groupOf(id);
    }

    // Catalog actions for the picker; `withHidden` adds the raw dispatcher
    // (the editor's "Advanced" part).
    function actionOptions(withHidden) {
        const extra = withHidden ? [KeybindActions.getActionById("legacy.dispatcher")] : [];
        return KeybindActions.getActionOptions().concat(extra.map(a => ({
                    "id": a.id,
                    "label": a.label,
                    "category": a.category,
                    "group": a.group
                }))).map(o => Object.assign({}, o, {
                "text": BindModel.actionLabel(o.id, root.tr)
            }));
    }

    // --- Recording: compositor binds held off --------------------------------
    // While a recorder records, Hyprland sits in yozd's empty submap
    // (<app>-record, Ctrl+Alt+Escape leaves it), so every combo reaches the
    // recorder instead of firing the bind it already has.

    readonly property string recordSubmap: BrandActions.appId + "-record"
    property int recorders: 0
    signal recordTimedOut

    function holdCompositorBinds(on) {
        recorders = Math.max(0, recorders + (on ? 1 : -1));
        setSubmap(recorders > 0 ? recordSubmap : "reset");
        if (recorders > 0)
            holdTimeout.restart();
        else
            holdTimeout.stop();
    }

    // $1: the submap to enter ("reset" leaves).
    readonly property string submapScript: "hyprctl dispatch \"hl.dsp.submap(\\\"$1\\\")\" | grep -qx ok || hyprctl dispatch submap \"$1\""

    function setSubmap(name) {
        if (!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            return;
        // Lua-config Hyprland takes a Lua dispatcher, hyprlang the classic one.
        Quickshell.execDetached(["sh", "-c", root.submapScript, "sh", name]);
    }

    // A forgotten recorder never leaves the keyboard without binds.
    property Timer holdTimeout: Timer {
        interval: 60000
        onTriggered: {
            root.recorders = 0;
            root.setSubmap("reset");
            root.recordTimedOut();
        }
    }

    // A shell restart mid-recording leaves Hyprland in the submap.
    Component.onCompleted: {
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            Quickshell.execDetached(["sh", "-c", "[ \"$(hyprctl submap)\" = \"$1\" ] || exit 0; hyprctl dispatch \"hl.dsp.submap(\\\"reset\\\")\" | grep -qx ok || hyprctl dispatch submap reset", "sh", recordSubmap]);
    }

    // --- Compositor binds (conflict detection) ---------------------------

    function refreshNative() {
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") && !hyprctl.running)
            hyprctl.running = true;
    }

    property Process hyprctl: Process {
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    root.hyprBinds = Array.isArray(list) ? list : [];
                } catch (e) {
                    root.hyprBinds = [];
                }
            }
        }
    }

    // yozd applies a new TOML asynchronously.
    property Timer nativeRefresh: Timer {
        interval: 1500
        onTriggered: root.refreshNative()
    }

    property Connections fileConnections: Connections {
        target: Config.keybindsLoader
        function onLoaded() {
            root.revision++;
        }
        function onFileChanged() {
            root.revision++;
        }
    }
}
