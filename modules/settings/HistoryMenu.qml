import QtQuick
import qs.modules.services
import qs.modules.settings.store

// The History of the settings window (the destination header's clock
// button and home's History button): the session's changes, newest first
// (a redo on top when there is one); a click on a change undoes it and
// every newer one (an item is named by its step's id, `undo:<id>`:
// SettingsStore.undoTo, never an older step than the one shown). "All
// changes" at the foot opens the Changes tab (what differs from the
// defaults or the preset, with a way back for each).
// A PageMenu: under the button it belongs to (its parent).
PageMenu {
    id: history

    objectName: "historyMenu"
    items: {
        const say = (s, kind) => {
            const what = s && s.label ? I18n.t(s.label) : I18n.t("prefs.undo.something");
            return kind === "changed" && String(s.label).startsWith("prefs.undo.") ? what : I18n.t("prefs.undo." + kind).arg(what);
        };
        const out = [];
        const redo = SettingsStore.redoStack;
        if (redo.length > 0)
            out.push({
                "name": "redo",
                "text": say(redo[redo.length - 1], "undone"),
                "subtitle": I18n.t("prefs.undo.redo")
            });
        const undo = SettingsStore.undoStack;
        for (let k = 0; k < Math.min(8, undo.length); k++)
            out.push({
                "name": "undo:" + undo[undo.length - 1 - k].id,
                "text": say(undo[undo.length - 1 - k], "changed"),
                "subtitle": k === 0 ? I18n.t("prefs.undo.undo") : I18n.t("prefs.history.undo_back")
            });
        if (out.length === 0)
            out.push({
                "name": "none",
                "text": I18n.t("prefs.history.empty"),
                "enabled": false
            });
        out.push({
            "name": "changes",
            "text": I18n.t("prefs.page.all_changes")
        });
        return out;
    }
    onTriggered: name => {
        if (name === "changes") {
            SettingsStore.navigate("changes");
            return;
        }
        if (name === "redo") {
            SettingsStore.redo();
            return;
        }
        // a change below the newest undoes it and every newer one, by the
        // step's id (never an older step than the one named)
        SettingsStore.undoTo(Number(name.split(":")[1]) || 0);
    }
}
