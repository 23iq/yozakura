import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.services
import qs.config
import "WallpaperFolders.js" as WallpaperFolders
import "WallpaperDefaults.js" as WallpaperDefaults
import "WallpaperRefs.js" as WallpaperRefs

// The wallpaper manager of a separate window process (ProcessRole:
// settings-window.qml, onboarding-window.qml), which has no wallpaper
// layer. It reads what the main shell's manager (Wallpaper.qml) saves in
// wallpapers.json and lists the library the same way, so pages and
// previews see the real wallpapers and thumbnails; every change (wallpaper,
// folder, scheme, color preset, per-screen choice) is asked of the main
// shell through the daemon (windows.relay "wallpaper.call",
// SeparateWindows.qml runs it on its manager). Nothing here writes
// wallpapers.json, runs matugen or makes thumbnails.
QtObject {
    id: root

    property string wallpaperDir: ""
    property var wallpaperPaths: []
    property var depthMaps: []
    property var subfolderFilters: []
    property string currentWallpaper: ""
    property var perScreenWallpapers: ({})
    property string currentMatugenScheme: WallpaperDefaults.MATUGEN_SCHEME
    property string activeColorPreset: ""
    property bool tintEnabled: false
    property bool usingFallback: false
    property bool initialLoadCompleted: false
    readonly property int currentIndex: Math.max(0, root.wallpaperPaths.indexOf(root.currentWallpaper))
    readonly property string fallbackDir: decodeURIComponent(Qt.resolvedUrl("../../../../assets/wallpapers_example").toString().replace("file://", ""))
    readonly property var extraDirs: WallpaperFolders.extras(root.wallpaperDir, (Config.desktop.wallpaperFolders || []).map(root.expandTilde))
    readonly property var scanDirs: WallpaperFolders.effective(root.wallpaperDir, root.extraDirs)
    readonly property var thumbDirs: WallpaperFolders.thumbFolders(root.wallpaperPaths, root.scanDirs, root.extraDirs, root.fallbackDir)
    readonly property alias colorPresets: presetStore.names

    function expandTilde(path) {
        const home = Quickshell.env("HOME");
        if (!path || !path.startsWith("~"))
            return path;
        return path === "~" ? home : (path.startsWith("~/") ? home + path.substring(1) : path);
    }

    function getFileType(path) {
        const ext = String(path || "").toLowerCase().split(".").pop();
        if (["jpg", "jpeg", "png", "webp", "tif", "tiff", "bmp"].includes(ext))
            return "image";
        if (ext === "gif")
            return "gif";
        if (["mp4", "webm", "mov", "avi", "mkv"].includes(ext))
            return "video";
        return "unknown";
    }

    function getThumbnailPath(filePath) {
        return WallpaperFolders.thumbnailPath(filePath, root.wallpaperDir, root.thumbDirs, Brand.cacheDir, Qt.md5);
    }

    function getDisplaySource(filePath) {
        return root.getFileType(filePath) === "unknown" ? filePath : root.getThumbnailPath(filePath);
    }

    function getColorSource(filePath) {
        return root.getFileType(filePath) === "video" ? root.getThumbnailPath(filePath) : filePath;
    }

    function getLockscreenFramePath(filePath) {
        const type = root.getFileType(filePath);
        if (!filePath || type === "image" || type === "unknown")
            return filePath || "";
        return Brand.cacheDir + "/lockscreen/" + filePath.split("/").pop() + ".jpg";
    }

    // ---- changes: run by the main shell's manager (the methods
    // SeparateWindows.wallpaperMethods allows) ----
    function _ask(method, args) {
        BackendService.call("windows.relay", {
            "to": "shell",
            "topic": "wallpaper.call",
            "data": {
                "method": method,
                "args": args || []
            }
        });
    }

    function setWallpaper(path, targetScreen) {
        root._ask("setWallpaper", targetScreen ? [path, targetScreen] : [path]);
    }
    function setWallpaperDir(path) {
        root._ask("setWallpaperDir", [path]);
    }
    function setMatugenScheme(scheme) {
        root._ask("setMatugenScheme", [scheme]);
    }
    function setColorPreset(name) {
        root._ask("setColorPreset", [name]);
    }
    function clearPerScreenWallpaper(screenName) {
        root._ask("clearPerScreenWallpaper", [screenName]);
    }
    function clearAllPerScreenWallpapers() {
        root._ask("clearAllPerScreenWallpapers", []);
    }
    function nextWallpaper() {
        root._ask("nextWallpaper", []);
    }
    function previousWallpaper() {
        root._ask("previousWallpaper", []);
    }
    function refreshFolders() {
        root.rescan();
    }

    // ---- reading ----
    function rescan() {
        const dirs = root.scanDirs.length > 0 ? root.scanDirs : [root.fallbackDir];
        root._scanned = dirs;
        scan.command = WallpaperFolders.findCommand(dirs.concat([root.fallbackDir]));
        scan.running = true;
    }

    // Same list as the main shell's scanner: the folders' wallpapers, else
    // the bundled ones (WallpaperScanner.qml).
    function applyScan(text) {
        const parts = WallpaperRefs.partition(String(text).trim().split("\n"), root._scanned, root.fallbackDir);
        const found = WallpaperFolders.splitScan(parts.wallpapers);
        root.depthMaps = found.depthMaps;
        root.usingFallback = found.wallpapers.length === 0;
        root.wallpaperPaths = root.usingFallback ? WallpaperFolders.splitScan(parts.bundled).wallpapers : found.wallpapers;
        root.initialLoadCompleted = true;
    }

    function applySaved(text) {
        let data = {};
        try {
            data = JSON.parse(text) || {};
        } catch (e) {
            data = {};
        }
        const bundled = root.fallbackDir;
        const dir = WallpaperFolders.normalize(root.expandTilde(WallpaperFolders.rebaseBundled(data.wallPath || "", bundled))) || bundled;
        root.currentWallpaper = WallpaperRefs.fromStored(data.currentWall || "", bundled);
        root.perScreenWallpapers = WallpaperRefs.mapScreens(data.perScreenWallpapers || {}, bundled, WallpaperRefs.fromStored);
        root.currentMatugenScheme = data.matugenScheme || WallpaperDefaults.MATUGEN_SCHEME;
        root.activeColorPreset = data.activeColorPreset || "";
        root.tintEnabled = data.tintEnabled === true;
        if (dir !== root.wallpaperDir || !root.initialLoadCompleted) {
            root.wallpaperDir = dir;
            Qt.callLater(root.rescan);
        }
    }

    onExtraDirsChanged: {
        if (root.initialLoadCompleted)
            root.rescan();
    }

    // The folders of the scan in flight.
    property var _scanned: []
    property Process scan: Process {
        stdout: StdioCollector {
            onStreamFinished: root.applyScan(text)
        }
    }

    // The main shell writes it; we follow (watchChanges).
    property FileView saved: FileView {
        path: Brand.cacheDir + "/wallpapers.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applySaved(text())
        onLoadFailed: root.applySaved("{}")
    }

    property WallpaperColorPresets presets: WallpaperColorPresets {
        id: presetStore
        Component.onCompleted: {
            presetStore.scan();
            presetStore.reloadWatchers();
        }
    }
}
