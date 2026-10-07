pragma Singleton

import QtQuick
import Quickshell
import qs.modules.settings.store
import "../GalleryTabs.js" as GalleryTabs

// The layouts, styles and palettes of the unified preset gallery
// (`preset parts --json`: {layouts, styles, palettes, current}) and the set
// actions of the gallery (apply a card, save the current look as a set,
// rename, delete). Refreshed with the preset list (PresetStudio.presets
// changes after every apply / save / rename / delete), so both stay in step.
Singleton {
    id: root

    property var parts: ({
            "layouts": [],
            "styles": [],
            "palettes": [],
            "current": {}
        })
    property bool loaded: false
    property string error: ""
    property string pending: "" // set name an action runs for
    // (args, cb(ok, out, err)) running `<app> preset <args>`. Tests replace it.
    property var run: PresetStudio.run

    function refresh() {
        root.run(["parts", "--json"], (ok, out, err) => {
            if (!ok) {
                root.error = PresetStudio.cleanError(err);
                return;
            }
            try {
                root.parts = JSON.parse(out) || root.parts;
                root.loaded = true;
                root.error = "";
            } catch (e) {
                root.error = String(e);
            }
        });
    }

    // Runs `args`, then reloads the sets (and so the parts); cb(ok).
    function act(name, args, cb) {
        root.pending = name;
        root.run(args, (ok, out, err) => {
            root.pending = "";
            root.error = ok ? "" : PresetStudio.cleanError(err);
            PresetStudio.refresh();
            if (cb)
                cb(ok);
        });
    }

    // A card's apply (a set, or one part merged into the live config),
    // after staged settings edits are written.
    function apply(card, cb) {
        if (!card)
            return;
        PresetStudio.afterFlush(() => root.act(card.name, card.apply, cb));
    }

    function save(name, cb) {
        PresetStudio.afterFlush(() => root.act(name, GalleryTabs.saveArgs(name), cb));
    }

    function rename(name, newName, cb) {
        if (!newName || newName === name)
            return;
        root.act(name, GalleryTabs.renameArgs(name, newName), cb);
    }

    function remove(name, cb) {
        root.act(name, GalleryTabs.deleteArgs(name), cb);
    }

    Connections {
        target: PresetStudio
        function onPresetsChanged() {
            debounce.restart();
        }
    }

    Timer {
        id: debounce
        interval: 50
        onTriggered: root.refresh()
    }
}
