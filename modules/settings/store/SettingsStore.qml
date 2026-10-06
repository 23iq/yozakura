pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services
import "../SchemaUtil.js" as SchemaUtil
import "../SettingsDefaults.js" as SettingsDefaults

// Read/write access to settings keys for the schema renderer.
//
// Change flow (compatible with the legacy panels): the first edit of a
// staged domain takes the GlobalStates snapshot (mark*Changed pauses
// auto-save), every edit is applied live to Config so the whole shell
// previews it, and the ChangesBar applies (writes the JSON files) or
// discards (restores the snapshot). Domains without a snapshot list and
// wallpaper keys (wallpapers.json) are written immediately.
Singleton {
    id: root

    readonly property var themeDomains: ["theme"]
    readonly property var compositorDomains: ["compositor"]
    readonly property var shellDomains: Object.keys(GlobalStates._shellSections || {})

    readonly property bool hasChanges: GlobalStates.themeHasChanges || GlobalStates.shellHasChanges || GlobalStates.compositorHasChanges

    // Set by the settings window to flash an entry after a search jump.
    property string highlightedEntry: ""

    signal navigateRequested(string categoryId, string sectionId, string entryId)
    // A settings control (or reset) changed `key`: lets an editor react to
    // user actions only, never to config changes from elsewhere.
    signal valueSet(string key, var value)

    function navigate(categoryId, sectionId, entryId) {
        navigateRequested(categoryId, sectionId || "", entryId || "");
    }

    readonly property var wallpaperManager: GlobalStates.wallpaperManager

    function get(key) {
        if (!key)
            return undefined;
        const k = SchemaUtil.splitKey(key);
        if (SchemaUtil.storeOf(key) === "wallpaper") {
            const m = root.wallpaperManager;
            if (!m)
                return SettingsDefaults.get(key);
            if (k.prop === "matugenScheme")
                return m.currentMatugenScheme;
            if (k.prop === "activeColorPreset")
                return m.activeColorPreset;
            if (k.prop === "wallPath")
                return m.wallpaperDir;
            return undefined;
        }
        const domain = Config[k.domain];
        if (!domain)
            return undefined;
        return SchemaUtil.getPath(domain, k.path);
    }

    function defaultValue(key) {
        return SettingsDefaults.get(key);
    }

    function stage(domain) {
        if (themeDomains.indexOf(domain) !== -1)
            GlobalStates.markThemeChanged();
        else if (compositorDomains.indexOf(domain) !== -1)
            GlobalStates.markCompositorChanged();
        else if (shellDomains.indexOf(domain) !== -1)
            GlobalStates.markShellChanged();
    }

    function isStaged(domain) {
        return themeDomains.indexOf(domain) !== -1 || compositorDomains.indexOf(domain) !== -1 || shellDomains.indexOf(domain) !== -1;
    }

    function set(key, value) {
        if (!key || SchemaUtil.equal(get(key), value))
            return;
        const k = SchemaUtil.splitKey(key);
        if (SchemaUtil.storeOf(key) === "wallpaper") {
            const m = root.wallpaperManager;
            if (!m)
                return;
            if (k.prop === "matugenScheme")
                m.setMatugenScheme(value);
            else if (k.prop === "activeColorPreset")
                m.setColorPreset(value);
            else if (k.prop === "wallPath" && m.setWallpaperDir)
                m.setWallpaperDir(value);
            return;
        }
        const domain = Config[k.domain];
        if (!domain) {
            console.warn("SettingsStore: unknown config domain for", key);
            return;
        }
        stage(k.domain);
        // Descend through nested JsonObject children (e.g. ai.quickAsk.enabled):
        // their properties are assigned in place; a `property var` object on
        // the way is replaced by an updated copy (e.g. bar.layout.style).
        let target = domain;
        let i = 0;
        while (i < k.path.length - 1) {
            const child = target[k.path[i]];
            if (!child || typeof child !== "object" || Array.isArray(child) || child.objectName === undefined)
                break;
            target = child;
            i++;
        }
        if (i === k.path.length - 1)
            target[k.path[i]] = SchemaUtil.plain(value);
        else
            target[k.path[i]] = SchemaUtil.withPath(target[k.path[i]], k.path.slice(i + 1), value);
        if (!isStaged(k.domain)) {
            const saver = Config["save" + k.domain.charAt(0).toUpperCase() + k.domain.slice(1)];
            if (typeof saver === "function")
                saver();
        }
        root.valueSet(key, value);
    }

    function isModified(entry) {
        if (!entry || !SchemaUtil.isResettable(entry))
            return false;
        const keys = SchemaUtil.entryKeys(entry);
        for (let i = 0; i < keys.length; i++) {
            const def = defaultValue(keys[i]);
            if (def !== undefined && !SchemaUtil.equal(get(keys[i]), def))
                return true;
        }
        return false;
    }

    function reset(entry) {
        if (!SchemaUtil.isResettable(entry))
            return;
        const keys = SchemaUtil.entryKeys(entry);
        for (let i = 0; i < keys.length; i++) {
            const def = defaultValue(keys[i]);
            if (def !== undefined)
                set(keys[i], def);
        }
    }

    function modifiedCount(category) {
        let n = 0;
        const all = SchemaUtil.flatten([category]);
        for (let i = 0; i < all.length; i++) {
            if (isModified(all[i].entry))
                n++;
        }
        return n;
    }

    function resetCategory(category) {
        const all = SchemaUtil.flatten([category]);
        for (let i = 0; i < all.length; i++)
            reset(all[i].entry);
    }

    // One schema section of a page (its header's reset button).
    function sectionModifiedCount(section) {
        return section ? modifiedCount({
            "sections": [section]
        }) : 0;
    }

    function resetSection(section) {
        if (section)
            resetCategory({
                "sections": [section]
            });
    }

    function visible(entry) {
        // entries tied to one compositor (exclusive mode: Hyprland)
        if (entry.compositor && YozdService.compositorName !== entry.compositor)
            return false;
        return SchemaUtil.evalCondition(entry.visibleWhen, root.get);
    }

    function enabled(entry) {
        return SchemaUtil.evalCondition(entry.enabledWhen, root.get);
    }

    function apply() {
        GlobalStates.applyThemeChanges();
        GlobalStates.applyShellChanges();
        GlobalStates.applyCompositorChanges();
    }

    function discard() {
        GlobalStates.discardThemeChanges();
        GlobalStates.discardShellChanges();
        GlobalStates.discardCompositorChanges();
    }
}
