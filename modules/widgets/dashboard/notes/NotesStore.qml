import QtQuick
import Quickshell.Io
import "notes_utils.js" as NotesUtils

// File storage of the notes tab: <notesPath>/<id>.html (rich text) or
// <id>.md (markdown) per note, plus <indexPath> (order + metadata, see
// notes_utils.js). Every operation is an async Process; results come back
// as signals.
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
    // read() finished (content without the parser's trailing newline)
    signal noteRead(bool ok, string content)
    // setTitle() updated the index
    signal titleSaved(string noteId, string title)

    function fileOf(noteId, isMarkdown) {
        return store.notesPath + "/" + noteId + (isMarkdown ? ".md" : store.noteExtension);
    }

    // $1 path, $2 content (argv, never part of the script)
    function writeCommand(path, content) {
        return ["sh", "-c", 'printf "%s" "$2" > "$1"', "notes-write", path, content];
    }

    // Create the directories and index, then load it
    function init() {
        initDirProcess.running = true;
    }

    function refresh() {
        readIndexProcess.running = true;
    }

    function create(title, isMarkdown) {
        var noteId = NotesUtils.generateUUID();
        // Create the note file with appropriate content
        var initialContent = isMarkdown ? "# " + title + "\n\n" : "<h1>" + title + "</h1><p></p>";

        createNoteProcess.noteId = noteId;
        createNoteProcess.noteTitle = title;
        createNoteProcess.noteIsMarkdown = isMarkdown || false;
        createNoteProcess.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$3" > "$2"', "notes-create", store.notesPath, fileOf(noteId, isMarkdown), initialContent];
        createNoteProcess.running = true;
    }

    function remove(noteId, isMarkdown) {
        deleteNoteProcess.deletedNoteId = noteId;
        deleteNoteProcess.command = ["rm", "-f", fileOf(noteId, isMarkdown)];
        deleteNoteProcess.running = true;
    }

    function read(noteId, isMarkdown) {
        readNoteProcess.command = ["cat", fileOf(noteId, isMarkdown)];
        readNoteProcess.running = true;
    }

    function write(noteId, isMarkdown, content) {
        saveNoteProcess.command = writeCommand(fileOf(noteId, isMarkdown), content);
        saveNoteProcess.running = true;
    }

    // Rewrite the index from the notes array (order + metadata)
    function writeIndex(notes) {
        var indexData = {
            order: notes.map(n => n.id),
            notes: {}
        };
        for (var i = 0; i < notes.length; i++) {
            var note = notes[i];
            indexData.notes[note.id] = {
                title: note.title,
                created: note.created,
                modified: note.modified,
                isMarkdown: note.isMarkdown || false
            };
        }
        saveIndexProcess.command = writeCommand(store.indexPath, NotesUtils.serializeIndex(indexData));
        saveIndexProcess.running = true;
    }

    // Read index, update title, save
    function setTitle(noteId, newTitle) {
        readIndexForUpdateProcess.noteId = noteId;
        readIndexForUpdateProcess.newTitle = newTitle;
        readIndexForUpdateProcess.command = ["cat", store.indexPath];
        readIndexForUpdateProcess.running = true;
    }

    // Read index, bump the modified timestamp, save
    function touch(noteId) {
        readIndexForModifiedProcess.noteId = noteId;
        readIndexForModifiedProcess.command = ["cat", store.indexPath];
        readIndexForModifiedProcess.running = true;
    }

    // Initialize directories
    Process {
        id: initDirProcess
        command: ["sh", "-c", 'mkdir -p "$1" && touch "$2"', "notes-init", store.notesPath, store.indexPath]

        onExited: code => {
            store.refresh();
        }
    }

    // Read index.json
    Process {
        id: readIndexProcess
        command: ["cat", store.indexPath]
        stdout: SplitParser {
            onRead: data => readIndexProcess.stdoutData += data + "\n"
        }
        property string stdoutData: ""

        onExited: code => {
            var indexData = NotesUtils.parseIndex(readIndexProcess.stdoutData.trim());
            readIndexProcess.stdoutData = "";

            var loadedNotes = [];
            for (var i = 0; i < indexData.order.length; i++) {
                var noteId = indexData.order[i];
                var noteMeta = indexData.notes[noteId];
                if (noteMeta) {
                    loadedNotes.push({
                        id: noteId,
                        title: noteMeta.title || "Untitled",
                        created: noteMeta.created || "",
                        modified: noteMeta.modified || "",
                        isMarkdown: noteMeta.isMarkdown || false,
                        isCreateButton: false
                    });
                }
            }
            store.indexLoaded(loadedNotes);
        }
    }

    // Create note
    Process {
        id: createNoteProcess
        property string noteId: ""
        property string noteTitle: ""
        property bool noteIsMarkdown: false

        onExited: code => {
            let id = createNoteProcess.noteId;
            let title = createNoteProcess.noteTitle;
            let isMarkdown = createNoteProcess.noteIsMarkdown;
            createNoteProcess.noteId = "";
            createNoteProcess.noteTitle = "";
            createNoteProcess.noteIsMarkdown = false;
            if (code === 0)
                store.noteCreated(id, title, isMarkdown);
        }
    }

    // Delete note
    Process {
        id: deleteNoteProcess
        property string deletedNoteId: ""

        onExited: code => {
            if (code === 0 && deleteNoteProcess.deletedNoteId !== "") {
                let id = deleteNoteProcess.deletedNoteId;
                deleteNoteProcess.deletedNoteId = "";
                store.noteDeleted(id);
            }
        }
    }

    // Read note content
    Process {
        id: readNoteProcess
        stdout: SplitParser {
            onRead: data => readNoteProcess.stdoutData += data + "\n"
        }
        property string stdoutData: ""

        onExited: code => {
            // Remove trailing newline added by parser
            let content = code === 0 ? readNoteProcess.stdoutData.replace(/\n$/, '') : "";
            readNoteProcess.stdoutData = "";
            store.noteRead(code === 0, content);
        }
    }

    // Save note content
    Process {
        id: saveNoteProcess
        onExited: code => {}
    }

    // Save index
    Process {
        id: saveIndexProcess
        onExited: code => {}
    }

    // Read index for title update
    Process {
        id: readIndexForUpdateProcess
        property string noteId: ""
        property string newTitle: ""
        stdout: SplitParser {
            onRead: data => readIndexForUpdateProcess.stdoutData += data + "\n"
        }
        property string stdoutData: ""

        onExited: code => {
            var indexData = NotesUtils.parseIndex(readIndexForUpdateProcess.stdoutData.trim());
            readIndexForUpdateProcess.stdoutData = "";
            let id = readIndexForUpdateProcess.noteId;
            let title = readIndexForUpdateProcess.newTitle;

            if (indexData.notes[id]) {
                indexData.notes[id].title = title;
                indexData.notes[id].modified = NotesUtils.getCurrentTimestamp();
            }

            saveIndexProcess.command = store.writeCommand(store.indexPath, NotesUtils.serializeIndex(indexData));
            saveIndexProcess.running = true;

            readIndexForUpdateProcess.noteId = "";
            readIndexForUpdateProcess.newTitle = "";
            store.titleSaved(id, title);
        }
    }

    // Read index for modified timestamp update
    Process {
        id: readIndexForModifiedProcess
        property string noteId: ""
        stdout: SplitParser {
            onRead: data => readIndexForModifiedProcess.stdoutData += data + "\n"
        }
        property string stdoutData: ""

        onExited: code => {
            var indexData = NotesUtils.parseIndex(readIndexForModifiedProcess.stdoutData.trim());
            readIndexForModifiedProcess.stdoutData = "";

            if (indexData.notes[readIndexForModifiedProcess.noteId]) {
                indexData.notes[readIndexForModifiedProcess.noteId].modified = NotesUtils.getCurrentTimestamp();
            }

            saveIndexProcess.command = store.writeCommand(store.indexPath, NotesUtils.serializeIndex(indexData));
            saveIndexProcess.running = true;
            readIndexForModifiedProcess.noteId = "";
        }
    }
}
