import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.bar.workspaces
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config
import qs.modules.desktop
import "WallpaperFolders.js" as WallpaperFolders

PanelWindow {
    id: wallpaper

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: Brand.namespace("wallpaper")
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    property string wallpaperDir: expandTilde(wallpaperConfig.adapter.wallPath)
    // Extra folders (Config.desktop.wallpaperFolders) scanned with wallpaperDir.
    readonly property var extraDirs: WallpaperFolders.extras(wallpaperDir, (Config.desktop.wallpaperFolders || []).map(expandTilde))
    readonly property var scanDirs: WallpaperFolders.effective(wallpaperDir, extraDirs)
    property string fallbackDir: decodeURIComponent(Qt.resolvedUrl("../../../../assets/wallpapers_example").toString().replace("file://", ""))
    property var wallpaperPaths: []
    property var subfolderFilters: []
    property var allSubdirs: []
    property int currentIndex: 0
    property string currentWallpaper: initialLoadCompleted && wallpaperPaths.length > 0 ? wallpaperPaths[currentIndex] : ""
    property bool initialLoadCompleted: false
    property bool usingFallback: false
    property bool _wallpaperDirInitialized: false
    property string currentMatugenScheme: wallpaperConfig.adapter.matugenScheme
    property var perScreenWallpapers: wallpaperConfig.adapter.perScreenWallpapers || {}
    property string effectiveWallpaper: perScreenWallpapers[currentScreenName] || currentWallpaper
    property string currentScreenName: wallpaper.screen ? wallpaper.screen.name : ""
    property alias tintEnabled: wallpaperAdapter.tintEnabled
    property int thumbnailsVersion: 0

    property var activeVideo: null

    // Blurs the wallpaper while niri's native overview is open. The overview
    // backdrop shows this surface (place-within-backdrop), so blurring it here
    // is what the user sees behind scaled workspace previews.
    readonly property bool overviewBlurPossible: YozdService.compositorName === "niri"
    readonly property bool overviewBlurActive: Config.desktop.blurWallpaperOnOverview && overviewBlurPossible && YozdService.overviewOpen

    // Video playback is held while nobody can see it: a fullscreen window
    // on this monitor (same per-monitor check the bar/notch/frame use), or
    // the session lock, which draws its own wallpaper copy on top.
    readonly property var compositorMonitor: YozdService.monitorFor(wallpaper.screen)
    readonly property bool fullscreenActive: CompositorData.monitorHasFullscreen(compositorMonitor)
    readonly property bool videoPaused: GlobalStates.lockscreenVisible || ((Config.performance.pauseWallpaperOnFullscreen ?? true) && fullscreenActive) || coverage.covered
    // ...or windows hiding every wallpaper pixel (tiled with gaps 0, monocle)
    readonly property WallpaperCoverage coverage: WallpaperCoverage {
        screenName: wallpaper.currentScreenName
        monitor: wallpaper.compositorMonitor
        enabled: Config.performance.pauseWallpaperWhenCovered ?? true
    }

    // Shader transition between wallpapers: "grow", "wipe", "dissolve",
    // "fade", "random" or "none".
    readonly property string transitionStyle: Config.desktop.wallpaperTransition ?? "grow"
    readonly property int transitionDuration: Config.desktop.wallpaperTransitionDuration ?? 800

    // Sync state from the primary wallpaper manager to secondary instances
    Binding {
        target: wallpaper
        property: "wallpaperPaths"
        value: GlobalStates.wallpaperManager.wallpaperPaths
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    Binding {
        target: wallpaper
        property: "currentIndex"
        value: GlobalStates.wallpaperManager.currentIndex
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    Binding {
        target: wallpaper
        property: "subfolderFilters"
        value: GlobalStates.wallpaperManager.subfolderFilters
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    Binding {
        target: wallpaper
        property: "initialLoadCompleted"
        value: GlobalStates.wallpaperManager.initialLoadCompleted
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    property alias colorPresetsDir: colorPresetStore.userDir
    property alias officialColorPresetsDir: colorPresetStore.officialDir

    onColorPresetsDirChanged: console.log("Color Presets Directory:", colorPresetsDir)
    property alias colorPresets: colorPresetStore.names
    onColorPresetsChanged: console.log("Color Presets Updated:", colorPresets)
    property string activeColorPreset: wallpaperConfig.adapter.activeColorPreset || ""

    // React to light/dark mode changes
    property bool isLightMode: Config.theme.lightMode
    onIsLightModeChanged: {
        if (activeColorPreset) {
            applyColorPreset();
        } else {
            runMatugenForCurrentWallpaper();
        }
    }

    onActiveColorPresetChanged: {
        if (activeColorPreset) {
            applyColorPreset();
        } else {
            runMatugenForCurrentWallpaper();
        }
    }

    function scanColorPresets() {
        colorPresetStore.scan();
    }

    function applyColorPreset() {
        if (!activeColorPreset)
            return;
        colorPresetStore.apply(activeColorPreset, Config.theme.lightMode);
    }

    function setColorPreset(name) {
        wallpaperConfig.adapter.activeColorPreset = name;
        // activeColorPreset property will update automatically via binding to adapter
    }

    // Funciones utilitarias para tipos de archivo
    function expandTilde(path) {
        if (!path || !path.startsWith("~"))
            return path;
        var home = Quickshell.env("HOME");
        if (path === "~")
            return home;
        if (path.startsWith("~/"))
            return home + path.substring(1);
        return path;
    }

    function getFileType(path) {
        var extension = path.toLowerCase().split('.').pop();
        if (['jpg', 'jpeg', 'png', 'webp', 'tif', 'tiff', 'bmp'].includes(extension)) {
            return 'image';
        } else if (['gif'].includes(extension)) {
            return 'gif';
        } else if (['mp4', 'webm', 'mov', 'avi', 'mkv'].includes(extension)) {
            return 'video';
        }
        return 'unknown';
    }

    function getThumbnailPath(filePath) {
        // QUICKSHELL-GIT: Quickshell.cacheDir instead of ~/.cache/yozakura
        return WallpaperFolders.thumbnailPath(filePath, wallpaperDir, extraDirs, Brand.cacheDir, Qt.md5);
    }

    // Primary wallpaper folder (wallPath in wallpapers.json).
    function setWallpaperDir(path) {
        const dir = WallpaperFolders.normalize(expandTilde(path));
        if (dir && dir !== WallpaperFolders.normalize(wallpaperConfig.adapter.wallPath))
            wallpaperConfig.adapter.wallPath = dir;
    }

    // Reads wallPath from the adapter: when called from its change handler
    // the wallpaperDir/scanDirs bindings may not have updated yet (an empty
    // list would make find scan "." and prune it).
    function rescanWallpapers() {
        const dirs = WallpaperFolders.effective(expandTilde(wallpaperConfig.adapter.wallPath), extraDirs);
        if (dirs.length === 0)
            return;
        scanner.scan(dirs);
    }

    function _watchWallpaperDir(dir) {
        scanner.watch(dir, true);
    }

    function _scheduleThumbnails() {
        cacheJobs.scheduleThumbnails();
    }

    // Rescan + regenerate thumbnails (debounced).
    function refreshFolders() {
        rescanWallpapers();
        cacheJobs.scheduleThumbnails();
    }

    onExtraDirsChanged: {
        if (_wallpaperDirInitialized && GlobalStates.wallpaperManager === wallpaper)
            refreshFolders();
    }

    function getDisplaySource(filePath) {
        var fileType = getFileType(filePath);

        // Para el display (WallpapersTab), siempre usar thumbnails si están disponibles
        if (fileType === 'video' || fileType === 'image' || fileType === 'gif') {
            var thumbnailPath = getThumbnailPath(filePath);
            // Verificar si el thumbnail existe (esto es solo para debugging, QML manejará el fallback)
            return thumbnailPath;
        }

        // Fallback al archivo original si no es un tipo soportado
        return filePath;
    }

    function getColorSource(filePath) {
        var fileType = getFileType(filePath);

        // Para generación de colores: solo videos usan thumbnails
        if (fileType === 'video') {
            return getThumbnailPath(filePath);
        }

        // Imágenes y GIFs usan el archivo original para colores
        return filePath;
    }

    function getLockscreenFramePath(filePath) {
        if (!filePath) {
            return "";
        }

        var fileType = getFileType(filePath);

        // Para imágenes estáticas, usar el archivo original
        if (fileType === 'image') {
            return filePath;
        }

        // Para videos y GIFs, usar el frame cacheado
        if (fileType === 'video' || fileType === 'gif') {
            var fileName = filePath.split('/').pop();
            // QUICKSHELL-GIT: var cachePath = Quickshell.cacheDir + "/lockscreen/" + fileName + ".jpg";
            var cachePath = Brand.cacheDir + "/lockscreen/" + fileName + ".jpg";
            return cachePath;
        }

        return filePath;
    }

    function generateLockscreenFrame(filePath) {
        cacheJobs.generateLockscreenFrame(filePath);
    }

    function getSubfolderFromPath(filePath) {
        var basePath = wallpaperDir.endsWith("/") ? wallpaperDir : wallpaperDir + "/";
        var relativePath = filePath.replace(basePath, "");
        var parts = relativePath.split("/");
        if (parts.length > 1) {
            return parts[0];
        }
        return "";
    }

    function scanSubfolders() {
        if (!wallpaperDir)
            return;
        scanner.scanSubfolders(wallpaperDir);
    }

    // Update directory watcher when wallpaperDir changes
    onWallpaperDirChanged: {
        // Skip initial spurious changes before config is loaded
        if (!_wallpaperDirInitialized)
            return;

        // Only the primary wallpaper manager should handle directory changes
        if (GlobalStates.wallpaperManager !== wallpaper)
            return;

        console.log("Wallpaper directory changed to:", wallpaperDir);
        usingFallback = false;

        // Clear current lists to reflect change immediately
        wallpaperPaths = [];
        subfolderFilters = [];

        scanner.watch(wallpaperDir, false);

        // Force update scan command
        rescanWallpapers();

        scanSubfolders();

        // Regenerate thumbnails for the new directory (delayed)
        cacheJobs.scheduleThumbnails();
    }

    onCurrentWallpaperChanged:
    // Matugen se ejecuta manualmente en las funciones de cambio
    {}

    function setWallpaper(path, targetScreen = null) {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.setWallpaper(path, targetScreen);
            return;
        }

        console.log("setWallpaper called with:", path, "for screen:", targetScreen);
        initialLoadCompleted = true;
        var pathIndex = wallpaperPaths.indexOf(path);
        if (pathIndex !== -1) {
            if (targetScreen) {
                // If targeting a specific screen, save to perScreenWallpapers instead of currentWall
                let perScreen = Object.assign({}, wallpaperConfig.adapter.perScreenWallpapers || {});
                perScreen[targetScreen] = path;
                wallpaperConfig.adapter.perScreenWallpapers = perScreen;

                // If this targetScreen is the primary screen, it must update currentWall
                // because currentWall is exactly the primary monitor fallback.
                let isPrimary = false;
                if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.screen) {
                    isPrimary = (targetScreen === GlobalStates.wallpaperManager.screen.name);
                }

                if (isPrimary || !wallpaperConfig.adapter.currentWall) {
                    currentIndex = pathIndex;
                    wallpaperConfig.adapter.currentWall = path;
                    currentWallpaper = path;
                    runMatugenForCurrentWallpaper();
                }
            } else {
                // Global fallback target
                currentIndex = pathIndex;
                wallpaperConfig.adapter.currentWall = path;
                currentWallpaper = path;
                runMatugenForCurrentWallpaper();
            }
            generateLockscreenFrame(path);
        } else {
            console.warn("Wallpaper path not found in current list:", path);
        }
    }

    function clearPerScreenWallpaper(targetScreen) {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.clearPerScreenWallpaper(targetScreen);
            return;
        }

        console.log("Clearing per-screen wallpaper for:", targetScreen);
        let perScreen = Object.assign({}, wallpaperConfig.adapter.perScreenWallpapers || {});
        if (perScreen[targetScreen]) {
            delete perScreen[targetScreen];
            wallpaperConfig.adapter.perScreenWallpapers = perScreen;
        }
    }

    function nextWallpaper() {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.nextWallpaper();
            return;
        }

        if (wallpaperPaths.length === 0)
            return;
        initialLoadCompleted = true;
        currentIndex = (currentIndex + 1) % wallpaperPaths.length;
        currentWallpaper = wallpaperPaths[currentIndex];
        wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
        runMatugenForCurrentWallpaper();
        generateLockscreenFrame(wallpaperPaths[currentIndex]);
    }

    function previousWallpaper() {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.previousWallpaper();
            return;
        }

        if (wallpaperPaths.length === 0)
            return;
        initialLoadCompleted = true;
        currentIndex = currentIndex === 0 ? wallpaperPaths.length - 1 : currentIndex - 1;
        currentWallpaper = wallpaperPaths[currentIndex];
        wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
        runMatugenForCurrentWallpaper();
        generateLockscreenFrame(wallpaperPaths[currentIndex]);
    }

    function setWallpaperByIndex(index) {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.setWallpaperByIndex(index);
            return;
        }

        if (index >= 0 && index < wallpaperPaths.length) {
            initialLoadCompleted = true;
            currentIndex = index;
            currentWallpaper = wallpaperPaths[currentIndex];
            wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
            runMatugenForCurrentWallpaper();
            generateLockscreenFrame(wallpaperPaths[currentIndex]);
        }
    }

    property bool _schemeSetHere: false

    // A preset applied from outside (`<app> preset apply`) rewrites the
    // scheme in wallpapers.json: regenerate the palette for it.
    Connections {
        target: wallpaperConfig.adapter
        function onMatugenSchemeChanged() {
            if (!wallpaper._schemeSetHere && wallpaper.initialLoadCompleted)
                Qt.callLater(wallpaper.runMatugenForCurrentWallpaper);
        }
    }

    // Función para re-ejecutar Matugen con el wallpaper actual
    function setMatugenScheme(scheme) {
        _schemeSetHere = true;
        wallpaperConfig.adapter.matugenScheme = scheme;
        _schemeSetHere = false;

        if (wallpaperConfig.adapter.activeColorPreset) {
            console.log("Switching to Matugen scheme, clearing preset");
            wallpaperConfig.adapter.activeColorPreset = "";
        } else {
            runMatugenForCurrentWallpaper();
        }
    }

    function runMatugenForCurrentWallpaper() {
        if (activeColorPreset) {
            console.log("Skipping Matugen because color preset is active:", activeColorPreset);
            return;
        }

        if (currentWallpaper && initialLoadCompleted) {
            console.log("Running Matugen for current wallpaper:", currentWallpaper);

            var fileType = getFileType(currentWallpaper);
            var matugenSource = getColorSource(currentWallpaper);

            console.log("Using source for matugen:", matugenSource, "(type:", fileType + ")");

            matugen.run(matugenSource, wallpaperConfig.adapter.matugenScheme, Config.theme.lightMode);
        }
    }

    function requestVideoSync() {
        if (GlobalStates.wallpaperManager !== wallpaper) {
            if (GlobalStates.wallpaperManager) {
                GlobalStates.wallpaperManager.requestVideoSync();
            }
            return;
        }
        GlobalStates.videoSyncTick++;
    }

    Component.onCompleted: {
        if (currentScreenName)
            GlobalStates.screenWallpapers[currentScreenName] = wallpaper;

        // Only the first Wallpaper instance should manage scanning
        // Other instances (for other screens) share the same data via GlobalStates
        if (GlobalStates.wallpaperManager !== null) {
            // Another instance already registered, skip initialization
            _wallpaperDirInitialized = true;
            return;
        }

        GlobalStates.wallpaperManager = wallpaper;

        // Verify wallpapers.json exists, create with fallback if not
        checkWallpapersJson.running = true;

        // Initial scans - color presets are needed for the wallpapers tab SchemeSelector.
        scanColorPresets();
        colorPresetStore.reloadWatchers();
        // Load initial wallpaper config - triggers onWallPathChanged which does the actual scan
        wallpaperConfig.reload();

        // Lockscreen frame generation deferred 5s after boot to reduce peak memory.
        Qt.callLater(function () {
            if (currentWallpaper) {
                lockscreenFrameTimer.start();
            }
        });
    }

    Component.onDestruction: {
        if (currentScreenName && GlobalStates.screenWallpapers[currentScreenName] === wallpaper)
            delete GlobalStates.screenWallpapers[currentScreenName];
    }

    // Deferred lockscreen frame generation to avoid blocking boot
    Timer {
        id: lockscreenFrameTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (currentWallpaper) {
                generateLockscreenFrame(currentWallpaper);
            }
        }
    }

    FileView {
        id: wallpaperConfig
        // QUICKSHELL-GIT: path: Quickshell.cachePath("wallpapers.json")
        path: Brand.cacheDir + "/wallpapers.json"
        watchChanges: true

        onLoaded: {
            if (!wallpaperConfig.adapter.wallPath) {
                console.log("Loaded config but wallPath is empty, using fallback");
                wallpaperConfig.adapter.wallPath = fallbackDir;
            }
        }

        onFileChanged: reload()
        onAdapterUpdated: {
            // Ensure matugenScheme has a default value
            if (!wallpaperConfig.adapter.matugenScheme) {
                wallpaperConfig.adapter.matugenScheme = "scheme-tonal-spot";
            }
            // Update the currentMatugenScheme property to trigger UI updates
            currentMatugenScheme = Qt.binding(function () {
                return wallpaperConfig.adapter.matugenScheme;
            });
            writeAdapter();
        }

        JsonAdapter {
            id: wallpaperAdapter
            property string currentWall: ""
            property string wallPath: ""
            property string matugenScheme: "scheme-tonal-spot"
            property string activeColorPreset: ""
            property bool tintEnabled: false
            property var perScreenWallpapers: ({})

            onActiveColorPresetChanged: {
                if (wallpaperConfig.adapter.activeColorPreset !== wallpaper.activeColorPreset) {
                    wallpaper.activeColorPreset = wallpaperConfig.adapter.activeColorPreset || "";
                }
            }

            onCurrentWallChanged: {
                // Skip during initial load - scanWallpapers handles this
                if (!wallpaper._wallpaperDirInitialized)
                    return;

                // Siempre actualizar si es diferente al actual
                if (currentWall && currentWall !== wallpaper.currentWallpaper) {
                    // If paths are not loaded yet, wait for scanWallpapers to finish
                    if (wallpaper.wallpaperPaths.length === 0) {
                        return;
                    }

                    var pathIndex = wallpaper.wallpaperPaths.indexOf(currentWall);
                    if (pathIndex !== -1) {
                        wallpaper.currentIndex = pathIndex;
                        if (!wallpaper.initialLoadCompleted) {
                            wallpaper.initialLoadCompleted = true;
                        }
                        wallpaper.runMatugenForCurrentWallpaper();
                    } else {
                        console.warn("Saved wallpaper not found in current list:", currentWall);
                    }
                }
            }

            onWallPathChanged: {
                if (wallPath) {
                    var dir = wallpaper.expandTilde(wallPath);
                    console.log("Config wallPath updated:", dir);

                    // Initialize scanning on first valid wallPath load
                    if (!wallpaper._wallpaperDirInitialized && GlobalStates.wallpaperManager === wallpaper) {
                        wallpaper._wallpaperDirInitialized = true;

                        // Set up directory watcher (this is the primary manager)
                        GlobalStates.wallpaperManager._watchWallpaperDir(dir);

                        // Perform initial wallpaper scan
                        GlobalStates.wallpaperManager.rescanWallpapers();
                        wallpaper.scanSubfolders();

                        // Start thumbnail generation
                        GlobalStates.wallpaperManager._scheduleThumbnails();
                    }
                }
            }
        }
    }

    Process {
        id: checkWallpapersJson
        running: false
        // QUICKSHELL-GIT: command: ["test", "-f", Quickshell.cachePath("wallpapers.json")]
        command: ["test", "-f", Brand.cacheDir + "/wallpapers.json"]

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.log("wallpapers.json does not exist, creating with fallbackDir");
                wallpaperConfig.adapter.wallPath = fallbackDir;
            } else {
                console.log("wallpapers.json exists");
            }
        }
    }

    WallpaperColorPresets {
        id: colorPresetStore
    }

    MatugenRunner {
        id: matugen
    }

    WallpaperCacheJobs {
        id: cacheJobs
        fallbackDir: wallpaper.fallbackDir
        extraDirs: wallpaper.extraDirs
        onThumbnailsGenerated: wallpaper.thumbnailsVersion++
    }

    WallpaperScanner {
        id: scanner
        manager: wallpaper
        adapter: wallpaperConfig.adapter
        jobs: cacheJobs
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: "black"
        focus: true

        Keys.onLeftPressed: {
            if (wallpaper.wallpaperPaths.length > 0) {
                wallpaper.previousWallpaper();
            }
        }

        Keys.onRightPressed: {
            if (wallpaper.wallpaperPaths.length > 0) {
                wallpaper.nextWallpaper();
            }
        }

        WallpaperImage {
            id: wallImage
            anchors.fill: parent
            host: wallpaper
            source: wallpaper.effectiveWallpaper
            screenName: wallpaper.currentScreenName
        }
    }
}
