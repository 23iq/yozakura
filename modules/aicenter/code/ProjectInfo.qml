import QtQuick
import Quickshell.Io

// Git branch and agent instructions file (AGENTS.md / CLAUDE.md) of a
// project folder, read with two small argv-only processes when `dir` changes.
QtObject {
    id: root

    property string dir: ""
    property string branch: ""
    property string instructions: ""     // file name found, "" = none

    function refresh() {
        branch = "";
        instructions = "";
        if (!dir)
            return;
        git.command = ["git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD"];
        git.running = true;
        files.command = ["find", dir, "-maxdepth", "1", "(", "-name", "AGENTS.md", "-o", "-name", "CLAUDE.md", ")", "-printf", "%f\\n"];
        files.running = true;
    }

    onDirChanged: refresh()
    Component.onCompleted: refresh()

    readonly property Process git: Process {
        stdout: StdioCollector {
            onStreamFinished: root.branch = text.trim()
        }
    }
    readonly property Process files: Process {
        stdout: StdioCollector {
            // AGENTS.md first: it is the cross-agent convention.
            onStreamFinished: {
                const names = text.split("\n").map(s => s.trim()).filter(Boolean);
                root.instructions = names.indexOf("AGENTS.md") >= 0 ? "AGENTS.md" : (names[0] || "");
            }
        }
    }
}
