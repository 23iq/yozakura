import QtQuick
import Quickshell.Io
import "PrivacyDetect.js" as PrivacyDetect

// Names of processes holding /dev/video* open, for apps that read the
// camera directly instead of through PipeWire (browsers, Zoom...).
// scripts/camera_users.sh is event driven (inotify) and idles when no camera
// exists; nothing runs while `running` is false.
QtObject {
    id: watcher

    property bool running: false
    // Unique process names (comm) currently using a camera
    property var users: []

    readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("../../../scripts/camera_users.sh").toString().replace("file://", ""))

    property var pending: []

    onRunningChanged: if (!running)
        users = []

    property Process proc: Process {
        running: watcher.running
        command: ["sh", watcher.scriptPath]
        stdout: SplitParser {
            onRead: line => {
                if (line === "--") {
                    const block = watcher.pending.join("\n");
                    watcher.pending = [];
                    Qt.callLater(() => {
                        watcher.users = PrivacyDetect.parseCameraUsers(block);
                    });
                } else {
                    watcher.pending.push(line);
                }
            }
        }
    }
}
