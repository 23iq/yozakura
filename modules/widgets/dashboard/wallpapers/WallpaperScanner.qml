pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import "WallpaperFolders.js" as WallpaperFolders

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

    function scan(dirs) {
        scanWallpapers.command = WallpaperFolders.findCommand(dirs);
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

    // Selects the saved wallpaper (or the first) after the list changed.
    function selectSaved(verbose) {
        const m = scanner.manager;
        if (scanner.adapter.currentWall) {
            var savedIndex = m.wallpaperPaths.indexOf(scanner.adapter.currentWall);
            if (savedIndex !== -1) {
                m.currentIndex = savedIndex;
                if (verbose)
                    console.log("Loaded saved wallpaper at index:", savedIndex);
            } else {
                m.currentIndex = 0;
                if (verbose)
                    console.log("Saved wallpaper not found, using first");
            }
        } else {
            m.currentIndex = 0;
        }

        if (!m.initialLoadCompleted) {
            if (!scanner.adapter.currentWall) {
                scanner.adapter.currentWall = m.wallpaperPaths[0];
            }
            m.initialLoadCompleted = true;
            // runMatugenForCurrentWallpaper() will be called by onCurrentWallChanged
        }
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
        command: scanner.manager.wallpaperDir ? WallpaperFolders.findCommand(scanner.manager.scanDirs) : []

        onRunningChanged: {
            if (running && scanner.manager.wallpaperDir === "") {
                console.log("Blocking scanWallpapers because wallpaperDir is empty");
                running = false;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const m = scanner.manager;
                var files = text.trim().split("\n").filter(function (f) {
                    return f.length > 0;
                });
                if (files.length === 0) {
                    console.log("No wallpapers found in main directory, using fallback");
                    m.usingFallback = true;
                    scanFallback.running = true;
                } else {
                    m.usingFallback = false;
                    // Only update if the list has actually changed
                    var newFiles = files.sort();
                    var listChanged = JSON.stringify(newFiles) !== JSON.stringify(m.wallpaperPaths);
                    if (listChanged) {
                        console.log("Wallpaper directory updated. Found", newFiles.length, "images");
                        m.wallpaperPaths = newFiles;

                        // Always try to load the saved wallpaper when list changes
                        if (m.wallpaperPaths.length > 0) {
                            // Trigger thumbnail generation if list changed
                            scanner.jobs.scheduleThumbnails();
                            scanner.selectSaved(true);
                        }
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
                var files = text.trim().split("\n").filter(function (f) {
                    return f.length > 0;
                });
                console.log("Using fallback wallpapers. Found", files.length, "images");

                // Only use fallback if we don't already have main wallpapers loaded
                if (m.usingFallback) {
                    m.wallpaperPaths = files.sort();

                    // Initialize fallback wallpaper selection
                    if (m.wallpaperPaths.length > 0)
                        scanner.selectSaved(false);
                }
            }
        }
    }
}
