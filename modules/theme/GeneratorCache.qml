import QtQuick
import Quickshell.Io
import qs.modules.globals
import "GenCache.js" as GenCache

// The app theme generator record (GenCache.js) in the shell cache dir:
// take() returns the generators that must run for the current inputs and
// records them as run. A missing or unreadable record runs everything.
QtObject {
    id: root

    property string path: Brand.cacheDir + "/theme-generators.json"
    property var stored: null

    // Generators to run (in order) for `inputs`; `force` runs them all.
    function take(names, inputs, force) {
        if (root.stored === null)
            root.stored = GenCache.parse(file.text());
        const fp = GenCache.fingerprint(inputs);
        const now = Date.now();
        const p = GenCache.plan(root.stored, names, fp, force, now);
        if (p.run.length > 0) {
            root.stored = GenCache.record(root.stored, p.run, fp, now);
            file.setText(GenCache.serialize(root.stored));
        }
        if (p.skip.length > 0)
            console.log("GeneratorCache: unchanged, skipped " + p.skip.join(", "));
        return p.run;
    }

    property FileView file: FileView {
        id: file
        path: root.path
        blockLoading: true
        printErrors: false
    }
}
