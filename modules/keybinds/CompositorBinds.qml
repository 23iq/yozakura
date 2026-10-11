import QtQuick
import Quickshell.Io
import qs.modules.globals
import qs.modules.services
import "CompositorSupport.js" as Support

// What the running compositor reports about binds: its own binds (conflict
// detection) and, on niri, the shell binds its config left out (shown on
// the row instead of vanishing). hyprctl on Hyprland, yozd elsewhere.
QtObject {
    id: root

    readonly property string compositor: YozdService.compositorName
    // hyprctl-like objects (BindModel.nativeBinds)
    property var nativeList: []
    // {comboId: reason} (CompositorSupport.parseSkipped)
    property var skipped: ({})

    function refresh() {
        const src = Support.nativeSource(root.compositor);
        if (src === "hyprctl" && !hyprctl.running)
            hyprctl.running = true;
        else if (src === "yozd" && !listBinds.running)
            listBinds.running = true;
        if (Support.reportsSkipped(root.compositor) && !skippedBinds.running)
            skippedBinds.running = true;
    }

    property Connections compositorWatch: Connections {
        target: YozdService
        function onCompositorNameChanged() {
            root.refresh();
        }
    }

    property Process hyprctl: Process {
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    root.nativeList = Array.isArray(list) ? list : [];
                } catch (e) {
                    root.nativeList = [];
                }
            }
        }
    }

    property Process listBinds: Process {
        command: Brand.daemonArgs(["config", "list-binds"])
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    root.nativeList = Support.fromListBinds(JSON.parse(text));
                } catch (e) {
                    root.nativeList = [];
                }
            }
        }
    }

    property Process skippedBinds: Process {
        command: Brand.daemonArgs(["config", "skipped-binds"])
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.skipped = Support.parseSkipped(text)
        }
    }
}
