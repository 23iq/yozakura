pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
import "timers/QuickNote.js" as QuickNoteModel

// Quick note capture (bind "quick-note", the notch hub in note mode):
// appends one line to an inbox markdown note of the Notes tab
// (system.timers.noteTitle, created with its index entry when missing).
// Files are written through argv, never through a script built from data.
Singleton {
    id: root

    readonly property string notesDir: Brand.dataDir + "-notes"
    readonly property string indexPath: root.notesDir + "/index.json"
    readonly property string notesPath: root.notesDir + "/notes"
    readonly property string title: (Config.system && Config.system.timers && Config.system.timers.noteTitle) || I18n.t("quicknote.inbox")

    // A line was saved (true) or failed (false)
    signal saved(bool ok, string text)

    property var queue: []
    property bool busy: false

    function add(text) {
        const t = String(text || "").trim();
        if (t === "")
            return false;
        root.queue = root.queue.concat([t]);
        root.next();
        return true;
    }

    function next() {
        if (root.busy || root.queue.length === 0)
            return;
        root.busy = true;
        readIndex.command = ["sh", "-c", 'cat -- "$1" 2>/dev/null || true', "quicknote-index", root.indexPath];
        readIndex.running = true;
    }

    function stamp() {
        const d = new Date();
        return Qt.formatDateTime(d, "dd.MM HH:mm");
    }

    function uuid() {
        return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
            const r = Math.random() * 16 | 0;
            return (c === "x" ? r : (r & 0x3 | 0x8)).toString(16);
        });
    }

    property Process readIndex: Process {
        id: readIndex
        stdout: StdioCollector {
            onStreamFinished: {
                const entry = root.queue[0];
                const plan = QuickNoteModel.plan(text, root.title, new Date().toISOString(), root.uuid());
                writeNote.lineText = entry;
                // $1 dir, $2 note file, $3 header (new note), $4 line, $5 index, $6 index text
                writeNote.command = ["sh", "-c", 'mkdir -p -- "$1" && { [ -z "$3" ] || printf "%s" "$3" > "$2"; } && printf "%s" "$4" >> "$2" && printf "%s" "$6" > "$5"', "quicknote-write", root.notesPath, root.notesPath + "/" + plan.noteId + ".md", plan.header, QuickNoteModel.line(entry, root.stamp()), root.indexPath, plan.indexText];
                writeNote.running = true;
            }
        }
    }

    property Process writeNote: Process {
        id: writeNote
        property string lineText: ""
        onExited: code => {
            root.queue = root.queue.slice(1);
            root.busy = false;
            root.saved(code === 0, writeNote.lineText);
            root.next();
        }
    }
}
