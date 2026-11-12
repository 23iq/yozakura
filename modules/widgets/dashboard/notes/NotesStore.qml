import QtQuick
import Quickshell.Io
import "notes_utils.js" as NotesUtils

// File storage of the notes tab: <notesPath>/<id>.html (rich text) or
// <id>.md (markdown) per note, plus <indexPath> (order + metadata, see
// notes_utils.js). Reads, deletes and directory setup are async processes,
// one per request (a request never replaces another one); results come back
// as signals. Files are written through `writer`: atomically (a temp file
// renamed over the old one, so a kill mid-write never leaves an empty note
// or index), in order, and never through argv (a long note does not fit).
Item {
    id: store

    required property string notesPath
    required property string indexPath
    required property string noteExtension

    // Index loaded (refresh): [{ id, title, created, modified, isMarkdown, isCreateButton }]
    signal indexLoaded(var notes)
    // Note file written by create()
    signal noteCreated(string noteId, string title, bool isMarkdown)
    // Note file removed by remove()
    signal noteDeleted(string noteId)
    // The latest read() finished (content without the parser's trailing
    // newline); an older read still running is never reported
    signal noteRead(string noteId, bool ok, string content)
    // setTitle() updated the index
    signal titleSaved(string noteId, string title)

    property int _readSeq: 0
    property string _readingId: ""
    // Pending index changes: [{ apply: index => index | null, done }]
    property var _indexQueue: []
    property bool _indexBusy: false
    property bool _writeFailed: false

    function fileOf(noteId, isMarkdown) {
        return store.notesPath + "/" + noteId + (isMarkdown ? ".md" : store.noteExtension);
    }

    // Create the directories and index, then load it
    function init() {
        store.run(["sh", "-c", 'mkdir -p "$1" && touch "$2"', "notes-init", store.notesPath, store.indexPath], code => store.refresh());
    }

    function refresh() {
        store.run(["cat", store.indexPath], (code, out) => {
            store.indexLoaded(NotesUtils.indexEntries(NotesUtils.parseIndex(out.trim())));
        });
    }

    function create(title, isMarkdown) {
        const noteId = NotesUtils.generateUUID();
        const markdown = isMarkdown || false;
        const initialContent = markdown ? "# " + title + "\n\n" : "<h1>" + title + "</h1><p></p>";
        store.run(["mkdir", "-p", store.notesPath], code => {
            if (code === 0 && store.writeFile(store.fileOf(noteId, markdown), initialContent))
                store.noteCreated(noteId, title, markdown);
        });
    }

    function remove(noteId, isMarkdown) {
        store.run(["rm", "-f", store.fileOf(noteId, isMarkdown)], code => {
            if (code === 0)
                store.noteDeleted(noteId);
        });
    }

    function read(noteId, isMarkdown) {
        // Already being read: that result comes (a second one would land
        // after the first and replace what was typed in between)
        if (store._readingId === noteId)
            return;
        const seq = ++store._readSeq;
        store._readingId = noteId;
        store.run(["cat", store.fileOf(noteId, isMarkdown)], (code, out) => {
            if (seq !== store._readSeq)
                return;
            store._readingId = "";
            // Remove trailing newline added by parser
            store.noteRead(noteId, code === 0, code === 0 ? out.replace(/\n$/, '') : "");
        });
    }

    // Returns whether the note was saved
    function write(noteId, isMarkdown, content) {
        return store.writeFile(store.fileOf(noteId, isMarkdown), content);
    }

    // Rewrite the index from the notes array (order + metadata), keeping the
    // notes added to it elsewhere unless listed in `removedIds`
    function writeIndex(notes, removedIds) {
        const snapshot = notes.map(n => ({
                    "id": n.id,
                    "title": n.title,
                    "created": n.created,
                    "modified": n.modified,
                    "isMarkdown": n.isMarkdown || false
                }));
        store.updateIndex(index => NotesUtils.mergeIndex(index, snapshot, removedIds), null);
    }

    // Update the title in the index (+ modified)
    function setTitle(noteId, newTitle) {
        store.updateIndex(index => NotesUtils.updateNote(index, noteId, {
                "title": newTitle
            }), () => store.titleSaved(noteId, newTitle));
    }

    // Bump the modified timestamp in the index
    function touch(noteId) {
        store.updateIndex(index => NotesUtils.updateNote(index, noteId, {}), null);
    }

    // Read the index from disk, apply `apply` (null: nothing to write),
    // write it back. One at a time, queued: no change is lost and the notes
    // other writers added are read before each rewrite.
    function updateIndex(apply, done) {
        store._indexQueue.push({
            "apply": apply,
            "done": done
        });
        store._nextIndexUpdate();
    }

    function _nextIndexUpdate() {
        if (store._indexBusy || store._indexQueue.length === 0)
            return;
        store._indexBusy = true;
        store.run(["cat", store.indexPath], (code, out) => {
            // An unreadable index (null) is only replaced by writeIndex
            let index = NotesUtils.parseIndexStrict(code === 0 ? out.trim() : "");
            let changed = false;
            const batch = store._indexQueue.splice(0);
            batch.forEach(req => {
                const next = req.apply(index);
                if (next) {
                    index = next;
                    changed = true;
                }
            });
            if (changed)
                store.writeFile(store.indexPath, NotesUtils.serializeIndex(index));
            batch.forEach(req => {
                if (req.done)
                    req.done();
            });
            store._indexBusy = false;
            store._nextIndexUpdate();
        });
    }

    // Write a file (atomic, blocking); returns false (and logs) on failure.
    // FileView.setText() skips a write equal to the data it holds, so it
    // first reads what the file holds now (not the previous file's data, nor
    // a version from before another writer changed it).
    function writeFile(path, text) {
        store._writeFailed = false;
        writer.path = path;
        writer.reload();
        writer.text();
        writer.setText(text);
        return !store._writeFailed;
    }

    // `command` in its own process; done(exitCode, stdout)
    function run(command, done) {
        const proc = oneShot.createObject(store, {
            "command": command,
            "done": done
        });
        proc.running = true;
    }

    FileView {
        id: writer
        // Only the blocking read of writeFile(), no background one per path
        preload: false
        blockAllReads: true
        atomicWrites: true
        blockWrites: true
        printErrors: false
        onSaveFailed: error => {
            store._writeFailed = true;
            console.warn("Notes: could not write", writer.path, error);
        }
    }

    Component {
        id: oneShot

        Process {
            id: proc

            property var done: null
            property string out: ""

            stdout: SplitParser {
                onRead: data => proc.out += data + "\n"
            }

            onExited: code => {
                const done = proc.done;
                proc.done = null;
                if (done)
                    done(code, proc.out);
                proc.destroy();
            }
        }
    }
}
