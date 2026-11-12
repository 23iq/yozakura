pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services
import "../SchemaUtil.js" as SchemaUtil
import "../ConfigWrite.js" as ConfigWrite
import "../SettingsDefaults.js" as SettingsDefaults
import "../CompositorGate.js" as CompositorGate
import "../ResetModel.js" as ResetModel
import "../UndoModel.js" as UndoModel
import "../schema/Categories.js" as Categories
import "../DisabledReason.js" as DisabledReason

// Read/write access to settings keys for the settings window and the setup
// wizard.
//
// Change flow (modules/settings/AGENTS.md, CHANGE FLOW):
//   set()       live: the value goes into Config at once (the whole shell
//               follows) and is persisted by the domain's own coalesced
//               auto-save (ConfigFile: at most a few writes per second
//               while a slider moves). The change is kept on the session
//               undo history (undo / redo, the window's undo pill).
//   stageSet()  the setup wizard only: staged like the old Apply flow (the
//               GlobalStates snapshot of the domain is taken and its
//               auto-save paused; a separate wizard process relays it to
//               the main shell through the daemon's `preview` service), so
//               the wizard's choices are written by apply() when it ends.
// Wallpaper keys (wallpapers.json) always go to the wallpaper manager.
Singleton {
    id: root

    readonly property var themeDomains: ["theme"]
    readonly property var compositorDomains: ["compositor"]
    readonly property var shellDomains: Object.keys(GlobalStates._shellSections || {})

    // The wizard's staged changes wait for apply() / discard().
    readonly property bool hasChanges: GlobalStates.themeHasChanges || GlobalStates.shellHasChanges || GlobalStates.compositorHasChanges

    // Set by the settings window to flash an entry after a search jump.
    property string highlightedEntry: ""
    // The row under the pointer or keyboard focus: its keys light up the
    // part of the page's stage they change (StageSpot). [] = none.
    property var focusKeys: []
    // The bar panel being edited (several bars): the Bar stage picks it
    // with a click, the bars editor edits it.
    property int selectedPanel: 0
    // The wallpaper on screen as a file URL ("" while there is none): the
    // window's ambient background, the stages and the picture tiles.
    readonly property string wallpaper: {
        const m = GlobalStates.wallpaperManager;
        if (!m)
            return "";
        const path = m.effectiveWallpaper ?? m.currentWallpaper ?? "";
        const shown = path && m.getDisplaySource ? m.getDisplaySource(path) : path;
        return shown ? (String(shown).startsWith("/") ? "file://" + shown : String(shown)) : "";
    }
    property var _focusOwner: null

    // A row is pointed at (hovered / focused) or no longer: the last one
    // pointed at owns focusKeys; leaving clears them only if it still does.
    function point(owner, keys) {
        root._focusOwner = owner;
        root.focusKeys = keys || [];
    }
    function unpoint(owner) {
        if (root._focusOwner !== owner)
            return;
        root._focusOwner = null;
        root.focusKeys = [];
    }

    signal navigateRequested(string categoryId, string sectionId, string entryId)
    // A settings control (or reset / undo) changed `key`: lets an editor
    // react to user actions only, never to config changes from elsewhere.
    signal valueSet(string key, var value)

    function navigate(categoryId, sectionId, entryId) {
        navigateRequested(categoryId, sectionId || "", entryId || "");
    }

    readonly property var wallpaperManager: GlobalStates.wallpaperManager

    function get(key) {
        if (!key)
            return undefined;
        const k = SchemaUtil.splitKey(key);
        if (SchemaUtil.storeOf(key) === "wallpaper") {
            const m = root.wallpaperManager;
            if (!m)
                return SettingsDefaults.get(key);
            if (k.prop === "matugenScheme")
                return m.currentMatugenScheme;
            if (k.prop === "activeColorPreset")
                return m.activeColorPreset;
            if (k.prop === "wallPath")
                return m.wallpaperDir;
            return undefined;
        }
        const domain = Config[k.domain];
        if (!domain)
            return undefined;
        return SchemaUtil.getPath(domain, k.path);
    }

    // Context of the reset / count rules (ResetModel.js).
    readonly property var resetContext: ({
            "compositor": YozdService.compositorName,
            "get": root.get
        })

    function defaultValue(key) {
        // The wallpaper folder default is the manager's bundled fallback.
        if (key === "wallpaper.wallPath")
            return root.wallpaperManager ? root.wallpaperManager.fallbackDir : undefined;
        return SettingsDefaults.get(key);
    }

    function isStaged(domain) {
        return themeDomains.indexOf(domain) !== -1 || compositorDomains.indexOf(domain) !== -1 || shellDomains.indexOf(domain) !== -1;
    }

    function _stage(domain) {
        if (themeDomains.indexOf(domain) !== -1)
            GlobalStates.markThemeChanged();
        else if (compositorDomains.indexOf(domain) !== -1)
            GlobalStates.markCompositorChanged();
        else if (shellDomains.indexOf(domain) !== -1)
            GlobalStates.markShellChanged();
    }

    function _setWallpaper(prop, value) {
        const m = root.wallpaperManager;
        if (!m)
            return;
        if (prop === "matugenScheme")
            m.setMatugenScheme(value);
        else if (prop === "activeColorPreset")
            m.setColorPreset(value);
        else if (prop === "wallPath" && m.setWallpaperDir)
            m.setWallpaperDir(value);
    }

    // One value into Config (or the wallpaper manager); `staged`: the
    // wizard's staging. false: unknown key.
    function _write(key, value, staged) {
        const k = SchemaUtil.splitKey(key);
        if (SchemaUtil.storeOf(key) === "wallpaper") {
            root._setWallpaper(k.prop, value);
            return true;
        }
        // Nested JsonObject children (e.g. ai.quickAsk.enabled) are assigned
        // in place; a `property var` object on the way is replaced by an
        // updated copy (e.g. bar.layout.style).
        if (ConfigWrite.assign(Config, key, value, staged ? root._stage : (d => {})) === "") {
            console.warn("SettingsStore: unknown config domain for", key);
            return false;
        }
        if (staged) {
            // A separate wizard process: the main shell previews the staged
            // value (daemon `preview` relay, PreviewSink.qml).
            if (ProcessRole.secondary && isStaged(k.domain))
                BackendService.call("preview.set", {
                    "owner": ProcessRole.role,
                    "key": key,
                    "value": SchemaUtil.plain(value)
                });
            return true;
        }
        // Live: the domain's auto-save persists it. Only while the wizard
        // holds this domain's auto-save for its staged choices (or a service
        // holds every domain) is the write explicit, so a live change is
        // never held back.
        const paused = typeof Config.autoSavePausedFor === "function" ? Config.autoSavePausedFor(k.domain) : Config.pauseAutoSave;
        if (paused)
            root._save(k.domain);
        return true;
    }

    // Writes one domain's file now (Config.saveDomain: every domain has one,
    // tests/settings-save-path.test.cjs). false: no way to write it.
    function _save(domain) {
        if (typeof Config.saveDomain === "function")
            return Config.saveDomain(domain);
        const saver = Config["save" + domain.charAt(0).toUpperCase() + domain.slice(1)];
        if (typeof saver !== "function") {
            console.warn("SettingsStore: no save path for", domain);
            return false;
        }
        saver();
        return true;
    }

    // ---- live changes + undo ------------------------------------------
    function set(key, value) {
        if (!key)
            return;
        const before = SchemaUtil.plain(get(key));
        if (SchemaUtil.equal(before, value))
            return;
        if (!root._write(key, value, false))
            return;
        // What the config holds now (a typed property may have converted
        // it): the value an undo expects to find. The wallpaper manager
        // answers later (a separate window relays it), so its keys keep the
        // value asked for.
        const after = root._async(key) ? SchemaUtil.plain(value) : root._current(key);
        if (!SchemaUtil.equal(before, after))
            root._record(key, before, after);
        root.valueSet(key, value);
    }

    // The setup wizard: staged until apply() / discard() (never on the undo
    // history).
    function stageSet(key, value) {
        if (!key || SchemaUtil.equal(get(key), value))
            return;
        if (root._write(key, value, true))
            root.valueSet(key, value);
    }

    // Window history: [{id, label, changes: [{key, before, after}], time}].
    // It lives while the window is open: closing the window clears it, in
    // process as in a separate window process (which quits), because what
    // changes while it is closed (dashboard, CLI, presets) is not recorded
    // and would make old steps write stale values. A preset command clears
    // it too (PresetStudio), and so does a reload of a domain that changed
    // a value the history expects (another process, `config set`, a preset
    // applied elsewhere: _domainReloaded). An undo or redo whose keys no
    // longer hold the values it expects is dropped, never written.
    property var undoStack: []
    property var redoStack: []
    readonly property bool canUndo: undoStack.length > 0
    readonly property bool canRedo: redoStack.length > 0
    // The last step recorded, undone or redone, for the undo pill:
    // {id (the step's), label, kind: "changed" | "undone" | "redone",
    // serial}; null: nothing to offer (the pill hides).
    property var lastStep: null
    property int _serial: 0
    property int _ids: 0
    // key -> label of the entry that edits it.
    readonly property var labelIndex: UndoModel.labelIndex(Categories.categories)
    // An open transaction: changes made inside it are one step.
    property var _txn: null
    property int _txnDepth: 0
    property bool _replaying: false

    function _record(key, before, after) {
        // Only what the open window changes is its history (the dashboard,
        // the AI service and the wizard write through here too).
        if (root._replaying || !GlobalStates.settingsWindowVisible)
            return;
        if (root._txn) {
            root._txn.changes = UndoModel.addChange(root._txn.changes, key, before, after);
            return;
        }
        root._push({
            "label": UndoModel.labelFor(root.labelIndex, key),
            "changes": UndoModel.addChange([], key, before, after)
        });
    }

    function _push(step) {
        step.id = root._ids + 1;
        const r = UndoModel.pushResult(root.undoStack, step, Date.now(), SchemaUtil.equal);
        if (r.outcome === "none")
            return;
        if (r.outcome === "added")
            root._ids = step.id;
        root.undoStack = r.stack;
        root.redoStack = [];
        // A change taken back within the coalescing window (a switch
        // flipped twice): its step is gone, nothing is announced and the
        // pill that named it hides.
        root._announce(r.outcome === "cancelled" ? null : r.step, "changed");
    }

    function _announce(step, kind) {
        root._serial++;
        root.lastStep = step ? {
            "id": step.id,
            "label": step.label || "",
            "kind": kind,
            "serial": root._serial
        } : null;
    }

    // Keys whose value is not known synchronously (the wallpaper manager):
    // the undo checks trust them.
    function _async(key) {
        return SchemaUtil.storeOf(key) === "wallpaper";
    }
    function _current(key) {
        return SchemaUtil.plain(root.get(key));
    }

    function clearHistory() {
        root.undoStack = [];
        root.redoStack = [];
        root._announce(null, "");
    }

    // A domain was reloaded from disk: when that changed a value the
    // history expects, its steps no longer describe the config and all of
    // them go (a later undo would bring back a stale value). Our own write
    // coming back, or a change to keys the history never touched, keeps it.
    function _domainReloaded(name) {
        if (root.undoStack.length === 0 && root.redoStack.length === 0)
            return;
        const only = k => SchemaUtil.splitKey(k).domain === name;
        if (!UndoModel.consistent(root.undoStack, root.redoStack, root._current, SchemaUtil.equal, only))
            root.clearHistory();
    }

    Connections {
        target: Config
        ignoreUnknownSignals: true
        function onDomainReloaded(name) {
            root._domainReloaded(name);
        }
    }
    Connections {
        target: GlobalStates
        function onSettingsWindowVisibleChanged() {
            if (!GlobalStates.settingsWindowVisible)
                root.clearHistory();
        }
    }

    // Changes made by `fn` are one undo step labelled `label` (an i18n key):
    // a reset, a macro slider, an editor that writes several keys.
    function transaction(label, fn) {
        if (root._txnDepth === 0)
            root._txn = {
                "label": label,
                "changes": []
            };
        root._txnDepth++;
        try {
            fn();
        } finally {
            root._txnDepth--;
            if (root._txnDepth === 0) {
                const t = root._txn;
                root._txn = null;
                if (t.changes.length > 0)
                    root._push(t);
            }
        }
    }

    function _replay(writes) {
        root._replaying = true;
        try {
            writes.forEach(w => {
                if (root._write(w.key, w.value, false))
                    root.valueSet(w.key, w.value);
            });
        } finally {
            root._replaying = false;
        }
    }

    // Undoes the newest step. A step whose keys no longer hold what it set
    // (changed elsewhere since) is dropped without writing. true: undone.
    function undo() {
        if (!root.canUndo)
            return false;
        const stack = root.undoStack.slice();
        const step = stack.pop();
        root.undoStack = stack;
        if (!UndoModel.holds(step, "after", root._current, SchemaUtil.equal, root._async)) {
            root._announce(null, "");
            return false;
        }
        root._replay(UndoModel.reverted(step));
        root.redoStack = root.redoStack.concat([step]);
        root._announce(step, "undone");
        return true;
    }

    function redo() {
        if (!root.canRedo)
            return false;
        const stack = root.redoStack.slice();
        const step = stack.pop();
        root.redoStack = stack;
        if (!UndoModel.holds(step, "before", root._current, SchemaUtil.equal, root._async)) {
            root._announce(null, "");
            return false;
        }
        root._replay(UndoModel.replayed(step));
        step.time = 0;
        root.undoStack = root.undoStack.concat([step]);
        root._announce(step, "redone");
        return true;
    }

    // The undo pill acts on the step it names and never on another one:
    // only while that step is still the newest (else the pill just hides).
    function undoStep(id) {
        const top = root.undoStack[root.undoStack.length - 1];
        if (!top || top.id !== id) {
            root._announce(null, "");
            return false;
        }
        return root.undo();
    }
    function redoStep(id) {
        const top = root.redoStack[root.redoStack.length - 1];
        if (!top || top.id !== id) {
            root._announce(null, "");
            return false;
        }
        return root.redo();
    }

    // ---- modified / reset ---------------------------------------------
    function isModified(entry) {
        if (!entry || !SchemaUtil.isResettable(entry))
            return false;
        const keys = SchemaUtil.entryKeys(entry);
        for (let i = 0; i < keys.length; i++) {
            const def = defaultValue(keys[i]);
            if (def !== undefined && !SchemaUtil.equal(get(keys[i]), def))
                return true;
        }
        return false;
    }

    function _resetKeys(entry) {
        const keys = SchemaUtil.entryKeys(entry);
        for (let i = 0; i < keys.length; i++) {
            const def = defaultValue(keys[i]);
            if (def !== undefined)
                set(keys[i], def);
        }
    }

    function reset(entry) {
        if (!SchemaUtil.isResettable(entry))
            return;
        root.transaction(entry.label || "", () => root._resetKeys(entry));
    }

    // Entries of a page a reset / the modified count may touch: the window's
    // own rows that are visible on the running compositor (ResetModel.js).
    function activeItems(category) {
        return ResetModel.activeItems(category, root.resetContext);
    }

    function modifiedCount(category) {
        let n = 0;
        const all = activeItems(category);
        for (let i = 0; i < all.length; i++) {
            if (isModified(all[i].entry))
                n++;
        }
        return n;
    }

    // "Reset page": one undo step.
    function resetCategory(category) {
        const all = activeItems(category);
        root.transaction("prefs.undo.reset_page", () => {
            for (let i = 0; i < all.length; i++) {
                if (SchemaUtil.isResettable(all[i].entry))
                    root._resetKeys(all[i].entry);
            }
        });
    }

    // ---- what the window shows ----------------------------------------
    // Shown in the window at all (not an out-of-window `advanced` entry).
    function inWindow(entry, section) {
        return SchemaUtil.inWindow(entry, section);
    }

    function visible(entry) {
        // entries tied to one compositor (exclusive mode: Hyprland)
        if (!CompositorGate.allows(entry.compositor, YozdService.compositorName))
            return false;
        return SchemaUtil.evalCondition(entry.visibleWhen, root.get);
    }

    // A section has at least one row to show right now.
    function sectionShown(section) {
        if (!section || !CompositorGate.allows(section.compositor, YozdService.compositorName))
            return false;
        return (section.entries || []).some(e => SchemaUtil.inWindow(e, section) && root.visible(e));
    }

    function enabled(entry) {
        return SchemaUtil.evalCondition(entry.enabledWhen, root.get);
    }

    // key -> the schema entry that edits it (DisabledReason names it).
    readonly property var entryByKey: DisabledReason.entryIndex(Categories.categories)

    // {text, fix: {key, value, on} | null} for an unusable entry, else null.
    function disabledNote(entry) {
        return DisabledReason.explain(entry, root.get, k => root.entryByKey[k] || null, k => I18n.t(k));
    }

    // ---- the wizard's staging -----------------------------------------
    function apply() {
        // A separate wizard process: the main shell writes the files (its
        // Config holds the staged values), the window follows them.
        if (ProcessRole.secondary) {
            PreviewSink.applyOwn();
            return;
        }
        GlobalStates.applyThemeChanges();
        GlobalStates.applyShellChanges();
        GlobalStates.applyCompositorChanges();
    }

    function discard() {
        if (ProcessRole.secondary) {
            PreviewSink.discardOwn();
            return;
        }
        GlobalStates.discardThemeChanges();
        GlobalStates.discardShellChanges();
        GlobalStates.discardCompositorChanges();
    }

    // Writes every coalesced auto-save still waiting (before a preset
    // command reads the files). The wizard's staging is applied first.
    function flush() {
        if (root.hasChanges)
            root.apply();
        if (typeof Config.flushWrites === "function")
            Config.flushWrites();
    }
}
