pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.modules.globals
import qs.modules.services
import "../presets/PresetModel.js" as PresetModel

// Data and actions of the settings preset studio. Every operation is a
// `<app> preset ...` command (backend/pkg/presets), so the studio, the CLI
// and the MCP tools behave identically; nothing here writes preset files.
// Sessions live in the backend (they survive a shell restart): a trial
// applies a preset for `trialSeconds` and reverts unless kept; an edit
// applies a user preset so every settings page edits it live, then saves
// the live config into the preset and brings the previous look back.
Singleton {
    id: root

    property var presets: [] // `preset list --json`
    property var aspects: [] // `preset aspects --json`
    property bool loaded: false
    property bool loading: false
    property string error: ""
    readonly property var activePreset: presets.find(p => p.active) || null
    readonly property string active: activePreset ? activePreset.name : ""
    property var trial: null // {preset, started} while trying
    property var edit: null // {preset, started} while editing
    property int trialSeconds: 10 // trial length (tests shorten it)
    property real trialLeft: 0 // ms
    property string pending: "" // name of the preset an action is running for
    // Transient notice {text, undo: trash id | ""} shown by PresetToast.
    property var toast: null
    property var lastDeleted: null
    // The studio view a navigation should open ("gallery" | "mixer" |
    // "editor:<name>"); the page consumes it.
    property string requestedView: ""
    // Command runner: (args, cb(ok, stdout, stderr)). Tests replace it.
    property var runner: null
    readonly property Component procFactory: Component {
        Process {
            property var done: null

            onExited: code => {
                if (done)
                    done(code === 0, so.text, se.text);

                destroy();
            }

            stdout: StdioCollector {
                id: so
            }

            stderr: StdioCollector {
                id: se
            }
        }
    }

    // ── Thumbnails ──────────────────────────────────────────────────────
    // PNGs in <cache>/preset-thumbs/<md5 of the key>.png; the index tells a
    // thumbnail whether to load its PNG or render it.
    readonly property string thumbDir: Brand.cacheDir + "/preset-thumbs"
    property var thumbSet: ({})
    property bool thumbIndexReady: false
    readonly property int maxRendering: 2
    property int rendering: 0 // thumbnails rendering right now
    property var renderHolders: ({}) // holder id -> since (ms)

    function run(args, cb) {
        const done = cb || function () {};
        if (runner) {
            runner(args, done);
            return;
        }
        const p = procFactory.createObject(root, {
            "command": [Brand.appId, "preset"].concat(args),
            "done": done
        });
        p.running = true;
    }

    function cleanError(err) {
        return (err || "").trim().replace(/^Error: /, "").split("\n")[0];
    }

    function notify(text, undo) {
        toast = {
            "text": text,
            "undo": undo || "",
            "serial": Date.now()
        };
    }

    function fail(err) {
        error = cleanError(err);
        notify(error, "");
    }

    // ── Loading ─────────────────────────────────────────────────────────
    function refresh() {
        loading = true;
        run(["list", "--json"], (ok, out, err) => {
            loading = false;
            if (!ok) {
                fail(err);
                return;
            }
            try {
                root.presets = JSON.parse(out) || [];
                root.loaded = true;
            } catch (e) {
                fail(String(e));
            }
        });
        if (!aspects.length) {
            run(["aspects", "--json"], (ok, out) => {
                if (ok) {
                    try {
                        root.aspects = JSON.parse(out) || [];
                    } catch (e) {}
                }
            });
        }
        refreshSessions();
    }

    function refreshSessions() {
        run(["try", "--status", "--json"], (ok, out) => {
            if (!ok)
                return;

            const s = parse(out);
            root.trial = s;
            if (s && !trialTimer.running) {
                // A trial outlived the window (or the shell): give it a
                // fresh countdown rather than reverting behind the user.
                root.trialLeft = root.trialSeconds * 1000;
                trialTimer.restart();
            }
        });
        run(["edit", "--status", "--json"], (ok, out) => {
            if (ok)
                root.edit = parse(out);
        });
    }

    function parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            return null;
        }
    }

    function find(name) {
        return PresetModel.byName(presets, name);
    }

    // Staged settings edits are written first, so a trial's backup, a
    // saved look and a preset edit hold exactly what the user sees; the
    // command runs once the config files are on disk.
    function afterFlush(fn) {
        if (!SettingsStore.hasChanges) {
            fn();
            return;
        }
        SettingsStore.apply();
        flushDelay.queue.push(fn);
        flushDelay.restart();
    }

    // ── Apply / try ─────────────────────────────────────────────────────
    // One session/apply at a time: `pending` is set before the flush, so a
    // double click (or a second action) never starts a second command.
    function busy() {
        return !!(trial || edit || pending);
    }

    function apply(name) {
        if (busy())
            return;

        pending = name;
        afterFlush(() => {
            run(["apply", name], (ok, out, err) => {
                pending = "";
                if (!ok)
                    fail(err);

                refresh();
            });
        });
    }

    function tryPreset(name) {
        if (busy())
            return;

        pending = name;
        afterFlush(() => {
            run(["try", name], (ok, out, err) => {
                pending = "";
                if (!ok) {
                    fail(err);
                    return;
                }
                root.trial = {
                    "preset": name
                };
                root.trialLeft = root.trialSeconds * 1000;
                trialTimer.restart();
                refresh();
            });
        });
    }

    function endTrial(keep) {
        trialTimer.stop();
        if (!trial || pending)
            return;

        pending = trial.preset;
        const done = () => {
            return run(["try", keep ? "--keep" : "--revert"], (ok, out, err) => {
                pending = "";
                if (!ok)
                    fail(err);

                root.trial = null;
                refresh();
            });
        };
        if (keep) {
            afterFlush(done);
        } else {
            if (SettingsStore.hasChanges)
                SettingsStore.discard();

            done();
        }
    }

    // ── Create / organize ───────────────────────────────────────────────
    function saveCurrent(name, cb) {
        afterFlush(() => {
            run(["save", name], (ok, out, err) => {
                if (!ok)
                    fail(err);
                else
                    notify(I18n.t("prefs.presets.toast.saved", name), "");
                refresh();
                if (cb)
                    cb(ok);
            });
        });
    }

    function updateFromCurrent(name) {
        afterFlush(() => {
            run(["update", name], (ok, out, err) => {
                if (!ok)
                    fail(err);
                else
                    notify(I18n.t("prefs.presets.toast.updated", name), "");
                refresh();
            });
        });
    }

    function duplicate(name, newName, cb) {
        const args = ["duplicate", name];
        if (newName)
            args.push(newName);

        args.push("--json");
        run(args, (ok, out, err) => {
            const p = ok ? parse(out) : null;
            if (!ok)
                fail(err);
            else
                notify(I18n.t("prefs.presets.toast.duplicated", p ? p.name : newName), "");
            refresh();
            if (cb)
                cb(ok, p ? p.name : "");
        });
    }

    function rename(name, newName, cb) {
        run(["rename", name, newName], (ok, out, err) => {
            if (!ok)
                fail(err);

            refresh();
            if (cb)
                cb(ok);
        });
    }

    function remove(name) {
        run(["delete", name, "--json"], (ok, out, err) => {
            if (!ok) {
                fail(err);
                return;
            }
            const t = parse(out);
            root.lastDeleted = t;
            notify(I18n.t("prefs.presets.toast.deleted", name), t ? t.id : "");
            refresh();
        });
    }

    function undoDelete(id) {
        run(["restore", id], (ok, out, err) => {
            if (!ok)
                fail(err);

            root.toast = null;
            refresh();
        });
    }

    function setDescription(name, text) {
        run(["set-info", name, "--description", text], (ok, out, err) => {
            if (!ok)
                fail(err);

            refresh();
        });
    }

    function mix(name, sources, cb) {
        const args = ["mix", name, "--json"];
        Object.keys(sources).forEach(a => {
            if (sources[a])
                args.push("--" + a, sources[a]);
        });
        run(args, (ok, out, err) => {
            if (!ok)
                fail(err);
            else
                notify(I18n.t("prefs.presets.toast.mixed", name), "");
            refresh();
            if (cb)
                cb(ok);
        });
    }

    // cb(inspection | null): `preset show --json` (aspects, changes, sameAs).
    function inspect(name, against, cb) {
        const args = ["show", name, "--json"];
        if (against)
            args.push("--against", against);

        run(args, (ok, out, err) => cb(ok ? parse(out) : null, cleanError(err)));
    }

    // ── Export / import ─────────────────────────────────────────────────
    function exportTo(name, file) {
        run(["export", name, file], (ok, out, err) => {
            if (!ok)
                fail(err);
            else
                notify(I18n.t("prefs.presets.toast.exported", file), "");
        });
    }

    function importFile(file, cb) {
        const path = String(file).replace(/^file:\/\//, "");
        run(["import", decodeURIComponent(path)], (ok, out, err) => {
            if (!ok)
                fail(err);
            else
                notify(I18n.t("prefs.presets.toast.imported"), "");
            refresh();
            if (cb)
                cb(ok);
        });
    }

    function pick(command, cb) {
        const p = procFactory.createObject(root, {
            "command": command,
            "done": (ok, out) => {
                if (ok && out.trim())
                    cb(out.trim());
            }
        });
        p.running = true;
    }

    function pickExport(name) {
        const file = (Quickshell.env("HOME") || "") + "/" + name.replace(/[^\w.-]+/g, "-") + "." + Brand.appId + "-preset.json";
        pick(["zenity", "--file-selection", "--save", "--confirm-overwrite", "--title=" + I18n.t("prefs.presets.export"), "--filename=" + file, "--file-filter=*.json"], f => exportTo(name, f));
    }

    function pickImport() {
        pick(["zenity", "--file-selection", "--title=" + I18n.t("prefs.presets.import"), "--file-filter=*.json"], f => importFile(f));
    }

    // ── Editing a preset ────────────────────────────────────────────────
    function beginEdit(name) {
        if (busy())
            return;

        pending = name;
        afterFlush(() => {
            run(["edit", name], (ok, out, err) => {
                pending = "";
                if (!ok) {
                    fail(err);
                    return;
                }
                root.edit = {
                    "preset": name
                };
                refresh();
            });
        });
    }

    // save: write the live config into the preset; keep: stay on it.
    // Without save the edits are dropped and the previous look returns.
    function finishEdit(save, keep) {
        if (!edit || pending)
            return;

        const args = ["edit", save ? "--save" : "--cancel"];
        if (keep)
            args.push("--keep");

        const name = edit.preset;
        pending = name;
        const done = () => {
            return run(args, (ok, out, err) => {
                pending = "";
                if (!ok) {
                    fail(err);
                    return;
                }
                root.edit = null;
                if (save)
                    notify(I18n.t("prefs.presets.toast.edit_saved", name), "");

                refresh();
            });
        };
        if (save) {
            afterFlush(done);
        } else {
            if (SettingsStore.hasChanges)
                SettingsStore.discard();

            done();
        }
    }

    // A render slot for a thumbnail (false: wait for renderingChanged).
    function acquireRender(id) {
        if (renderHolders[id] === undefined) {
            if (rendering >= maxRendering)
                return false;

            renderHolders[id] = Date.now();
        }
        rendering = Object.keys(renderHolders).length;
        return true;
    }

    function releaseRender(id) {
        if (renderHolders[id] === undefined)
            return;

        delete renderHolders[id];
        rendering = Object.keys(renderHolders).length;
    }

    function thumbName(key) {
        return Qt.md5(key) + ".png";
    }

    function thumbFile(key) {
        return thumbDir + "/" + thumbName(key);
    }

    function hasThumb(key) {
        return !!thumbSet[thumbName(key)];
    }

    function markRendered(key) {
        const m = Object.assign({}, thumbSet);
        m[thumbName(key)] = true;
        thumbSet = m;
    }

    function indexThumbs() {
        const m = {};
        for (let i = 0; i < thumbIndex.count; i++)
            m[thumbIndex.get(i, "fileName")] = true;
        thumbSet = m;
        thumbIndexReady = true;
    }

    Component.onCompleted: {
        if (!runner)
            mkThumbDir.running = true;
    }

    Timer {
        id: flushDelay

        property var queue: []

        interval: 250
        onTriggered: {
            const q = queue;
            queue = [];
            q.forEach(f => f());
        }
    }

    Timer {
        id: trialTimer

        interval: 100
        repeat: true
        onTriggered: {
            root.trialLeft = Math.max(0, root.trialLeft - interval);
            if (root.trialLeft <= 0)
                root.endTrial(false);
        }
    }

    // A holder destroyed mid-render never releases: expire stale slots.
    Timer {
        interval: 2000
        repeat: true
        running: root.rendering > 0
        onTriggered: {
            const now = Date.now();
            Object.keys(root.renderHolders).forEach(id => {
                if (now - root.renderHolders[id] > 6000)
                    root.releaseRender(id);
            });
        }
    }

    FolderListModel {
        id: thumbIndex

        folder: "file://" + root.thumbDir
        nameFilters: ["*.png"]
        showDirs: false
        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                root.indexThumbs();
            }
        }
        onCountChanged: {
            if (status === FolderListModel.Ready) {
                root.indexThumbs();
            }
        }
    }

    // A missing folder never reports Ready: render everything then.
    Timer {
        running: !root.thumbIndexReady
        interval: 1500
        onTriggered: root.thumbIndexReady = true
    }

    Process {
        id: mkThumbDir

        command: ["mkdir", "-p", root.thumbDir]
    }
}
