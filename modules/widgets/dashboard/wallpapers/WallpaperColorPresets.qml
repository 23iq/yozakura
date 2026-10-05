import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

// Named colour presets (assets/colors/<name> and <configDir>/colors/<name>,
// each with dark.json + light.json): lists them, watches both folders and
// copies the chosen one over the cached palette.
Scope {
    id: presets

    property string userDir: Brand.configDir + "/colors"
    property string officialDir: decodeURIComponent(Qt.resolvedUrl("../../../../assets/colors").toString().replace("file://", ""))
    property list<string> names: []

    function scan() {
        scanProcess.running = true;
    }

    function reloadWatchers() {
        userWatcher.reload();
        officialWatcher.reload();
    }

    function apply(name, lightMode) {
        var mode = lightMode ? "light.json" : "dark.json";

        var officialFile = presets.officialDir + "/" + name + "/" + mode;
        var userFile = presets.userDir + "/" + name + "/" + mode;
        // QUICKSHELL-GIT: var dest = Quickshell.cachePath("colors.json");
        var dest = Brand.cacheDir + "/colors.json";

        // Official first, then user; preset names are directory names, so
        // the paths go in as positional args.
        console.log("Applying color preset:", name);
        applyProcess.command = ["sh", "-c", 'if [ -f "$1" ]; then cp -- "$1" "$3"; else cp -- "$2" "$3"; fi', "color-preset", officialFile, userFile, dest];
        applyProcess.running = true;
    }

    // Directory watcher for user color presets.
    FileView {
        id: userWatcher
        path: presets.userDir
        watchChanges: true
        printErrors: false

        onFileChanged: {
            console.log("User color presets directory changed, rescanning...");
            scanProcess.running = true;
        }
    }

    // Directory watcher for official color presets.
    FileView {
        id: officialWatcher
        path: presets.officialDir
        watchChanges: true
        printErrors: false

        onFileChanged: {
            console.log("Official color presets directory changed, rescanning...");
            scanProcess.running = true;
        }
    }

    Process {
        id: scanProcess
        running: false
        // Scan both directories. find will complain to stderr if one is missing but still output what it finds.
        command: ["find", presets.officialDir, presets.userDir, "-mindepth", "1", "-maxdepth", "1", "-type", "d"]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("Scan Presets Output:", text);
                var rawLines = text.trim().split("\n");
                var uniqueNames = [];
                for (var i = 0; i < rawLines.length; i++) {
                    var line = rawLines[i].trim();
                    if (line.length === 0)
                        continue;
                    var name = line.split('/').pop();
                    // Deduplicate
                    if (uniqueNames.indexOf(name) === -1) {
                        uniqueNames.push(name);
                    }
                }
                uniqueNames.sort();
                console.log("Found color presets:", uniqueNames);
                presets.names = uniqueNames;
            }
        }

        stderr: StdioCollector {
            onStreamFinished:
            // Suppress common "No such file or directory" if one dir is missing
            {}
        }
    }

    Process {
        id: applyProcess
        running: false
        command: []

        onExited: code => {
            if (code === 0)
                console.log("Color preset applied successfully");
            else
                console.warn("Failed to apply color preset, code:", code);
        }
    }
}
