import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

// Background cache jobs of the wallpaper manager: picker thumbnails
// (`<app> thumbs`, debounced) and the still frame the lock screen shows for
// video/GIF wallpapers (`<app> lockwall`).
Scope {
    id: jobs

    property string fallbackDir: ""
    property var extraDirs: []

    signal thumbnailsGenerated

    // Regenerate thumbnails 2 s after the last request.
    function scheduleThumbnails() {
        if (thumbnailDelay.running)
            thumbnailDelay.restart();
        else
            thumbnailDelay.start();
    }

    function generateLockscreenFrame(filePath) {
        if (!filePath) {
            console.warn("generateLockscreenFrame: empty filePath");
            return;
        }

        console.log("Generating lockscreen frame for:", filePath);

        // QUICKSHELL-GIT: var dataPath = Quickshell.cacheDir;
        var dataPath = Brand.cacheDir;

        lockscreenFrameProcess.command = [Brand.appBin, "lockwall", filePath, dataPath];

        lockscreenFrameProcess.running = true;
    }

    Process {
        id: thumbnailProcess
        running: false
        // Extra folders are appended; older binaries ignore them.
        command: [Brand.appBin, "thumbs", Brand.cacheDir + "/wallpapers.json", Brand.cacheDir, jobs.fallbackDir].concat(jobs.extraDirs)

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Thumbnail Generator:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Thumbnail Generator Error:", text);
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                console.log("✅ Video thumbnails generated successfully");
                jobs.thumbnailsGenerated();
            } else {
                console.warn("⚠️ Thumbnail generation failed with code:", exitCode);
            }
        }
    }

    Timer {
        id: thumbnailDelay
        interval: 2000 // Delay 2 seconds after change to not block
        repeat: false
        onTriggered: thumbnailProcess.running = true
    }

    Process {
        id: lockscreenFrameProcess
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Lockscreen Wallpaper Generator:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Lockscreen Wallpaper Generator Error:", text);
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                console.log("✅ Lockscreen wallpaper ready");
            } else {
                console.warn("⚠️ Lockscreen wallpaper generation failed with code:", exitCode);
            }
        }
    }
}
