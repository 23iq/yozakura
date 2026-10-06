import QtQuick
import Quickshell.Io
import "ConfigValidator.js" as ConfigValidator

// One config domain persisted as <configDir>/<name>.json, bound two-way to its
// generated adapter (config/adapters/<Name>Adapter.qml). On the first load the
// file is validated against the defaults (or created from the preset /
// defaults when missing); later reloads only fill in missing top-level keys.
// Adapter edits are written back unless the store pauses auto-save.
FileView {
    id: file

    // The Config singleton: configDir, presetDir and the shared pauseAutoSave.
    required property var store
    required property string name
    required property var defaults
    property bool ready: false
    // The file on disk is not valid JSON: adapter edits are not written
    // back (they would silently replace the user's file) until it is fixed.
    property bool broken: false
    // Copies a malformed file to <file>.bad-<timestamp> before anything
    // replaces it; then calls store.configMalformed(name, backup, replaced).
    property Process quarantine: Process {
        id: proc

        property bool replace: false
        property var onDone: null
        onExited: code => {
            const backup = proc.command[3];
            const saved = code === 0;
            if (saved && proc.replace) {
                file.broken = false;
                file.setText(JSON.stringify(file.defaults, null, 2));
            }
            if (typeof file.store.configMalformed === "function")
                file.store.configMalformed(file.name, saved ? backup : "", saved && proc.replace);
            const done = proc.onDone;
            proc.onDone = null;
            if (done)
                done();
        }
    }

    // Emitted at the start of every load, before validation (legacy fixes).
    signal beforeValidate

    path: store.configDir + "/" + name + ".json"
    atomicWrites: true
    watchChanges: true
    onLoaded: {
        file.beforeValidate();
        if (!file.ready) {
            // Files touched by a key alias validate together (AliasGate).
            if (file.store.aliasGate && file.store.aliasGate.hold(file))
                return;
            file.validate(() => {
                file.ready = true;
            });
        } else {
            file.fillMissingKeys();
        }
    }
    onLoadFailed: error => {
        // Quickshell passes the FileViewError value (a number), not its name.
        if ((error === FileViewError.FileNotFound || String(error).includes("FileNotFound")) && !file.ready) {
            if (file.store.aliasGate)
                file.store.aliasGate.skip(file.name);
            file.handleMissing(() => {
                file.ready = true;
            });
        }
    }
    onFileChanged: {
        file.store.pauseAutoSave = true;
        reload();
        file.store.pauseAutoSave = false;
    }
    onPathChanged: reload()
    onAdapterUpdated: {
        if (file.ready && !file.broken && !file.store.pauseAutoSave) {
            file.writeAdapter();
        }
    }

    // `migrated`: the parsed file after the key-alias migration (AliasGate).
    function validate(onComplete, migrated) {
        var raw = file.text();
        if (!raw || raw.trim().length === 0) {
            // File is missing or empty — create with defaults
            console.log(name + ".json missing or empty, creating default...");
            file.setText(JSON.stringify(defaults, null, 2));
            onComplete();
            return;
        }

        try {
            var current = JSON.parse(raw);
            var validated = ConfigValidator.validate(migrated !== undefined ? migrated : current, defaults);

            if (JSON.stringify(current) !== JSON.stringify(validated)) {
                console.log("Merging and updating " + name + ".json...");
                file.setText(JSON.stringify(validated, null, 2));
            }
            onComplete();
        } catch (e) {
            console.warn(name + ".json is not valid JSON (" + e + "); backing it up before using the defaults");
            file.backUpMalformed(true, onComplete);
        }
    }

    // Never silently drop a malformed file: copy it to <file>.bad-<time>
    // first. replace: write the defaults once the copy exists (first load);
    // otherwise the file stays for the user to fix. A failed copy keeps it.
    function backUpMalformed(replace, onComplete) {
        file.broken = true;
        if (quarantine.running) {
            if (onComplete)
                onComplete();
            return;
        }
        const stamp = new Date().toISOString().replace(/[:.]/g, "-");
        quarantine.replace = replace;
        quarantine.onDone = onComplete || null;
        quarantine.command = ["cp", "--", file.path, file.path + ".bad-" + stamp];
        quarantine.running = true;
    }

    // JsonAdapter keeps the previous value of keys absent from a reloaded
    // file (e.g. a preset saved before a key existed). Add the defaults for
    // missing top-level keys so such presets fall back instead of inheriting.
    function fillMissingKeys() {
        try {
            var current = JSON.parse(file.text());
            file.broken = false;
            var added = [];
            for (var key in defaults) {
                if (current[key] === undefined) {
                    current[key] = JSON.parse(JSON.stringify(defaults[key]));
                    added.push(key);
                }
            }
            if (added.length > 0) {
                console.log("Filling missing " + name + ".json keys: " + added.join(", "));
                file.setText(JSON.stringify(current, null, 2));
            }
        } catch (e) {
            console.warn(name + ".json is not valid JSON (" + e + "); backing it up, edits paused until it is fixed");
            if (!file.broken)
                file.backUpMalformed(false, null);
        }
    }

    // Missing file: copy it from the default preset or create it with defaults.
    function handleMissing(onComplete) {
        var presetPath = store.presetDir + "/" + name + ".json";
        var targetPath = store.configDir + "/" + name + ".json";
        console.log(name + ".json not found, checking preset: " + presetPath);
        var copy = copyProcess.createObject(file, {
            command: ["cp", "-n", "--", presetPath, targetPath],
            whenDone: exitCode => {
                // Copied: the reload validates it. Otherwise use the defaults.
                if (exitCode === 0) {
                    file.reload();
                } else {
                    console.log("Using defaults for " + name + ".json");
                    file.setText(JSON.stringify(defaults, null, 2));
                    onComplete();
                }
            }
        });
        copy.running = true;
    }

    property Component copyProcess: Component {
        Process {
            id: copyProc

            property var whenDone: null

            onExited: (exitCode, exitStatus) => {
                if (copyProc.whenDone)
                    copyProc.whenDone(exitCode);
                copyProc.destroy();
            }
        }
    }
}
