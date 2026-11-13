import QtQuick
import Quickshell.Io
import "ConfigValidator.js" as ConfigValidator
import "JsonUtil.js" as JsonUtil
import "ConfigMerge.js" as ConfigMerge
import "WriteThrottle.js" as WriteThrottle

// One config domain persisted as <configDir>/<name>.json, bound two-way to its
// generated adapter (config/adapters/<Name>Adapter.qml). On the first load the
// file is validated against the defaults (or created from the preset /
// defaults when missing); later reloads only fill in missing top-level keys.
// Adapter edits are written back (coalesced by store.autoSaveDelay, and at
// least every store.autoSaveMaxWait ms during a long burst such as a slider
// drag, WriteThrottle.js) unless the store pauses auto-save; a reload this
// file triggers never writes back.
// Another process may write the same file (the main shell and a separate
// Settings window, the `config set` CLI): an edit still waiting to be
// written when the file changes is merged into the new contents (what this
// process changed since it last read or wrote the file, ConfigMerge.js),
// never written over them.
FileView {
    id: file

    // The Config singleton: configDir, presetDir, autoSavePausedFor(name)
    // (or the derived pauseAutoSave for every domain), autoSaveDelay (ms,
    // optional) and configReloaded(name) (optional).
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

    // An external change is being reloaded: adapter updates it causes are
    // not edits and are not written back.
    property bool reloading: false
    // Coalesces bursts of edits (slider ticks) into one write.
    property Timer saveTimer: Timer {
        interval: Math.max(1, file.autoSaveDelay())
        onTriggered: file.autoSave()
    }
    // When the oldest edit the timer holds was made (ms, -1: none).
    property real pendingSince: -1

    // Values the key aliases moved into this still missing file; laid over the
    // preset copy by the validation that follows it (see handleMissing).
    property var pendingOverlay: undefined

    // The file as this process last loaded or wrote it (plain JSON): the
    // base a merge compares the adapter with. null: not known yet.
    property var synced: null
    // A merge waiting for the reload: {base, local, force}.
    property var pendingMerge: null
    // Every first-load path (validate, handleMissing, AliasGate) ends here.
    onReadyChanged: {
        if (file.ready && file.synced === null)
            file.synced = file.parsed();
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
            file.finishMerge();
            // Lets the settings snapshots follow an external reload.
            if (typeof file.store.configReloaded === "function")
                file.store.configReloaded(file.name);
        }
    }
    onLoadFailed: error => {
        // Quickshell passes the FileViewError value (a number), not its name.
        if ((error === FileViewError.FileNotFound || String(error).includes("FileNotFound")) && !file.ready) {
            if (file.store.aliasGate && file.store.aliasGate.skip(file))
                return;
            file.handleMissing(() => {
                file.ready = true;
            });
        }
    }
    onFileChanged: {
        // Our own edit waits to be written: merge it into what is on disk
        // now instead of writing the whole adapter over it.
        if (saveTimer.running) {
            saveTimer.stop();
            file.startMerge(false);
            return;
        }
        file.reloading = true;
        reload();
        file.reloading = false;
    }
    onPathChanged: reload()
    // Config.configFile(name) finds it (a merged write of one domain).
    Component.onCompleted: {
        if (typeof file.store.registerFile === "function")
            file.store.registerFile(file.name, file);
    }
    // A pending coalesced write must not be lost when the shell quits.
    Component.onDestruction: file.flushPending()

    // Writes the coalesced edit still waiting for its timer now (a preset
    // command is about to read the file, or to replace it: a cancelled
    // preset edit, a reverted trial). Written before the replacement lands,
    // the edit is simply replaced; left waiting, it would be merged into
    // the new contents (onFileChanged) and outlive the cancel.
    function flushPending() {
        if (saveTimer.running) {
            saveTimer.stop();
            file.autoSave();
        }
    }
    onAdapterUpdated: {
        if (file.ready && !file.broken && !file.reloading && !file.paused())
            file.scheduleWrite();
    }

    // The store pauses per domain when it can (Config.autoSavePausedFor:
    // only staged domains wait for Apply), else all of them at once.
    function paused() {
        const s = file.store;
        if (typeof s.autoSavePausedFor === "function")
            return !!s.autoSavePausedFor(file.name);
        return !!s.pauseAutoSave;
    }

    function autoSaveDelay() {
        const d = Number(file.store.autoSaveDelay);
        return isFinite(d) && d > 0 ? d : 0;
    }

    function autoSaveMaxWait() {
        const d = Number(file.store.autoSaveMaxWait);
        return isFinite(d) && d > 0 ? d : 0;
    }

    function scheduleWrite() {
        const now = Date.now();
        if (!saveTimer.running)
            file.pendingSince = now;
        if (WriteThrottle.decide(now, file.pendingSince, file.autoSaveDelay(), file.autoSaveMaxWait()) === "now") {
            saveTimer.stop();
            file.autoSave();
        } else {
            saveTimer.restart();
        }
    }

    function autoSave() {
        if (file.ready && !file.broken && !file.paused())
            file.writeSynced();
    }

    function writeSynced() {
        file.pendingSince = -1;
        file.writeAdapter();
        file.synced = ConfigMerge.serialize(file.adapter, file.defaults);
    }

    function parsed() {
        try {
            return JSON.parse(file.text());
        } catch (e) {
            return null;
        }
    }

    // Writes only what this process changed since it last read or wrote
    // the file, laid over the file as it is now (re-read first). Used where
    // a whole-domain write could drop another process's edits (a separate
    // window's Apply with no main shell, StagedDomains.js). false: not
    // loaded or the file is broken, nothing written.
    function writeMerged() {
        if (!file.ready || file.broken)
            return false;
        saveTimer.stop();
        file.startMerge(true);
        return true;
    }

    // Remembers this process's changes, then reloads; finishMerge (on the
    // load) lays them over the new contents. force: written at once, even
    // while auto-save is paused; else by the next auto-save.
    function startMerge(force) {
        const prev = file.pendingMerge;
        file.pendingMerge = {
            "base": prev ? prev.base : file.synced,
            "local": ConfigMerge.serialize(file.adapter, file.defaults),
            "force": force || (prev ? prev.force : false)
        };
        file.reloading = true;
        reload();
        file.reloading = false;
    }

    function finishMerge() {
        const m = file.pendingMerge;
        file.pendingMerge = null;
        const disk = file.parsed();
        if (disk !== null)
            file.synced = disk;
        if (!m || file.broken || disk === null)
            return;
        const list = ConfigMerge.changes(m.base, m.local);
        if (list.length === 0)
            return;
        file.reloading = true;
        for (let i = 0; i < list.length; i++)
            ConfigMerge.assign(file.adapter, list[i].path, list[i].value);
        file.reloading = false;
        if (m.force)
            file.writeSynced();
        else
            file.scheduleWrite();
    }

    // `migrated`: the parsed file after the key-alias migration (AliasGate).
    function validate(onComplete, migrated) {
        var raw = file.text();
        if (!raw || raw.trim().length === 0) {
            // File is missing or empty — create with defaults
            console.log(name + ".json missing or empty, creating default...");
            file.setText(JSON.stringify(ConfigValidator.validateDomain(migrated, defaults, file.name), null, 2));
            onComplete();
            return;
        }

        try {
            var current = JSON.parse(raw);
            var source = current;
            if (file.pendingOverlay !== undefined) {
                source = ConfigValidator.overlay(current, file.pendingOverlay);
                file.pendingOverlay = undefined;
            }
            var validated = ConfigValidator.validateDomain(migrated !== undefined ? migrated : source, defaults, file.name);

            if (!JsonUtil.deepEqual(current, validated)) {
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
                    current[key] = JsonUtil.clone(defaults[key]);
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
    // `migrated`: values the key aliases moved into it; they win over the
    // preset's and are kept when the defaults are used.
    function handleMissing(onComplete, migrated) {
        var presetPath = store.presetDir + "/" + name + ".json";
        var targetPath = store.configDir + "/" + name + ".json";
        console.log(name + ".json not found, checking preset: " + presetPath);
        var copy = copyProcess.createObject(file, {
            // Writable even when the preset is read-only (the Nix store)
            command: ["sh", "-c", 'cp -n -- "$1" "$2" && chmod u+w -- "$2"', "seed-config", presetPath, targetPath],
            whenDone: exitCode => {
                // Copied: the reload validates it. Otherwise use the defaults.
                if (exitCode === 0) {
                    file.pendingOverlay = migrated;
                    file.reload();
                } else {
                    console.log("Using defaults for " + name + ".json");
                    file.setText(JSON.stringify(migrated !== undefined ? ConfigValidator.validateDomain(migrated, defaults, file.name) : defaults, null, 2));
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
