import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.config

// Keeps the app's SDDM theme in sync with the shell: on palette/theme,
// wallpaper or lock screen style changes, runs scripts/sddm-sync.sh, which
// copies the wallpaper frame, a blurred copy, fonts, the lock screen style
// and the resolved palette into
// /var/lib/<app id>-sddm (created by scripts/install-sddm-theme.sh).
// When the theme is not installed the script exits immediately.
QtObject {
    id: root

    readonly property string scriptPath: Quickshell.shellDir + "/scripts/sddm-sync.sh"
    property bool pending: false

    function generate(Colors) {
        root.debounce.restart();
    }

    function run() {
        // dry run: the login screen theme is left alone
        if (DryRun.active)
            return;
        // Settings > Terminal & Apps can switch the SDDM sync off (apps.theming.sddm).
        if (Config.apps && Config.apps.theming && Config.apps.theming.sddm === false)
            return;
        if (syncProcess.running) {
            pending = true;
            return;
        }
        pending = false;
        syncProcess.command = ["bash", scriptPath, "--quiet"];
        syncProcess.running = true;
    }

    // Wallpaper changes don't always regenerate colors (e.g. fixed color
    // presets), so watch the wallpaper too.
    property Connections wallpaperWatcher: Connections {
        target: GlobalStates.wallpaperManager
        ignoreUnknownSignals: true
        function onCurrentWallpaperChanged() {
            root.debounce.restart();
        }
    }

    // The login screen mirrors the lock screen style and its options.
    property Connections lockscreenWatcher: Connections {
        target: Config.lockscreen
        ignoreUnknownSignals: true
        function onStyleChanged() {
            root.debounce.restart();
        }
        function onToneChanged() {
            root.debounce.restart();
        }
        function onBlurChanged() {
            root.debounce.restart();
        }
        function onPositionChanged() {
            root.debounce.restart();
        }
        function onShowStatusChanged() {
            root.debounce.restart();
        }
    }

    // Coalesce bursts (wallpaper switch -> matugen -> colors.json rewrite).
    property Timer debounce: Timer {
        interval: 2000
        repeat: false
        onTriggered: root.run()
    }

    property Process syncProcess: Process {
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (text)
                    console.warn("SddmGenerator:", text.trim());
            }
        }
        onExited: {
            if (root.pending)
                root.run();
        }
    }
}
