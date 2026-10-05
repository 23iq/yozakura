import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

// GET with headers kept out of argv (0600 header file in $XDG_RUNTIME_DIR).
// Create, call get(url, headers, cb(text, ok)); destroys itself when done.
QtObject {
    id: root

    property var callback: null
    readonly property string dir: Brand.runtimeFile("-ai")
    readonly property string headerPath: dir + "/get-" + Math.random().toString(36).slice(2, 10) + ".hdr"
    property string url: ""
    property var headers: []

    function get(url, headers, cb) {
        root.url = url;
        root.headers = headers || [];
        root.callback = cb;
        prepare.running = true;
    }

    property Process prepare: Process {
        command: ["sh", "-c", "umask 077; mkdir -p \"$1\"", "sh", root.dir]
        onExited: {
            root.headerFile.setText(root.headers.join("\n") + "\n");
            root.proc.command = ["curl", "-sS", "--max-time", "8", root.url, "-H", "@" + root.headerPath];
            root.proc.running = true;
        }
    }

    property FileView headerFile: FileView {
        path: root.headerPath
        blockWrites: true
        printErrors: false
    }

    property Process proc: Process {
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            root.cleanup.running = true;
            if (root.callback)
                root.callback(out.text, code === 0);
        }
    }

    property Process cleanup: Process {
        command: ["rm", "-f", root.headerPath]
        onExited: root.destroy()
    }
}
