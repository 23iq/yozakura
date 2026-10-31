pragma Singleton

import QtQuick
import Quickshell
import qs.modules.globals

// The active preset against the live config (backend `preset.status`,
// pushed on every config or preset change): its name, whether it is the
// user's own (Save updates it) or built in (Save as new), and the settings
// changed since it was applied. Actions run `<app> preset ...` through
// PresetsService.run (dry-run aware). Like PresetCommandService, sibling
// singletons are referenced unqualified (no self-import of the namespace).
Singleton {
    id: root

    property var status: ({
            "active": "",
            "official": false,
            "owned": false,
            "changed": 0,
            "changes": []
        })
    readonly property string active: (status && status.active) || ""
    readonly property bool official: !!(status && status.official)
    readonly property bool owned: !!(status && status.owned)
    readonly property int changed: (status && status.changed) || 0
    readonly property var changes: (status && status.changes) || []
    readonly property bool inSession: !!(status && status.session)
    // There is something to save (and nothing else owns the live config).
    readonly property bool dirty: active !== "" && changed > 0 && !inSession
    property bool busy: false

    function refresh() {
        BackendService.call("preset.status", {}, (res, err) => {
            if (res && !err)
                root.status = res;
        });
    }

    function parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            return null;
        }
    }

    function errorText(err) {
        return (err || "").trim().replace(/^Error: /, "").split("\n")[0];
    }

    // The default name of a built-in's copy: "<Name> (my)".
    function suggestedName() {
        return I18n.t("presets.status.my_name", root.active);
    }

    // Every action ends with done(ok, message, undoId) for the caller's toast.
    function finish(done, ok, message, undo) {
        root.busy = false;
        if (done)
            done(ok, message, undo || "");
        root.refresh();
    }

    // Save into the active user preset (an undo id comes back).
    function save(done) {
        if (root.busy || !root.owned)
            return;
        root.busy = true;
        PresetsService.run(["save", "--current", "--json"], (ok, out, err) => {
            const r = ok ? root.parse(out) : null;
            root.finish(done, ok, ok ? I18n.t("presets.status.saved", r ? r.preset : root.active) : root.errorText(err), r ? r.undo : "");
        });
    }

    // Save the live config as a new user preset that becomes the active one.
    function saveAs(name, done) {
        if (root.busy || !name)
            return;
        root.busy = true;
        PresetsService.run(["save", "--current", "--as", name, "--json"], (ok, out, err) => {
            PresetsService.scanPresets();
            root.finish(done, ok, ok ? I18n.t("presets.status.saved_as", name) : root.errorText(err), "");
        });
    }

    function undoSave(id, done) {
        if (!id)
            return;
        PresetsService.run(["save", "--undo", id], (ok, out, err) => {
            root.finish(done, ok, ok ? I18n.t("presets.status.undone") : root.errorText(err), "");
        });
    }

    // Apply the active preset exactly: the changed settings go back to it.
    function revert(done) {
        if (root.busy || root.active === "")
            return;
        root.busy = true;
        const name = root.active;
        PresetsService.run(["apply", "--exact", name], (ok, out, err) => {
            root.finish(done, ok, ok ? I18n.t("presets.status.reverted", name) : root.errorText(err), "");
        });
    }

    Component.onCompleted: {
        BackendService.addSubscription(["preset"], (service, data) => {
            if (service === "preset.status" && data)
                root.status = data;
        });
        refresh();
    }
}
