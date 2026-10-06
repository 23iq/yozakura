import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.config
import "../widgets/dashboard/wallpapers/WallpaperFolders.js" as WallpaperFolders

// The wallpaper manager of the dry-run wizard (onboarding-dryrun.qml, no
// wallpaper layer): lists the library like the real one (folder from
// wallpapers.json, extra folders, thumbnails from the cache) so the Look
// step can be clicked through, but picking a wallpaper, folder, scheme or
// color preset only changes this object and is journaled (no matugen, no
// wallpapers.json write).
QtObject {
    id: root

    property string wallpaperDir: ""
    property var wallpaperPaths: []
    property string currentWallpaper: ""
    property string currentMatugenScheme: ""
    property string activeColorPreset: ""
    readonly property string fallbackDir: decodeURIComponent(Qt.resolvedUrl("../../assets/wallpapers_example").toString().replace("file://", ""))
    readonly property var extraDirs: WallpaperFolders.extras(root.wallpaperDir, (Config.desktop.wallpaperFolders || []).map(root.expandTilde))

    function expandTilde(path) {
        const home = Quickshell.env("HOME");
        return path && path.startsWith("~") ? home + path.substring(1) : path;
    }

    function getDisplaySource(filePath) {
        return WallpaperFolders.thumbnailPath(filePath, root.wallpaperDir, root.extraDirs, Brand.cacheDir, Qt.md5) || filePath;
    }

    function setWallpaper(path, targetScreen) {
        DryRun.journal("set wallpaper " + path + (targetScreen ? " on " + targetScreen : ""));
        root.currentWallpaper = path;
    }

    function setWallpaperDir(path) {
        const dir = WallpaperFolders.normalize(root.expandTilde(path));
        if (!dir || dir === root.wallpaperDir)
            return;
        DryRun.journal("set wallpaper folder " + dir);
        root.wallpaperDir = dir;
        root.rescan();
    }

    function setMatugenScheme(scheme) {
        DryRun.journal("set color scheme " + scheme);
        root.currentMatugenScheme = scheme;
    }

    function setColorPreset(name) {
        DryRun.journal("set color preset " + name);
        root.activeColorPreset = name;
    }

    function nextWallpaper() {
    }

    function previousWallpaper() {
    }

    function rescan() {
        scan.command = WallpaperFolders.findCommand(WallpaperFolders.effective(root.wallpaperDir || root.fallbackDir, root.extraDirs));
        scan.running = true;
    }

    property Process scan: Process {
        stdout: StdioCollector {
            onStreamFinished: root.wallpaperPaths = text.trim().split("\n").filter(f => f !== "").sort()
        }
    }

    property FileView saved: FileView {
        path: Brand.cacheDir + "/wallpapers.json"
        printErrors: false
        onLoaded: {
            let data = {};
            try {
                data = JSON.parse(text()) || {};
            } catch (e) {
                data = {};
            }
            root.wallpaperDir = WallpaperFolders.normalize(root.expandTilde(data.wallPath || "")) || root.fallbackDir;
            root.currentWallpaper = data.currentWall || "";
            root.currentMatugenScheme = data.matugenScheme || "scheme-tonal-spot";
            root.activeColorPreset = data.activeColorPreset || "";
            root.rescan();
        }
        onLoadFailed: {
            root.wallpaperDir = root.fallbackDir;
            root.rescan();
        }
    }
}
