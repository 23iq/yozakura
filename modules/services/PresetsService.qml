pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs.modules.services
import qs.modules.globals

// Preset list + actions for the quick preset switcher (bar button popup).
// Every operation runs `<app> preset ...` (backend/pkg/presets), the same
// code the settings preset studio, the CLI and the MCP tools use, so they
// all agree on names, excluded files, validation and the active marker.
Singleton {
    id: root

    // [{name, path, isOfficial, configFiles: ["bar.js", ...], author, authorUrl, description, tags}]
    property var presets: []
    property string currentPreset: ""
    property string activePreset: ""

    readonly property string presetsDir: Brand.configDir + "/presets"
    readonly property string activePresetFile: presetsDir + "/active_preset"

    signal presetsUpdated

    function isOfficialName(name) {
        return presets.some(p => p.name.toLowerCase() === name.toLowerCase() && p.isOfficial);
    }

    readonly property Component procFactory: Component {
        Process {
            property var done: null
            stdout: StdioCollector {
                id: so
            }
            stderr: StdioCollector {
                id: se
            }
            onExited: code => {
                if (done)
                    done(code === 0, so.text, se.text);
                destroy();
            }
        }
    }

    // Runs `<app> preset <args>`; cb(ok, stdout, stderr).
    // Dry run: changes are journaled; they only run when the config dir is
    // the dry run's temp copy (the preview then really shows the preset).
    function run(args, cb) {
        if (DryRun.active && args[0] !== "list") {
            DryRun.journal(args[0] === "apply" ? "apply preset " + args.slice(1).join(" ") : "preset " + args.join(" "));
            if (!DryRun.sandboxed) {
                if (cb)
                    Qt.callLater(() => cb(true, "", ""));
                return;
            }
        }
        const p = procFactory.createObject(root, {
            command: [Brand.appId, "preset"].concat(args),
            done: cb || null
        });
        p.running = true;
    }

    function notify(ok, summary, body, err) {
        // a dry-run instance never claims the notification server
        if (DryRun.active)
            return;
        Notifications.notifyInternal({
            summary: ok ? summary : "Error",
            body: ok ? body : (err || body).trim().replace(/^Error: /, ""),
            appName: "Presets",
            urgency: ok ? "normal" : "critical"
        });
    }

    function scanPresets() {
        run(["list", "--json"], (ok, out) => {
            if (!ok)
                return;
            try {
                const list = JSON.parse(out) || [];
                root.presets = list.map(p => ({
                            name: p.name,
                            path: p.path,
                            isOfficial: p.official,
                            configFiles: (p.domains || []).map(d => d + ".js"),
                            author: p.author || "Unknown",
                            authorUrl: p.authorUrl || "",
                            description: p.description || "",
                            tags: p.tags || []
                        }));
                // The backend resolves a stale marker (a removed preset) to
                // the default preset, so its answer wins over the raw file.
                const active = list.find(p => p.active);
                root.activePreset = active ? active.name : "";
                root.presetsUpdated();
            } catch (e) {
                console.warn("PresetsService: bad preset list:", e);
            }
        });
        readActive.reload();
    }

    function loadPreset(presetName) {
        if (!presetName)
            return;
        currentPreset = presetName;
        run(["apply", presetName], (ok, out, err) => {
            if (ok)
                root.activePreset = presetName;
            root.currentPreset = "";
            root.notify(ok, "Preset Loaded", `Preset "${presetName}" loaded successfully.`, err);
        });
    }

    function domainsArg(configFiles) {
        return (configFiles || []).map(f => f.replace(/\.js(on)?$/, "")).join(",");
    }

    function savePreset(presetName, configFiles) {
        if (!presetName)
            return;
        const args = ["save", presetName];
        if (configFiles && configFiles.length)
            args.push("--domains", domainsArg(configFiles));
        run(args, (ok, out, err) => {
            root.notify(ok, "Preset Saved", `Preset "${presetName}" saved successfully.`, err);
            root.scanPresets();
        });
    }

    function renamePreset(oldName, newName) {
        if (!oldName || !newName || oldName === newName)
            return;
        run(["rename", oldName, newName], (ok, out, err) => {
            if (ok && root.activePreset === oldName)
                root.activePreset = newName;
            root.notify(ok, "Preset Renamed", `Preset renamed to "${newName}".`, err);
            root.scanPresets();
        });
    }

    // Built-in presets are read-only: updating one saves a user copy.
    function updatePreset(presetName, configFiles) {
        if (!presetName)
            return;
        const preset = presets.find(p => p.name === presetName);
        if (preset && preset.isOfficial) {
            savePreset(presetName + " (Custom)", configFiles);
            return;
        }
        const args = ["update", presetName];
        if (configFiles && configFiles.length)
            args.push("--domains", domainsArg(configFiles));
        run(args, (ok, out, err) => {
            root.notify(ok, "Preset Updated", `Preset "${presetName}" updated successfully.`, err);
            root.scanPresets();
        });
    }

    function deletePreset(presetName) {
        if (!presetName)
            return;
        run(["delete", presetName], (ok, out, err) => {
            if (ok && root.activePreset === presetName)
                root.activePreset = "";
            root.notify(ok, "Preset Deleted", `Preset "${presetName}" deleted.`, err);
            root.scanPresets();
        });
    }

    FileView {
        id: readActive
        path: root.activePresetFile
        watchChanges: true
        printErrors: false
        // A marker naming a preset that is not in the list keeps the
        // backend's resolution (scanPresets) instead of the stale name.
        onLoaded: {
            const name = text().trim();
            if (!name || !root.presets.length || root.presets.some(p => p.name === name))
                root.activePreset = name;
        }
        onFileChanged: reload()
    }

    // New, renamed or deleted presets (also from the CLI or the settings).
    FileView {
        path: root.presetsDir
        watchChanges: true
        printErrors: false
        onFileChanged: rescan.restart()
    }

    Timer {
        id: rescan
        interval: 250
        onTriggered: root.scanPresets()
    }

    property bool _initialized: false

    function initialize() {
        if (_initialized)
            return;
        _initialized = true;
        scanPresets();
    }
}
