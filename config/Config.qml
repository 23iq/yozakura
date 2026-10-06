pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.theme
import qs.modules.services as Services
import qs.config.adapters
import "defaults/theme.js" as ThemeDefaults
import "defaults/bar.js" as BarDefaults
import "defaults/workspaces.js" as WorkspacesDefaults
import "defaults/overview.js" as OverviewDefaults
import "defaults/notch.js" as NotchDefaults
import "defaults/compositor.js" as CompositorDefaults
import "ColorSpec.js" as ColorSpec
import "motion/MotionBudget.js" as MotionBudget
import "motion/MotionProfiles.js" as MotionProfiles
import "defaults/performance.js" as PerformanceDefaults
import "defaults/weather.js" as WeatherDefaults
import "defaults/desktop.js" as DesktopDefaults
import "defaults/lockscreen.js" as LockscreenDefaults
import "defaults/prefix.js" as PrefixDefaults
import "defaults/system.js" as SystemDefaults
import "defaults/dock.js" as DockDefaults
import "defaults/ai.js" as AiDefaults
import "defaults/general.js" as GeneralDefaults
import "defaults/voice.js" as VoiceDefaults
import "defaults/notifications.js" as NotificationsDefaults
import "defaults/layout.js" as LayoutDefaults
import "defaults/specials.js" as SpecialsDefaults
import "defaults/displays.js" as DisplaysDefaults
import "defaults/keyboard.js" as KeyboardDefaults
import "KeyboardMigration.js" as KeyboardMigration
import "defaults/apps.js" as AppsDefaults
import "defaults/terminal.js" as TerminalDefaults

Singleton {
    id: root

    property string version: "0.0.0"

    FileView {
        id: versionFile
        path: Qt.resolvedUrl("../version").toString().replace("file://", "")
        onLoaded: root.version = text().trim()
    }

    property string configDir: Brand.configDir + "/config"
    property string keybindsPath: Brand.configDir + "/binds.json"
    property string presetDir: Qt.resolvedUrl("../assets/presets/" + Brand.displayName + " Default").toString().replace("file://", "")

    property bool pauseAutoSave: false

    // ConfigFile found <name>.json malformed: tell the user where the copy
    // is (backup "" = the copy failed; replaced = defaults now in use).
    function configMalformed(name, backup, replaced) {
        const file = root.configDir + "/" + name + ".json";
        const body = backup ? (replaced ? `${file} was not valid JSON. It was saved as ${backup} and the defaults are used.` : `${file} is not valid JSON. A copy was saved as ${backup}; settings changes are not written until it is fixed.`) : `${file} is not valid JSON and could not be backed up; it was left untouched and settings changes are not written until it is fixed.`;
        Qt.callLater(() => Services.Notifications.notifyInternal({
                summary: "Invalid config file",
                body: body,
                appName: Brand.displayName,
                urgency: "critical"
            }));
    }

    // Module init status
    property bool themeReady: themeLoader.ready
    property bool barReady: barLoader.ready
    property bool workspacesReady: workspacesLoader.ready
    property bool overviewReady: overviewLoader.ready
    property bool notchReady: notchLoader.ready
    property bool compositorReady: compositorLoader.ready
    property bool performanceReady: performanceLoader.ready
    property bool weatherReady: weatherLoader.ready
    property bool desktopReady: desktopLoader.ready
    property bool lockscreenReady: lockscreenLoader.ready
    property bool prefixReady: prefixLoader.ready
    property bool systemReady: systemLoader.ready
    property bool dockReady: dockLoader.ready
    property bool aiReady: aiLoader.ready
    property bool generalReady: generalLoader.ready
    property bool voiceReady: voiceLoader.ready
    property bool notificationsReady: notificationsLoader.ready
    property bool specialsReady: specialsLoader.ready
    property bool displaysReady: displaysLoader.ready
    property bool keyboardReady: keyboardLoader.ready
    property bool appsReady: appsLoader.ready
    property bool terminalReady: terminalLoader.ready
    property bool layoutReady: layoutLoader.ready
    property bool keybindsInitialLoadComplete: keybinds.initialLoadComplete

    property bool initialLoadComplete: themeReady && barReady && workspacesReady && overviewReady && notchReady && compositorReady && performanceReady && weatherReady && desktopReady && lockscreenReady && prefixReady && systemReady && dockReady && aiReady && generalReady && voiceReady && notificationsReady && appsReady && specialsReady && displaysReady && keyboardReady && terminalReady && layoutReady

    // Compatibility aliases
    property alias loader: themeLoader
    property alias keybindsLoader: keybinds.loader

    // ============================================
    // BATCH INITIALIZATION
    // ============================================
    // Ensure config directory exists and copy preset files if missing
    Process {
        id: ensureConfigDir
        running: true
        // $1 preset dir, $2 config dir, then the domain names.
        command: ["sh", "-c", 'src="$1"; dst="$2"; shift 2; mkdir -p "$dst" || exit 0; for f in "$@"; do cp -n "$src/$f.json" "$dst/$f.json" 2>/dev/null; done; echo "Preset files copied if missing"', "seed-config", root.presetDir, root.configDir, "theme", "bar", "workspaces", "overview", "notch", "compositor", "performance", "desktop", "lockscreen", "dock", "ai", "system"]
    }

    // Auto-migrate hyprland.json → compositor.json for existing users
    Process {
        id: migrateCompositorConfig
        running: true
        command: ["sh", "-c", 'd="$1"; if [ -f "$d/hyprland.json" ] && [ ! -f "$d/compositor.json" ]; then mv "$d/hyprland.json" "$d/compositor.json" && echo "Migrated hyprland.json to compositor.json"; fi; exit 0', "migrate-compositor", root.configDir]
    }

    // ============================================
    // CONFIG DOMAINS: <configDir>/<name>.json <-> config/adapters/<Name>Adapter.qml
    // (generated from config/defaults by tools/config/gen_adapters.cjs)
    // ============================================
    ConfigFile {
        id: themeLoader
        store: root
        name: "theme"
        defaults: ThemeDefaults.data
        adapter: ThemeAdapter {}
    }
    ConfigFile {
        id: barLoader
        store: root
        name: "bar"
        defaults: BarDefaults.data
        adapter: BarAdapter {}
    }
    ConfigFile {
        id: workspacesLoader
        store: root
        name: "workspaces"
        defaults: WorkspacesDefaults.data
        adapter: WorkspacesAdapter {}
    }
    ConfigFile {
        id: overviewLoader
        store: root
        name: "overview"
        defaults: OverviewDefaults.data
        adapter: OverviewAdapter {}
    }
    ConfigFile {
        id: notchLoader
        store: root
        name: "notch"
        defaults: NotchDefaults.data
        adapter: NotchAdapter {}
    }
    ConfigFile {
        id: compositorLoader
        store: root
        name: "compositor"
        defaults: CompositorDefaults.data
        adapter: CompositorAdapter {}
    }
    ConfigFile {
        id: performanceLoader
        store: root
        name: "performance"
        defaults: PerformanceDefaults.data
        adapter: PerformanceAdapter {}
    }
    ConfigFile {
        id: weatherLoader
        store: root
        name: "weather"
        defaults: WeatherDefaults.data
        adapter: WeatherAdapter {}
    }
    ConfigFile {
        id: voiceLoader
        store: root
        name: "voice"
        defaults: VoiceDefaults.data
        adapter: VoiceAdapter {}
    }
    ConfigFile {
        id: notificationsLoader
        store: root
        name: "notifications"
        defaults: NotificationsDefaults.data
        adapter: NotificationsAdapter {}
    }
    ConfigFile {
        id: specialsLoader
        store: root
        name: "specials"
        defaults: SpecialsDefaults.data
        adapter: SpecialsAdapter {}
    }
    ConfigFile {
        id: displaysLoader
        store: root
        name: "displays"
        defaults: DisplaysDefaults.data
        adapter: DisplaysAdapter {}
    }
    ConfigFile {
        id: keyboardLoader
        store: root
        name: "keyboard"
        defaults: KeyboardDefaults.data
        onBeforeValidate: root.markKeyboardManagedIfLegacy(keyboardLoader)
        adapter: KeyboardAdapter {}
    }
    ConfigFile {
        id: layoutLoader
        store: root
        name: "layout"
        defaults: LayoutDefaults.data
        adapter: LayoutAdapter {}
    }
    ConfigFile {
        id: terminalLoader
        store: root
        name: "terminal"
        defaults: TerminalDefaults.data
        adapter: TerminalAdapter {}
    }
    ConfigFile {
        id: appsLoader
        store: root
        name: "apps"
        defaults: AppsDefaults.data
        adapter: AppsAdapter {}
    }
    ConfigFile {
        id: desktopLoader
        store: root
        name: "desktop"
        defaults: DesktopDefaults.data
        adapter: DesktopAdapter {}
    }
    ConfigFile {
        id: lockscreenLoader
        store: root
        name: "lockscreen"
        defaults: LockscreenDefaults.data
        adapter: LockscreenAdapter {}
    }
    ConfigFile {
        id: prefixLoader
        store: root
        name: "prefix"
        defaults: PrefixDefaults.data
        adapter: PrefixAdapter {}
    }
    ConfigFile {
        id: systemLoader
        store: root
        name: "system"
        defaults: SystemDefaults.data
        adapter: SystemAdapter {}
    }
    ConfigFile {
        id: dockLoader
        store: root
        name: "dock"
        defaults: DockDefaults.data
        adapter: DockAdapter {}
    }
    ConfigFile {
        id: aiLoader
        store: root
        name: "ai"
        defaults: AiDefaults.data
        adapter: AiAdapter {}
    }
    ConfigFile {
        id: generalLoader
        store: root
        name: "general"
        defaults: GeneralDefaults.data
        onBeforeValidate: root.markOnboardedIfLegacy(generalLoader)
        adapter: GeneralAdapter {}
    }

    // Pinned apps (per-user)
    property bool pinnedAppsReady: false

    FileView {
        id: pinnedAppsLoader
        path: Quickshell.dataPath("pinnedapps.json")
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (!root.pinnedAppsReady) {
                var raw = text();
                // the dry run never writes the real data dir (only config,
                // cache and state are sandboxed)
                if ((!raw || raw.trim().length === 0) && !DryRun.active) {
                    console.log("pinnedapps.json not found, creating with default values...");
                    pinnedAppsLoader.writeAdapter();
                }
                root.pinnedAppsReady = true;
            }
        }
        onFileChanged: {
            root.pauseAutoSave = true;
            reload();
            root.pauseAutoSave = false;
        }
        onPathChanged: reload()
        onAdapterUpdated: {
            if (root.pinnedAppsReady && !root.pauseAutoSave && !DryRun.active) {
                pinnedAppsLoader.writeAdapter();
            }
        }

        adapter: JsonAdapter {
            property list<string> apps: []
        }
    }

    // binds.json (core + custom keybinds)
    KeybindsFile {
        id: keybinds
        store: root
    }

    // general.json written before the onboarding wizard existed belongs to an
    // existing install: mark it onboarded before validation fills in the
    // default (false), so the wizard only auto-shows on fresh installs.
    function markOnboardedIfLegacy(loader) {
        try {
            var raw = loader.text();
            if (!raw || raw.trim().length === 0)
                return;
            var current = JSON.parse(raw);
            if (current && typeof current === "object" && current.onboardingDone === undefined) {
                current.onboardingDone = true;
                loader.setText(JSON.stringify(current, null, 2));
            }
        } catch (e) {}
    }

    // keyboard.json from before keyboard.managed: pure defaults stay
    // unmanaged, anything the user changed stays managed (KeyboardMigration.js).
    function markKeyboardManagedIfLegacy(loader) {
        try {
            var raw = loader.text();
            if (!raw || raw.trim().length === 0)
                return;
            var current = JSON.parse(raw);
            var managed = KeyboardMigration.legacyManaged(current, KeyboardDefaults.data);
            if (managed !== null) {
                current.managed = managed;
                loader.setText(JSON.stringify(current, null, 2));
            }
        } catch (e) {}
    }

    // Exposed properties
    // Theme configuration
    property ThemeAdapter theme: themeLoader.adapter
    property bool oledMode: lightMode ? false : theme.oledMode
    property bool lightMode: theme.lightMode

    property int roundness: theme.roundness
    property string defaultFont: theme.font
    // The motion profile (compositor.motionProfile, config/motion) also sets
    // the shell's animation scale and easing family unless motionShell is off.
    readonly property var motionProfile: MotionProfiles.resolveId(compositor ? compositor.motionProfile : "")
    readonly property bool motionDrivesShell: !!compositor && compositor.motionShell !== false
    // Profile scale alone; the budget caps it before the user's explicit duration scale.
    readonly property real motionProfileScale: !motionDrivesShell ? 1 : (motionProfile.disabled ? 0 : motionProfile.shell.scale)
    readonly property real motionUserScale: motionDrivesShell && compositor.motionDurationScale > 0 ? compositor.motionDurationScale : 1
    property int animDuration: Services.GameModeClient.toggled ? 0 : Math.round(MotionBudget.shellBase(theme.animDuration, motionProfileScale) * motionUserScale)
    // Easing family of the motion profile, for animations that follow it.
    readonly property int animEasing: {
        const name = motionDrivesShell ? motionProfile.shell.easing : "OutCubic";
        const map = {
            "Linear": Easing.Linear,
            "OutCubic": Easing.OutCubic,
            "OutQuart": Easing.OutQuart,
            "OutExpo": Easing.OutExpo,
            "OutBack": Easing.OutBack,
            "InOutSine": Easing.InOutSine,
            "InOutExpo": Easing.InOutExpo
        };
        return map[name] !== undefined ? map[name] : Easing.OutCubic;
    }
    property bool tintIcons: theme.tintIcons

    // Handle lightMode changes
    onLightModeChanged: {
        console.log("lightMode changed to:", lightMode);
        if (GlobalStates.wallpaperManager) {
            var wallpaperManager = GlobalStates.wallpaperManager;
            if (wallpaperManager.currentWallpaper) {
                console.log("Re-running Matugen due to lightMode change");
                wallpaperManager.runMatugenForCurrentWallpaper();
            }
        }
    }

    // Bar configuration
    property BarAdapter bar: barLoader.adapter
    property bool showBackground: theme.srBarBg.opacity > 0

    // Workspace configuration
    property WorkspacesAdapter workspaces: workspacesLoader.adapter

    // Overview configuration
    property OverviewAdapter overview: overviewLoader.adapter

    // Notch configuration
    property NotchAdapter notch: notchLoader.adapter
    property string notchTheme: notch.theme
    property string notchPosition: notch.position

    onNotchPositionChanged: {
        if (!initialLoadComplete || !dockReady)
            return;

        // If notch moves bottom
        if (notchPosition === "bottom") {
            // Conflict with Dock?
            if (dock.position === "bottom") {
                console.log("Notch moved to bottom, adjusting Dock position...");
                // Offset Dock to avoid notch
                if (bar.position === "left") {
                    dock.position = "right";
                } else {
                    dock.position = "left";
                }
                // Trigger save
                GlobalStates.markShellChanged();
            }
        } else
        // If notch moves top
        if (notchPosition === "top") {
            // Restore Dock if displaced
            if (dock.position === "left" || dock.position === "right") {
                console.log("Notch moved to top, restoring Dock to bottom...");
                dock.position = "bottom";
                GlobalStates.markShellChanged();
            }
        }
    }

    // Compositor configuration
    property CompositorAdapter compositor: compositorLoader.adapter
    property int compositorRounding: compositor.syncRoundness ? roundness : compositor.rounding
    property int compositorBorderSize: compositor.syncBorderWidth ? (theme.srBg.border[1] || 0) : compositor.borderSize
    property string compositorBorderColor: compositor.syncBorderColor ? (theme.srBg.border[0] || "primary") : (compositor.activeBorderColor.length > 0 ? compositor.activeBorderColor[0] : "primary")
    property real compositorShadowOpacity: compositor.syncShadowOpacity ? theme.shadowOpacity : compositor.shadowOpacity
    property string compositorShadowColor: compositor.syncShadowColor ? theme.shadowColor : compositor.shadowColor

    // Performance configuration
    property PerformanceAdapter performance: performanceLoader.adapter
    property bool blurTransition: performance.blurTransition

    // Weather configuration
    property WeatherAdapter weather: weatherLoader.adapter

    // Voice input configuration
    property VoiceAdapter voice: voiceLoader.adapter

    // Notifications configuration
    property NotificationsAdapter notifications: notificationsLoader.adapter

    // Special workspaces (global like binds.json; presets never carry them)
    property SpecialsAdapter specials: specialsLoader.adapter

    // Saved monitor layout (machine specific; presets never carry it)
    property DisplaysAdapter displays: displaysLoader.adapter

    // Keyboard layouts, switch bind and key repeat
    property KeyboardAdapter keyboard: keyboardLoader.adapter

    // Where the launcher/dashboard live, dashboard tabs and grid, sheet side, OSD
    property LayoutAdapter layout: layoutLoader.adapter

    // Terminal look: fish prompt, greeting, kitty padding and cursor
    property TerminalAdapter terminal: terminalLoader.adapter

    // External app theming configuration
    property AppsAdapter apps: appsLoader.adapter

    // Desktop configuration
    property DesktopAdapter desktop: desktopLoader.adapter

    // Lockscreen configuration
    property LockscreenAdapter lockscreen: lockscreenLoader.adapter

    // Prefix configuration
    property PrefixAdapter prefix: prefixLoader.adapter

    // System configuration
    property SystemAdapter system: systemLoader.adapter

    // Dock configuration
    property DockAdapter dock: dockLoader.adapter

    // Pinned apps configuration (stored in dataPath)
    property QtObject pinnedApps: pinnedAppsLoader.adapter

    // AI configuration
    property AiAdapter ai: aiLoader.adapter

    // General configuration
    property GeneralAdapter general: generalLoader.adapter

    // Module save functions
    function saveBar() {
        barLoader.writeAdapter();
    }
    function saveWorkspaces() {
        workspacesLoader.writeAdapter();
    }
    function saveOverview() {
        overviewLoader.writeAdapter();
    }
    function saveNotch() {
        notchLoader.writeAdapter();
    }
    function saveCompositor() {
        compositorLoader.writeAdapter();
    }
    function savePerformance() {
        performanceLoader.writeAdapter();
    }
    function saveWeather() {
        weatherLoader.writeAdapter();
    }
    function saveVoice() {
        voiceLoader.writeAdapter();
    }
    function saveNotifications() {
        notificationsLoader.writeAdapter();
    }
    function saveSpecials() {
        specialsLoader.writeAdapter();
    }
    function saveDisplays() {
        displaysLoader.writeAdapter();
    }
    function saveKeyboard() {
        keyboardLoader.writeAdapter();
    }
    function saveLayout() {
        layoutLoader.writeAdapter();
    }
    function saveTerminal() {
        terminalLoader.writeAdapter();
    }
    function saveApps() {
        appsLoader.writeAdapter();
    }
    function saveDesktop() {
        desktopLoader.writeAdapter();
    }
    function saveLockscreen() {
        lockscreenLoader.writeAdapter();
    }
    function savePrefix() {
        prefixLoader.writeAdapter();
    }
    function saveSystem() {
        systemLoader.writeAdapter();
    }
    function saveDock() {
        dockLoader.writeAdapter();
    }
    function savePinnedApps() {
        pinnedAppsLoader.writeAdapter();
    }
    function saveAi() {
        aiLoader.writeAdapter();
    }
    function saveGeneral() {
        generalLoader.writeAdapter();
    }

    // Color helpers
    function isHexColor(colorValue) {
        if (!colorValue || typeof colorValue !== 'string')
            return false;
        const normalized = colorValue.toLowerCase().trim();
        return normalized.startsWith('#') || normalized.startsWith('rgb');
    }

    // Accepts a palette role ("primary"), a literal ("#rrggbb", "rgba(...)")
    // or either with an alpha suffix ("surfaceBright@0.5"). Plain specs
    // resolve exactly as before; a suffix returns a color whose alpha is
    // multiplied by the given factor.
    function resolveColor(colorValue) {
        if (!colorValue)
            return "transparent"; // Fallback

        const spec = ColorSpec.parse(colorValue);
        if (spec.alpha !== null) {
            const base = resolveColor(spec.base);
            const c = (typeof base === 'string') ? Qt.color(base) : base;
            return Qt.rgba(c.r, c.g, c.b, c.a * spec.alpha);
        }

        if (isHexColor(colorValue)) {
            return colorValue;
        }

        // Check Colors singleton
        if (typeof Colors === 'undefined' || !Colors)
            return "transparent";

        return Colors[colorValue] || "transparent";
    }

    function resolveColorWithOpacity(colorValue, opacity) {
        if (!colorValue)
            return Qt.rgba(0, 0, 0, 0);

        const base = ColorSpec.baseOf(colorValue);
        const color = isHexColor(base) ? Qt.color(base) : (Colors[base] || Qt.color("transparent"));
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }
}
