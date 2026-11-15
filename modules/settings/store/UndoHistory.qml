import QtQuick
import "../SchemaUtil.js" as SchemaUtil
import "../UndoModel.js" as UndoModel

// The settings window's session history (SettingsStore keeps one; its API
// forwards here): [{id, label, changes: [{key, before, after}], time}].
// Coalescing, labels and checks are UndoModel.js (pure, node-tested).
//
// It lives while the window is open: closing the window clears it, in
// process as in a separate window process (which quits), because what
// changes while it is closed (dashboard, CLI, presets) is not recorded and
// would make old steps write stale values. A preset command clears it too
// (PresetStudio), and so does a reload of a domain that changed a value the
// history expects (another process, `config set`, a preset applied
// elsewhere: domainReloaded). A step whose keys no longer hold the values
// it expects (changed elsewhere since) is dropped, never written: undo()
// then goes on to the step under it, so Ctrl+Z always undoes something.
QtObject {
    id: history

    // (key, value): writes one value (a replay: never recorded)
    required property var write
    // key -> its plain current value
    required property var current
    // key -> true when its value is not known synchronously (the wallpaper
    // manager answers later): the checks trust it
    required property var trusted
    // key -> i18n label of the entry that edits it (UndoModel.labelIndex)
    required property var labels

    property var undoStack: []
    property var redoStack: []
    readonly property bool canUndo: history.undoStack.length > 0
    readonly property bool canRedo: history.redoStack.length > 0
    // The last step recorded, undone or redone, for the undo pill:
    // {id (the step's), label, kind: "changed" | "undone" | "redone",
    // serial}; null: nothing to offer (the pill hides).
    property var lastStep: null
    property int _serial: 0
    property int _ids: 0
    // An open transaction: changes made inside it are one step.
    property var _txn: null
    property int _txnDepth: 0
    property bool replaying: false

    // A change made in the window: one step (or merged into the newest).
    function record(key, before, after) {
        if (history.replaying)
            return;
        if (history._txn) {
            history._txn.changes = UndoModel.addChange(history._txn.changes, key, before, after);
            return;
        }
        history._push({
            "label": UndoModel.labelFor(history.labels, key),
            "changes": UndoModel.addChange([], key, before, after)
        });
    }

    function _push(step) {
        step.id = history._ids + 1;
        const r = UndoModel.pushResult(history.undoStack, step, Date.now(), SchemaUtil.equal);
        if (r.outcome === "none")
            return;
        if (r.outcome === "added")
            history._ids = step.id;
        history.undoStack = r.stack;
        history.redoStack = [];
        // A change taken back within the coalescing window (a switch
        // flipped twice): its step is gone, nothing is announced and the
        // pill that named it hides.
        history.announce(r.outcome === "cancelled" ? null : r.step, "changed");
    }

    function announce(step, kind) {
        history._serial++;
        history.lastStep = step ? {
            "id": step.id,
            "label": step.label || "",
            "kind": kind,
            "serial": history._serial
        } : null;
    }

    function clear() {
        history.undoStack = [];
        history.redoStack = [];
        history.announce(null, "");
    }

    // A domain was reloaded from disk: when that changed a value the
    // history expects, its steps no longer describe the config and all of
    // them go (a later undo would bring back a stale value). Our own write
    // coming back, or a change to keys the history never touched, keeps it.
    function domainReloaded(name) {
        if (history.undoStack.length === 0 && history.redoStack.length === 0)
            return;
        const only = k => SchemaUtil.splitKey(k).domain === name;
        if (!UndoModel.consistent(history.undoStack, history.redoStack, history.current, SchemaUtil.equal, only))
            history.clear();
    }

    // The next change starts a new step, even within the merge window
    // (UndoModel.COALESCE_MS): the steps are aged to time 0, as a redone one.
    function seal() {
        history.undoStack = history.undoStack.map(s => Object.assign({}, s, {
                "time": 0
            }));
    }

    // Changes made by `fn` are one step labelled `label` (an i18n key).
    function transaction(label, fn) {
        if (history._txnDepth === 0)
            history._txn = {
                "label": label,
                "changes": []
            };
        history._txnDepth++;
        try {
            fn();
        } finally {
            history._txnDepth--;
            if (history._txnDepth === 0) {
                const t = history._txn;
                history._txn = null;
                if (t.changes.length > 0)
                    history._push(t);
            }
        }
    }

    function _replay(writes) {
        history.replaying = true;
        try {
            writes.forEach(w => history.write(w.key, w.value));
        } finally {
            history.replaying = false;
        }
    }

    // The newest step, undone; a stale one is dropped instead. Returns
    // "undone", "stale" or "" (nothing to undo).
    function _undoOne() {
        if (!history.canUndo)
            return "";
        const stack = history.undoStack.slice();
        const step = stack.pop();
        history.undoStack = stack;
        if (!UndoModel.holds(step, "after", history.current, SchemaUtil.equal, history.trusted))
            return "stale";
        history._replay(UndoModel.reverted(step));
        history.redoStack = history.redoStack.concat([step]);
        history.announce(step, "undone");
        return "undone";
    }

    function _redoOne() {
        if (!history.canRedo)
            return "";
        const stack = history.redoStack.slice();
        const step = stack.pop();
        history.redoStack = stack;
        if (!UndoModel.holds(step, "before", history.current, SchemaUtil.equal, history.trusted))
            return "stale";
        history._replay(UndoModel.replayed(step));
        step.time = 0;
        history.undoStack = history.undoStack.concat([step]);
        history.announce(step, "redone");
        return "redone";
    }

    // Undoes the newest step that still holds (stale ones on the way are
    // dropped). true: something was undone.
    function undo() {
        for (; ; ) {
            const r = history._undoOne();
            if (r === "undone")
                return true;
            if (r === "") {
                history.announce(null, "");
                return false;
            }
        }
    }

    function redo() {
        for (; ; ) {
            const r = history._redoOne();
            if (r === "redone")
                return true;
            if (r === "") {
                history.announce(null, "");
                return false;
            }
        }
    }

    // The undo pill acts on the step it names and never on another one:
    // only while that step is still the newest (else, or when it no longer
    // holds, the pill just hides).
    function undoStep(id) {
        const top = history.undoStack[history.undoStack.length - 1];
        if (top && top.id === id && history._undoOne() === "undone")
            return true;
        history.announce(null, "");
        return false;
    }
    function redoStep(id) {
        const top = history.redoStack[history.redoStack.length - 1];
        if (top && top.id === id && history._redoOne() === "redone")
            return true;
        history.announce(null, "");
        return false;
    }

    // The History menu: undoes the step `id` and every newer one, by id
    // (a step pushed while the menu was open is undone too, never an older
    // one the menu did not name). false: that step is gone.
    function undoTo(id) {
        if (UndoModel.depthOf(history.undoStack, id) < 0) {
            history.announce(null, "");
            return false;
        }
        while (history.canUndo && history.undoStack[history.undoStack.length - 1].id >= id)
            history._undoOne();
        return true;
    }
}
