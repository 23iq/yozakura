import QtQuick
import Quickshell
import Quickshell.Io

// Runs matugen for a wallpaper: once with the app's template config
// (assets/matugen/config.toml) and once plain, in parallel. A new request
// stops the previous runs.
Scope {
    id: runner

    readonly property string configPath: decodeURIComponent(Qt.resolvedUrl("../../../../assets/matugen/config.toml").toString().replace("file://", ""))

    function run(source, scheme, lightMode) {
        // Stop existing processes if running to prioritize new request
        if (withConfig.running) {
            withConfig.running = false;
        }
        if (normal.running) {
            normal.running = false;
        }

        var commandWithConfig = ["matugen", "image", source, "--source-color-index", "0", "-c", runner.configPath, "-t", scheme];
        if (lightMode) {
            commandWithConfig.push("-m", "light");
        }
        withConfig.command = commandWithConfig;
        withConfig.running = true;

        var commandNormal = ["matugen", "image", source, "--source-color-index", "0", "-t", scheme];
        if (lightMode) {
            commandNormal.push("-m", "light");
        }
        normal.command = commandNormal;
        normal.running = true;
    }

    Process {
        id: withConfig
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Matugen (with config) output:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Matugen (with config) error:", text);
                }
            }
        }

        onExited: {
            console.log("Matugen with config finished");
        }
    }

    Process {
        id: normal
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Matugen (normal) output:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Matugen (normal) error:", text);
                }
            }
        }

        onExited: {
            console.log("Matugen normal finished");
        }
    }
}
