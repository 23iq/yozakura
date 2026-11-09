pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import "WallpaperFolders.js" as WallpaperFolders
import "WallpaperRefs.js" as WallpaperRefs

// Finds the wallpaper files of the primary Wallpaper manager: scans the
// wallpaper folder (+ extra folders, or the bundled examples as fallback),
// lists its subfolders for the picker filters and rescans when any of them
// changes on disk. Results are written to `manager` (wallpaperPaths,
// currentIndex, subfolderFilters, ...) and the saved selection in `adapter`.
Scope {
    id: scanner

    // The owning Wallpaper window and its wallpapers.json JsonAdapter.
    required property var manager
    required property var adapter
    required property WallpaperCacheJobs jobs

    // Files of the bundled example folder, found by every scan: a saved
    // bundled wallpaper stays selectable while the wallpaper folder is
    // another one, and is matched by name after a release renamed it.
    property var bundledPaths: []
    // Folders of the last scan (the bundled folder is scanned with them).
    property var _dirs: []

    function scanCommand(dirs) {
        scanner._dirs = dirs || [];
        const all = WallpaperFolders.effective(scanner._dirs[0] || "", scanner._dirs.slice(1).concat([scanner.manager.fallbackDir]));
        return WallpaperFolders.findCommand(all);
    }

    function scan(dirs) {
        scanWallpapers.command = scanner.scanCommand(dirs);
        scanWallpapers.running = true;
    }

    function scanSubfolders(dir) {
        // Explicitly update command with current wallpaperDir
        var cmd = ["find", "-L", dir, "-mindepth", "1", "-name", ".*", "-prune", "-o", "-type", "d", "-print"];
        scanSubfoldersProcess.command = cmd;
        scanSubfoldersProcess.running = true;
    }

    // Point the directory watcher at the (new) wallpaper folder.
    function watch(dir, reload) {
        directoryWatcher.path = dir;
        if (reload)
            directoryWatcher.reload();
    }

    function rescanOnChange() {
        scanWallpapers.running = true;
        scanSubfoldersProcess.running = true;
        // Regenerar thumbnails si hay nuevos videos (delayed)
        scanner.jobs.scheduleThumbnails();
    }

    // Saved wallpaper (resolved) -> {paths, index, found} for `files`.
    function pick(files) {
        const saved = WallpaperRefs.resolveSaved(scanner.adapter.currentWall, scanner.manager.fallbackDir, scanner.bundledPaths);
        return WallpaperRefs.choose(files, saved, scanner.bundledPaths);
    }

    // Applies a pick() after the list changed: selects the saved wallpaper,
    // or a still image when it is gone (videos only when nothing else).
    function selectSaved(choice, verbose) {
        const m = scanner.manager;
        const a = scanner.adapter;
        if (JSON.stringify(choice.paths) !== JSON.stringify(m.wallpaperPaths))
            m.wallpaperPaths = choice.paths;
        m.currentIndex = Math.max(0, choice.index);
        const chosen = choice.paths[m.currentIndex] || "";
        if (verbose)
            console.log(choice.found ? "Loaded saved wallpaper at index: " + choice.index : (a.currentWall ? "Saved wallpaper not found, using " : "No saved wallpaper, using ") + chosen);
        // A bundled wallpaper found under another name: save the new id.
        const stored = WallpaperRefs.toStored(chosen, m.fallbackDir);
        if (choice.found && stored !== a.currentWall)
            a.currentWall = stored;

        if (!m.initialLoadCompleted) {
            if (!a.currentWall)
                a.currentWall = stored;
            m.initialLoadCompleted = true;
            // runMatugenForCurrentWallpaper() will be called by onCurrentWallChanged
        }
    }

    // The bundled examples stand in for an empty or unreadable folder.
    function useFallback(files) {
        const m = scanner.manager;
        console.log("Using fallback wallpapers. Found", files.length, "images");
        // Only use fallback if we don't already have main wallpapers loaded
        if (m.usingFallback && files.length > 0)
            scanner.selectSaved(scanner.pick(files), false);
    }

    Process {
        id: scanSubfoldersProcess
        running: false
        command: scanner.manager.wallpaperDir ? ["find", "-L", scanner.manager.wallpaperDir, "-mindepth", "1", "-name", ".*", "-prune", "-o", "-type", "d", "-print"] : []

        stdout: StdioCollector {
            onStreamFinished: {
                const m = scanner.manager;
                console.log("scanSubfolders stdout:", text);
                var rawPaths = text.trim().split("\n").filter(function (f) {
                    return f.length > 0;
                });

                m.allSubdirs = rawPaths;

                var basePath = m.wallpaperDir.endsWith("/") ? m.wallpaperDir : m.wallpaperDir + "/";

                var topLevelFolders = rawPaths.filter(function (path) {
                    var relative = path.replace(basePath, "");
                    return relative.indexOf("/") === -1;
                }).map(function (path) {
                    return path.split("/").pop();
                }).filter(function (name) {
                    return name.length > 0 && !name.startsWith(".");
                });

                topLevelFolders.sort();
                m.subfolderFilters = topLevelFolders;
                m.subfolderFiltersChanged();  // Emitir señal manualmente
                console.log("Updated subfolderFilters:", m.subfolderFilters);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Error scanning subfolders:", text);
                }
            }
        }

        onRunningChanged: {
            if (running) {
                console.log("Starting scanSubfolders for directory:", scanner.manager.wallpaperDir);
            } else {
                console.log("Finished scanSubfolders");
            }
        }
    }

    // Directory watcher using FileView to monitor the wallpaper directory
    FileView {
        id: directoryWatcher
        path: scanner.manager.wallpaperDir
        watchChanges: true
        printErrors: false

        onFileChanged: {
            if (scanner.manager.wallpaperDir === "")
                return;
            console.log("Wallpaper directory changed, rescanning...");
            scanner.rescanOnChange();
        }
    }

    // Recursive directory watchers for subfolders
    Instantiator {
        model: scanner.manager.allSubdirs

        delegate: FileView {
            required property string modelData
            path: modelData
            watchChanges: true
            printErrors: false
            onFileChanged: {
                console.log("Subdirectory content changed (" + modelData + "), rescanning...");
                scanner.rescanOnChange();
            }
        }
    }

    // Extra wallpaper folders
    Instantiator {
        model: GlobalStates.wallpaperManager === scanner.manager ? scanner.manager.extraDirs : []

        delegate: FileView {
            required property string modelData
            path: modelData
            watchChanges: true
            printErrors: false
            onFileChanged: GlobalStates.wallpaperManager.refreshFolders()
        }
    }

    Process {
        id: scanWallpapers
        running: false
        command: scanner.manager.wallpaperDir ? scanner.scanCommand(scanner.manager.scanDirs) : []

        onRunningChanged: {
            if (running && scanner.manager.wallpaperDir === "") {
                console.log("Blocking scanWallpapers because wallpaperDir is empty");
                running = false;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const m = scanner.manager;
                const parts = WallpaperRefs.partition(text.trim().split("\n"), scanner._dirs.length > 0 ? scanner._dirs : m.scanDirs, m.fallbackDir);
                scanner.bundledPaths = WallpaperFolders.splitScan(parts.bundled).wallpapers;
                var scan = WallpaperFolders.splitScan(parts.wallpapers);
                var files = scan.wallpapers;
                if (JSON.stringify(scan.depthMaps) !== JSON.stringify(m.depthMaps))
                    m.depthMaps = scan.depthMaps;
                if (files.length === 0) {
                    console.log("No wallpapers found in main directory, using fallback");
                    m.usingFallback = true;
                    if (scanner.bundledPaths.length > 0)
                        scanner.useFallback(scanner.bundledPaths);
                    else
                        scanFallback.running = true;
                } else {
                    m.usingFallback = false;
                    // Only update if the list has actually changed
                    const choice = scanner.pick(files);
                    if (JSON.stringify(choice.paths) !== JSON.stringify(m.wallpaperPaths)) {
                        console.log("Wallpaper directory updated. Found", files.length, "images");
                        // Trigger thumbnail generation if list changed
                        scanner.jobs.scheduleThumbnails();
                        scanner.selectSaved(choice, true);
                    }
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const m = scanner.manager;
                if (text.length > 0) {
                    console.warn("Error scanning wallpaper directory:", text);
                    // Only fallback if we don't already have wallpapers loaded AND we have a valid directory that failed
                    if (m.wallpaperPaths.length === 0 && m.wallpaperDir !== "") {
                        console.log("Directory scan failed for " + m.wallpaperDir + ", using fallback");
                        m.usingFallback = true;
                        scanFallback.running = true;
                    }
                }
            }
        }
    }

    Process {
        id: scanFallback
        running: false
        command: WallpaperFolders.findCommand([scanner.manager.fallbackDir])

        stdout: StdioCollector {
            onStreamFinished: {
                const m = scanner.manager;
                var files = WallpaperFolders.splitScan(text.trim().split("\n")).wallpapers;
                scanner.bundledPaths = files;
                scanner.useFallback(files);
            }
        }
    }
}
