import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.config.adapters
import "KeybindActions.js" as KeybindActions
import "CoreBinds.js" as CoreBinds
import "CustomBindDefaults.js" as CustomBindDefaults
import "../modules/globals/BrandActions.js" as BrandActions

// binds.json (<app dir>/binds.json): the shell's core binds, the disabled
// list and the user's custom compositor binds, bound to the generated
// KeybindsAdapter. Creates the file when missing, repairs/migrates old
// layouts after the first load and normalizes custom binds to the action
// format. Config.keybindsLoader is `loader`.
Scope {
    id: root

    // The Config singleton: keybindsPath and the shared pauseAutoSave.
    required property var store
    property bool initialLoadComplete: false
    property alias loader: loader

    // Timer to repair keybinds after initial load
    Timer {
        id: repairKeybindsTimer
        interval: 500
        repeat: false
        onTriggered: {
            root.repairKeybinds();
        }
    }

    // Timer to create binds.json if missing after initial load
    Timer {
        id: createKeybindsTimer
        interval: 1000
        repeat: false
        onTriggered: {
            const raw = loader.text();
            if (!raw || raw.trim().length === 0) {
                console.log("binds.json still missing after delay, creating...");
                loader.writeAdapter();
                repairKeybindsTimer.start();
            }
        }
    }
    // Repair missing binds
    function repairKeybinds() {
        const raw = loader.text();
        if (!raw)
            return;

        try {
            const current = JSON.parse(raw);
            let needsUpdate = false;

            // Files written by the legacy app keep their core binds under its
            // id ("ambxst"); move them over instead of resetting to defaults.
            const legacyRoot = Brand.legacyAppId;
            if (current[legacyRoot] && !current.yozakura) {
                console.log("Migrating legacy binds root to yozakura...");
                current.yozakura = current[legacyRoot];
                needsUpdate = true;
            }
            for (const stale of [legacyRoot, "default" + BrandActions.legacyDisplayName + "Binds"]) {
                if (current[stale] !== undefined) {
                    delete current[stale];
                    needsUpdate = true;
                }
            }
            // Legacy action ids ("ambxst.launcher") are rewritten in place;
            // dispatch also accepts them (KeybindActions.getActionById).
            const normalizeIds = node => {
                if (!node || typeof node !== "object")
                    return;
                if (node.action && typeof node.action.id === "string") {
                    const id = BrandActions.normalizeAction(node.action.id);
                    if (id !== node.action.id) {
                        node.action.id = id;
                        needsUpdate = true;
                    }
                }
                if (Array.isArray(node.actions))
                    node.actions.forEach(a => {
                        if (a && typeof a.id === "string" && BrandActions.normalizeAction(a.id) !== a.id) {
                            a.id = BrandActions.normalizeAction(a.id);
                            needsUpdate = true;
                        }
                    });
                for (const k in node)
                    if (k !== "action" && k !== "actions")
                        normalizeIds(node[k]);
            };
            normalizeIds(current);

            // Ensure yozakura structure exists
            if (!current.yozakura) {
                current.yozakura = {};
                needsUpdate = true;
            }

            // Migrate nested to flat structure
            if (current.yozakura.dashboard && typeof current.yozakura.dashboard === "object" && !current.yozakura.dashboard.modifiers) {
                console.log("Migrating nested yozakura binds to flat structure...");
                const nested = current.yozakura.dashboard;

                // Map old names to new names and update arguments
                if (nested.widgets) {
                    current.yozakura.launcher = nested.widgets;
                    current.yozakura.launcher.argument = Brand.appId + " run launcher";
                    current.yozakura.launcher.action = createAction(current.yozakura.launcher);
                }
                if (nested.dashboard) {
                    current.yozakura.dashboard = nested.dashboard;
                    current.yozakura.dashboard.argument = Brand.appId + " run dashboard";
                    current.yozakura.dashboard.action = createAction(current.yozakura.dashboard);
                }
                if (nested.assistant) {
                    current.yozakura.assistant = nested.assistant;
                    current.yozakura.assistant.argument = Brand.appId + " run assistant";
                    current.yozakura.assistant.action = createAction(current.yozakura.assistant);
                }
                if (nested.clipboard) {
                    current.yozakura.clipboard = nested.clipboard;
                    current.yozakura.clipboard.argument = Brand.appId + " run clipboard";
                    current.yozakura.clipboard.action = createAction(current.yozakura.clipboard);
                }
                if (nested.emoji) {
                    current.yozakura.emoji = nested.emoji;
                    current.yozakura.emoji.argument = Brand.appId + " run emoji";
                    current.yozakura.emoji.action = createAction(current.yozakura.emoji);
                }
                if (nested.notes) {
                    current.yozakura.notes = nested.notes;
                    current.yozakura.notes.argument = Brand.appId + " run notes";
                    current.yozakura.notes.action = createAction(current.yozakura.notes);
                }
                if (nested.tmux) {
                    current.yozakura.tmux = nested.tmux;
                    current.yozakura.tmux.argument = Brand.appId + " run tmux";
                    current.yozakura.tmux.action = createAction(current.yozakura.tmux);
                }
                if (nested.wallpapers) {
                    current.yozakura.wallpapers = nested.wallpapers;
                    current.yozakura.wallpapers.argument = Brand.appId + " run wallpapers";
                    current.yozakura.wallpapers.action = createAction(current.yozakura.wallpapers);
                }

                // Remove the old nested object
                delete current.yozakura.dashboard;
                needsUpdate = true;
            }

            if (!current.yozakura.system) {
                current.yozakura.system = {};
                needsUpdate = true;
            }

            // Get default binds from adapter
            const adapter = loader.adapter;
            if (!adapter || !adapter.yozakura)
                return;

            // Helper function to create clean bind object
            function createAction(bindObj) {
                if (bindObj && bindObj.action) {
                    return KeybindActions.ensureAction(bindObj.action);
                }
                return KeybindActions.actionFromLegacy(bindObj.dispatcher || "", bindObj.argument || "", bindObj.flags || "");
            }

            function createCleanBind(bindObj) {
                return {
                    "modifiers": bindObj.modifiers || [],
                    "key": bindObj.key || "",
                    "action": createAction(bindObj)
                };
            }

            // Check yozakura core binds
            const yozakuraKeys = CoreBinds.names("");
            for (const key of yozakuraKeys) {
                if (!current.yozakura[key] && adapter.yozakura[key]) {
                    console.log("Adding missing yozakura bind:", key);
                    current.yozakura[key] = createCleanBind(adapter.yozakura[key]);
                    needsUpdate = true;
                } else if (current.yozakura[key] && !current.yozakura[key].action) {
                    current.yozakura[key].action = createAction(current.yozakura[key]);
                    delete current.yozakura[key].dispatcher;
                    delete current.yozakura[key].argument;
                    delete current.yozakura[key].flags;
                    needsUpdate = true;
                }
            }

            // Check system binds
            const systemKeys = CoreBinds.names("system");
            for (const key of systemKeys) {
                if (!current.yozakura.system[key] && adapter.yozakura.system && adapter.yozakura.system[key]) {
                    console.log("Adding missing system bind:", key);
                    current.yozakura.system[key] = createCleanBind(adapter.yozakura.system[key]);
                    needsUpdate = true;
                } else if (current.yozakura.system[key] && !current.yozakura.system[key].action) {
                    current.yozakura.system[key].action = createAction(current.yozakura.system[key]);
                    delete current.yozakura.system[key].dispatcher;
                    delete current.yozakura.system[key].argument;
                    delete current.yozakura.system[key].flags;
                    needsUpdate = true;
                }
            }

            // New default custom binds reach existing files once per id.
            const migrations = Array.isArray(current.migrations) ? current.migrations : [];
            if (migrations.indexOf("window-fullscreen") === -1) {
                const added = KeybindActions.addNewDefaults(current.custom, CustomBindDefaults.binds(), ["window.fullscreen", "window.maximize"]);
                if (added.changed)
                    current.custom = added.binds;
                current.migrations = migrations.concat(["window-fullscreen"]);
                needsUpdate = true;
            }

            if (current.custom && current.custom.length > 0) {
                const normalized = KeybindActions.normalizeCustomBinds(current.custom);
                if (normalized.changed) {
                    current.custom = normalized.binds;
                    needsUpdate = true;
                }
            }

            if (needsUpdate) {
                console.log("Auto-repairing binds.json: adding missing binds");
                loader.setText(JSON.stringify(current, null, 2));
            }
        } catch (e) {
            console.warn("Failed to repair binds.json:", e);
        }
    }
    FileView {
        id: loader
        path: root.store.keybindsPath
        atomicWrites: true
        watchChanges: true
        Component.onCompleted: {
            // Ensure binds.json is created even if onLoaded never fires
            createKeybindsTimer.start();
        }
        onLoaded: {
            if (!root.initialLoadComplete) {
                var raw = text();
                if (!raw || raw.trim().length === 0) {
                    console.log("binds.json not found, creating with default values...");
                    loader.writeAdapter();
                    repairKeybindsTimer.start();
                } else {
                    // File exists, check if it needs repair
                    repairKeybindsTimer.start();
                }
                root.initialLoadComplete = true;
                createKeybindsTimer.start();
            }
        }
        onFileChanged: {
            root.store.pauseAutoSave = true;
            reload();
            normalizeCustomBinds();
            root.store.pauseAutoSave = false;
        }
        onPathChanged: {
            reload();
            normalizeCustomBinds();
        }
        onAdapterUpdated: {
            if (root.initialLoadComplete) {
                loader.writeAdapter();
            }
        }

        // Normalize custom binds
        function normalizeCustomBinds() {
            if (!adapter || !adapter.custom)
                return;

            const normalized = KeybindActions.normalizeCustomBinds(adapter.custom);
            if (normalized.changed) {
                console.log("Normalizing custom binds: migrating to action format");
                adapter.custom = normalized.binds;
            }
        }

        adapter: KeybindsAdapter {}
    }
}
