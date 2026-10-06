pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services
import qs.config
import "BrandActions.js" as BrandActions

Singleton {
    id: root

    property var wallpaperManager: null
    property string avatarCacheBuster: ""

    // Broadcast to every BarContent instance: flip the pinned state.
    signal barPinToggled()

    function pickUserAvatar() {
        filePickerProcess.running = true;
    }

    Process {
        id: filePickerProcess
        running: false
        command: ["zenity", "--file-selection", "--title=Select User Icon", "--file-filter=Images | *.png *.jpg *.jpeg *.svg *.webp"]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path) {
                    console.log("Selected icon:", path);
                    copyIconProcess.command = ["cp", path, Quickshell.env("HOME") + "/.face.icon"];
                    copyIconProcess.running = true;
                }
            }
        }
    }

    Process {
        id: copyIconProcess
        running: false
        command: []

        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Icon updated successfully");
                avatarCacheBuster = Date.now();
            } else {
                console.warn("Failed to update icon");
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // COMPOSITOR LAYOUT STATE (persisted via StateService)
    // Layouts are fetched per compositor from `yozd layout list`;
    // on niri that's just ["scrolling"], on hyprland the live set.
    // ═══════════════════════════════════════════════════════════════
    property string compositorLayout: ""
    property bool compositorLayoutReady: false
    readonly property var fallbackLayouts: ["dwindle", "master", "scrolling", "monocle"]
    property var availableLayouts: fallbackLayouts

    Timer {
        id: layoutFetchRetry
        interval: 1000
        repeat: true
        property int attempts: 0

        onTriggered: {
            attempts++;
            if (attempts > 30) {
                running = false;
                return;
            }
            root.fetchLayoutList();
        }
    }

    function applyLayoutList(payload) {
        if (!payload) return;
        const names = (payload.items || []).map(item => item.name).filter(name => !!name);
        if (names.length > 0) {
            root.availableLayouts = names;
        }
        const active = payload.active || ((payload.items || []).find(item => item.current) || {}).name || "";
        if (active) {
            root.compositorLayout = active;
        } else {
            root.compositorLayout = StateService.get("compositorLayout", names[0] || "dwindle");
        }
        // The payload carries the compositor name too; sync it so the
        // overview/overview-button detection doesn't wait for the
        // separate get-compositor probe.
        if (payload.compositor) {
            YozdService.compositorName = payload.compositor;
        }
        root.compositorLayoutReady = true;
        layoutFetchRetry.running = false;
    }

    function fetchLayoutList() {
        BackendService.call("compositor.dispatch", {args: ["layout", "list"]}, (result, error) => {
            if (error || !result || result.error || result.exit_code !== 0) {
                if (layoutFetchRetry.attempts >= 30) {
                    console.warn("GlobalStates: " + BrandActions.daemon + " layout list failed:", error || (result && result.error));
                    if (!root.compositorLayout) {
                        root.compositorLayout = StateService.get("compositorLayout", "dwindle");
                    }
                    root.compositorLayoutReady = true;
                }
                return;
            }
            try {
                root.applyLayoutList(JSON.parse(result.stdout || ""));
            } catch (e) {
                console.warn("GlobalStates: failed to parse layout list:", e);
                if (!root.compositorLayout) {
                    root.compositorLayout = StateService.get("compositorLayout", "dwindle");
                }
                root.compositorLayoutReady = true;
                layoutFetchRetry.running = false;
            }
        });
    }

    function setCompositorLayout(layout) {
        if (!availableLayouts.includes(layout)) {
            return;
        }
        compositorLayout = layout;
        StateService.set("compositorLayout", layout);
        // Bar selector / keybind cycle: keep the setting in step so the
        // choice survives a restart (compositor.layout wins at startup).
        if (Config.loader.loaded && Config.compositor.layout !== layout)
            Config.compositor.layout = layout;
        BackendService.call("compositor.dispatch", {args: ["layout", "set", layout]}, (result, error) => {
            if (error || !result || result.error || result.exit_code !== 0) {
                console.warn("GlobalStates: " + BrandActions.daemon + " layout set failed (", layout, "):", error || (result && result.error));
            }
        });
    }

    function cycleCompositorLayout() {
        if (availableLayouts.length === 0) {
            return;
        }
        const currentIndex = availableLayouts.indexOf(compositorLayout);
        const nextIndex = (currentIndex + 1) % availableLayouts.length;
        setCompositorLayout(availableLayouts[nextIndex]);
    }


    // Ensure LockscreenService singleton is loaded
    Component.onCompleted: {
        // Reference the singleton to ensure it loads
        LockscreenService.toString();
        // Fetch the active layout from the compositor
        fetchLayoutList();
        layoutFetchRetry.running = true;
    }

    // Persistent launcher state across monitors
    property string launcherSearchText: ""
    property int launcherSelectedIndex: -1
    property int launcherCurrentTab: 0

    function clearLauncherState() {
        launcherSearchText = "";
        launcherSelectedIndex = -1;
    }

    // Persistent dashboard state across monitors  
    property int dashboardCurrentTab: 0
    
    // Widgets tab internal state (for prefix-based tabs)
    // 0=launcher, 1=clipboard, 2=emoji, 3=tmux, 4=wallpapers
    property int widgetsTabCurrentIndex: 0

    // Persistent wallpaper navigation state
    property int wallpaperSelectedIndex: -1

    // Bumped to re-align video wallpapers across screens (seek to 0)
    property int videoSyncTick: 0

    // Per-screen Wallpaper instances (screen name -> instance)
    property var screenWallpapers: ({})

    // Where the user picked the next wallpaper ({ screen, x, y, time } in
    // that screen's coordinates). The "grow" transition expands from here;
    // stale or other-screen origins fall back to the screen centre.
    property var wallpaperTransitionOrigin: null

    function setWallpaperTransitionOrigin(item, x, y, screenName) {
        if (!item)
            return;
        // Scene coordinates == screen coordinates for the full-screen
        // shell panel that hosts the dashboard.
        const p = item.mapToItem(null, x, y);
        wallpaperTransitionOrigin = {
            screen: screenName || "",
            x: p.x,
            y: p.y,
            time: Date.now()
        };
    }

    function wallpaperForScreen(name) {
        return (screenWallpapers && screenWallpapers[name]) || wallpaperManager || null;
    }

    function clearWallpaperState() {
        wallpaperSelectedIndex = -1;
    }

    function getNotchOpen(screenName) {
        let visibilities = Visibilities.getForScreen(screenName);
        return visibilities.launcher || visibilities.dashboard || visibilities.overview || visibilities.presets;
    }

    function getActiveLauncher() {
        let active = Visibilities.getForActive();
        return active ? active.launcher : false;
    }

    function getActiveDashboard() {
        let active = Visibilities.getForActive();
        return active ? active.dashboard : false;
    }

    function getActiveOverview() {
        let active = Visibilities.getForActive();
        return active ? active.overview : false;
    }

    function getActivePresets() {
        let active = Visibilities.getForActive();
        return active ? active.presets : false;
    }

    function getActiveNotchOpen() {
        let active = Visibilities.getForActive();
        return active ? (active.launcher || active.dashboard || active.overview) : false;
    }

    // Legacy properties for backward compatibility - use active screen
    readonly property bool notchOpen: getActiveNotchOpen()
    readonly property bool overviewOpen: getActiveOverview()
    readonly property bool presetsOpen: getActivePresets()
    readonly property bool launcherOpen: getActiveLauncher()
    readonly property bool dashboardOpen: getActiveDashboard()

    // Lockscreen state
    property bool lockscreenVisible: false

    // OSD state
    property bool osdVisible: false
    property string osdIndicator: "volume" // volume, mic, brightness

    // Screenshot Tool state
    property bool screenshotToolVisible: false
    // property string screenshotToolMode: "normal" // DEPRECATED
    property string screenshotCaptureMode: "region" // region, window, screen
    
    // Global selection state for synchronization
    property int screenshotSelectionX: 0
    property int screenshotSelectionY: 0
    property int screenshotSelectionW: 0
    property int screenshotSelectionH: 0

    // Screen Record Tool state
    property bool screenRecordToolVisible: false

    // Mirror Tool state
    property bool mirrorWindowVisible: false

    // Settings Window state
    property bool settingsWindowVisible: false
    property int settingsTargetWorkspaceId: 0
    property string settingsTargetScreenName: ""

    // Theme editor state - persists across tab switches
    property bool themeHasChanges: false
    property var themeSnapshot: null

    // Constants for theme snapshot operations (avoid duplication)
    // Get SR variant names dynamically from Config.theme
    function _getSrVariantNames() {
        var names = [];
        var keys = Object.keys(Config.theme);
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].startsWith("sr")) {
                names.push(keys[i]);
            }
        }
        return names;
    }

    readonly property var _simpleThemeProps: [
        "roundness", "oledMode", "lightMode", "font", "fontSize", "monoFont", "monoFontSize",
        "tintIcons", "enableCorners", "animDuration", "paletteTransitionDuration",
        "shadowOpacity", "shadowColor", "shadowXOffset", "shadowYOffset", "shadowBlur",
        "terminalOpacity", "glass", "surfaceEffect", "surfaceEffectOptions", "density", "shape", "popup", "signatures", "icons", "type"
    ]
    readonly property var _srVariantProps: [
        "gradientType", "gradientAngle", "gradientCenterX", "gradientCenterY",
        "halftoneDotMin", "halftoneDotMax", "halftoneStart", "halftoneEnd",
        "halftoneDotColor", "halftoneBackgroundColor", "itemColor", "opacity", "inheritBg"
    ]

    // Deep copy a single SR variant
    function _copySrVariant(src) {
        var copy = {};
        for (var i = 0; i < _srVariantProps.length; i++) {
            if (src[_srVariantProps[i]] !== undefined) {
                copy[_srVariantProps[i]] = src[_srVariantProps[i]];
            }
        }
        // Deep copy arrays with safety checks
        try {
            copy.gradient = (src.gradient !== undefined) ? JSON.parse(JSON.stringify(src.gradient)) : [];
        } catch (e) {
            console.warn("GlobalStates: Error cloning gradient: " + e);
            copy.gradient = [];
        }
        
        try {
            copy.border = (src.border !== undefined) ? JSON.parse(JSON.stringify(src.border)) : [];
        } catch (e) {
            console.warn("GlobalStates: Error cloning border: " + e);
            copy.border = [];
        }
        
        return copy;
    }

    // Restore a single SR variant from source to destination
    function _restoreSrVariant(src, dest) {
        for (var i = 0; i < _srVariantProps.length; i++) {
            if (src[_srVariantProps[i]] !== undefined) {
                dest[_srVariantProps[i]] = src[_srVariantProps[i]];
            }
        }
        // Deep copy arrays with safety checks
        if (src.gradient !== undefined) {
            try {
                dest.gradient = JSON.parse(JSON.stringify(src.gradient));
            } catch (e) { console.warn("GlobalStates: Error restoring gradient: " + e); }
        }
        
        if (src.border !== undefined) {
            try {
                dest.border = JSON.parse(JSON.stringify(src.border));
            } catch (e) { console.warn("GlobalStates: Error restoring border: " + e); }
        }
    }

    // In-place restore of a nested JsonObject (e.g. theme.glass) from its
    // JSON copy: assigning the plain object would replace the JsonObject.
    function _restoreJsonObject(src, dest) {
        for (var key in src) {
            if (key === "objectName" || dest[key] === undefined)
                continue;
            var v = src[key];
            if (v !== null && typeof v === "object" && !Array.isArray(v) && typeof dest[key] === "object" && dest[key] !== null)
                _restoreJsonObject(v, dest[key]);
            else
                dest[key] = v;
        }
    }

    // Create a deep copy of the current theme config
    function createThemeSnapshot() {
        var snapshot = {};
        var theme = Config.theme;
        var srVariantNames = _getSrVariantNames();

        // Copy simple properties (nested JsonObjects such as glass deep-copied)
        for (var i = 0; i < _simpleThemeProps.length; i++) {
            var prop = _simpleThemeProps[i];
            var val = theme[prop];
            snapshot[prop] = (typeof val === "object" && val !== null) ? JSON.parse(JSON.stringify(val)) : val;
        }

        // Copy SR variants
        for (var j = 0; j < srVariantNames.length; j++) {
            var name = srVariantNames[j];
            snapshot[name] = _copySrVariant(theme[name]);
        }

        return snapshot;
    }

    // Restore theme from snapshot
    function restoreThemeSnapshot(snapshot) {
        if (!snapshot) return;

        var theme = Config.theme;
        var srVariantNames = _getSrVariantNames();

        // Restore simple properties (nested JsonObjects restored in place)
        for (var i = 0; i < _simpleThemeProps.length; i++) {
            var prop = _simpleThemeProps[i];
            var val = snapshot[prop];
            if (typeof val === "object" && val !== null && typeof theme[prop] === "object" && theme[prop] !== null)
                _restoreJsonObject(val, theme[prop]);
            else
                theme[prop] = val;
        }

        // Restore SR variants
        for (var j = 0; j < srVariantNames.length; j++) {
            var name = srVariantNames[j];
            if (snapshot[name]) {
                _restoreSrVariant(snapshot[name], theme[name]);
            }
        }
    }

    function markThemeChanged() {
        // Take a snapshot before the first change
        if (!themeHasChanges) {
            themeSnapshot = createThemeSnapshot();
            Config.pauseAutoSave = true;
        }
        themeHasChanges = true;
    }

    function applyThemeChanges() {
        if (themeHasChanges) {
            Config.loader.writeAdapter();
            themeHasChanges = false;
            themeSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardThemeChanges() {
        if (themeHasChanges && themeSnapshot) {
            restoreThemeSnapshot(themeSnapshot);
            themeHasChanges = false;
            themeSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SHELL SETTINGS STATE
    // ═══════════════════════════════════════════════════════════════
    property bool shellHasChanges: false
    property var shellSnapshot: null

    // Shell config sections and their properties
    readonly property var _shellSections: {
        "bar": ["position", "launcherIcon", "launcherIconTint", "launcherIconFullTint", "launcherIconSize", "enableFirefoxPlayer", "screenList", "frameEnabled", "frameThickness", "pinnedOnStartup", "hoverToReveal", "hoverRegionHeight", "showPinButton", "availableOnFullscreen", "pillStyle", "use12hFormat", "containBar", "keepBarShadow", "keepBarBorder", "clockShowDate", "layout", "compact", "activities", "panels", "moduleOptions"],
        "notch": ["position", "align", "hoverRegionHeight", "keepHidden", "visualizer", "expandOn", "disableHoverExpansion", "noMediaDisplay", "customText", "style", "activities", "osd"],
        "workspaces": ["shown", "showAppIcons", "alwaysShowNumbers", "showNumbers", "dynamic", "numeralStyle", "numeralFont", "indicatorStyle"],
        "overview": ["style", "rows", "columns", "scale", "workspaceSpacing"],
        "dock": ["enabled", "theme", "position", "height", "iconSize", "spacing", "margin", "hoverRegionHeight", "pinnedOnStartup", "hoverToReveal", "availableOnFullscreen", "showRunningIndicators", "showPinButton", "showOverviewButton", "screenList", "keepHidden", "magnification", "magnificationScale", "launchBounce"],
        "lockscreen": ["position", "style", "tone", "blur", "showMedia", "showVisualizer", "showStatus"],
        "desktop": ["enabled", "iconSize", "spacingVertical", "textColor", "wallpaperTransition", "wallpaperTransitionDuration", "wallpaperFolders", "depthClock", "depthClockStyle", "depthClockPosition", "depthClockVideo", "depthClockInk", "blurWallpaperOnOverview", "widgetsEnabled", "widgets", "widgetGrid", "widgetVariant"],
        "system": ["idle", "ocr", "disks", "language", "updateServiceEnabled", "clipboard", "pomodoro", "timers", "focus"],
        "voice": ["enabled", "model", "language", "activation", "useGpu", "maxSeconds", "idleTimeout", "vadAutoStop", "vadSilenceMs", "vadSensitivity", "noSpeechTimeout", "serverVad", "typingMethod", "punctuation", "trailingSpace", "aiAutoSend", "previewMs"]
    }

    // Create a deep copy of the current shell config
    function createShellSnapshot() {
        var snapshot = {};
        var sections = Object.keys(_shellSections);
        for (var i = 0; i < sections.length; i++) {
            var section = sections[i];
            var props = _shellSections[section];
            snapshot[section] = {};
            for (var j = 0; j < props.length; j++) {
                var prop = props[j];
                var val = Config[section][prop];
                // Deep copy arrays or objects
                if (typeof val === 'object' && val !== null) {
                    snapshot[section][prop] = JSON.parse(JSON.stringify(val));
                } else {
                    snapshot[section][prop] = val;
                }
            }
        }
        return snapshot;
    }

    // Restore shell config from snapshot
    function restoreShellSnapshot(snapshot) {
        if (!snapshot) return;
        var sections = Object.keys(_shellSections);
        for (var i = 0; i < sections.length; i++) {
            var section = sections[i];
            var props = _shellSections[section];
            for (var j = 0; j < props.length; j++) {
                var prop = props[j];
                var val = snapshot[section][prop];
                
                // Special handling for system.idle (JsonObject)
                if (section === "system" && prop === "idle" && val) {
                    if (val.general) {
                        var generalProps = ["lock_cmd", "before_sleep_cmd", "after_sleep_cmd"];
                        for (var k = 0; k < generalProps.length; k++) {
                            var gp = generalProps[k];
                            if (val.general[gp] !== undefined) {
                                Config.system.idle.general[gp] = val.general[gp];
                            }
                        }
                    }
                    if (val.listeners) {
                        Config.system.idle.listeners = JSON.parse(JSON.stringify(val.listeners));
                    }
                }
                // Special handling for system.ocr (JsonObject)
                else if (section === "system" && prop === "ocr" && val) {
                    var keys = Object.keys(val);
                    for (var k = 0; k < keys.length; k++) {
                        var key = keys[k];
                        Config.system.ocr[key] = val[key];
                    }
                }
                // Nested JsonObject (e.g. system.clipboard): restore its fields in place
                else if (val && typeof val === 'object' && !Array.isArray(val) && Config[section][prop] && Config[section][prop].objectName !== undefined) {
                    var fields = Object.keys(val);
                    for (var f = 0; f < fields.length; f++)
                        Config[section][prop][fields[f]] = val[fields[f]];
                }
                // Deep copy arrays or objects
                else if (typeof val === 'object' && val !== null) {
                    Config[section][prop] = JSON.parse(JSON.stringify(val));
                } else {
                    Config[section][prop] = val;
                }
            }
        }
    }

    function markShellChanged() {
        // Take a snapshot before the first change
        if (!shellHasChanges) {
            shellSnapshot = createShellSnapshot();
            Config.pauseAutoSave = true;
        }
        shellHasChanges = true;
    }

    function applyShellChanges() {
        if (shellHasChanges) {
            Config.saveBar();
            Config.saveNotch();
            Config.saveWorkspaces();
            Config.saveOverview();
            Config.saveDock();
            Config.saveLockscreen();
            Config.saveDesktop();
            Config.saveSystem();
            Config.saveVoice();
            
            shellHasChanges = false;
            shellSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardShellChanges() {
        if (shellHasChanges && shellSnapshot) {
            restoreShellSnapshot(shellSnapshot);
            shellHasChanges = false;
            shellSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // COMPOSITOR SETTINGS STATE
    // ═══════════════════════════════════════════════════════════════
    property bool compositorHasChanges: false
    property var compositorSnapshot: null

    // Compositor config properties (YozdService)
    readonly property var _compositorProps: [
        "syncBorderWidth", "borderSize",
        "syncRoundness", "rounding",
        "gapsIn", "gapsOut",
        "borderAngle", "inactiveBorderAngle",
        "syncBorderColor", "activeBorderColor", "inactiveBorderColor",
        "shadowEnabled", "syncShadowColor", "syncShadowOpacity",
        "shadowRange", "shadowRenderPower", "shadowScale",
        "shadowOpacity", "shadowSharp", "shadowIgnoreWindow",
        "blurEnabled", "blurSize", "blurPasses", "blurXray",
        "blurNewOptimizations", "blurIgnoreOpacity",
        "blurNoise", "blurContrast", "blurBrightness", "blurVibrancy",
        "blurVibrancyDarkness", "blurSpecial", "blurPopups", "blurPopupsIgnorealpha",
        "blurInputMethods", "blurInputMethodsIgnorealpha",
        "blurExplicitIgnoreAlpha", "blurIgnoreAlphaValue",
        "shadowOffset", "shadowColor", "shadowColorInactive",
        "layout", "smartGaps", "dimInactive", "dimStrength",
        "motionProfile", "motionDurationScale", "motionWorkspaceStyle",
        "motionBorderLoop", "motionBorderLoopSpeed", "motionShell", "motionOverrides",
        "borderPulse"
    ]

    // A JsonObject child (e.g. compositor.borderPulse) is snapshotted as a
    // plain copy of its fields and restored field by field.
    function _isJsonObject(val) {
        return val !== null && typeof val === "object" && !Array.isArray(val) && val.objectName !== undefined;
    }

    // Create a deep copy of the current compositor config
    function createCompositorSnapshot() {
        var snapshot = {};
        for (var i = 0; i < _compositorProps.length; i++) {
            var prop = _compositorProps[i];
            var val = Config.compositor[prop];
            if (_isJsonObject(val)) {
                var fields = JSON.parse(JSON.stringify(val));
                delete fields.objectName;
                snapshot[prop] = {
                    "__fields": fields
                };
            } else if (Array.isArray(val) || (val !== null && typeof val === "object")) {
                snapshot[prop] = JSON.parse(JSON.stringify(val));
            } else {
                snapshot[prop] = val;
            }
        }
        return snapshot;
    }

    // Restore compositor config from snapshot
    function restoreCompositorSnapshot(snapshot) {
        if (!snapshot) return;
        for (var i = 0; i < _compositorProps.length; i++) {
            var prop = _compositorProps[i];
            if (snapshot[prop] !== undefined) {
                var val = snapshot[prop];
                if (val && val.__fields) {
                    for (var f in val.__fields) {
                        if (Config.compositor[prop][f] !== undefined)
                            Config.compositor[prop][f] = val.__fields[f];
                    }
                } else if (Array.isArray(val) || (val !== null && typeof val === "object")) {
                    Config.compositor[prop] = JSON.parse(JSON.stringify(val));
                } else {
                    Config.compositor[prop] = val;
                }
            }
        }
    }

    function markCompositorChanged() {
        // Take a snapshot before the first change
        if (!compositorHasChanges) {
            compositorSnapshot = createCompositorSnapshot();
            Config.pauseAutoSave = true;
        }
        compositorHasChanges = true;
    }

    function applyCompositorChanges() {
        if (compositorHasChanges) {
            Config.saveCompositor();
            compositorHasChanges = false;
            compositorSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardCompositorChanges() {
        if (compositorHasChanges && compositorSnapshot) {
            restoreCompositorSnapshot(compositorSnapshot);
            compositorHasChanges = false;
            compositorSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // ASSISTANT SIDEBAR STATE
    // ═══════════════════════════════════════════════════════════════
    property bool assistantVisible: false
    property bool assistantPinned: Config.ai.sidebarPinnedOnStartup ?? false
    property int assistantWidth: Config.ai.sidebarWidth ?? 400
    property string assistantPosition: Config.ai.sidebarPosition ?? "right"
    property string assistantScreenName: ""

    signal assistantFocusRequested(bool wasAlreadyOpen)

    function toggleAssistant() {
        if (assistantVisible) {
            assistantFocusRequested(true);
        } else {
            assistantVisible = true;
            if (YozdService.focusedMonitor && YozdService.focusedMonitor.name) {
                assistantScreenName = YozdService.focusedMonitor.name;
            } else if (Quickshell.screens.length > 0) {
                assistantScreenName = Quickshell.screens[0].name;
            }
            assistantFocusRequested(false);
        }
    }

    function hideAssistant() {
        assistantVisible = false;
    }

    // AI bar: size (compact | wide | fullscreen, ai.appearance.defaultSize at
    // startup), visible space (assistant | code; Ai persists it) and the
    // notch quick-ask card.
    property bool assistantWide: (Config.ai.appearance?.defaultSize ?? "compact") === "wide"
    property bool assistantFullscreen: (Config.ai.appearance?.defaultSize ?? "compact") === "fullscreen"
    property string aiSpace: "assistant"
    readonly property int assistantEffectiveWidth: assistantWide ? Math.max(assistantWidth, Config.ai.wideWidth ?? 1040) : assistantWidth
    readonly property bool quickAskVisible: Visibilities.currentActiveModule === "aiquick"
    property string quickAskKind: "chat"   // chat | shell
    property var quickAskAttachments: []

    function focusedScreenName() {
        if (YozdService.focusedMonitor && YozdService.focusedMonitor.name)
            return YozdService.focusedMonitor.name;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    function showQuickAsk(kind) {
        quickAskKind = kind || "chat";
        if (!(Config.ai.quickAsk.enabled ?? true)) {
            toggleAssistant();
            return;
        }
        if (Visibilities.currentActiveModule !== "aiquick")
            Visibilities.setActiveModule("aiquick");
    }

    function hideQuickAsk() {
        quickAskAttachments = [];
        if (Visibilities.currentActiveModule === "aiquick")
            Visibilities.setActiveModule("");
    }

    function toggleQuickAsk() {
        if (quickAskVisible)
            hideQuickAsk();
        else
            showQuickAsk("chat");
    }

    // Legacy numeric tab (old SettingsTab order); the settings window maps
    // it to a category and resets it to 0.
    property int settingsCurrentTab: 0
    // Category shown by the settings window (modules/settings/schema/Categories.js)
    property string settingsCategory: "appearance"
}
