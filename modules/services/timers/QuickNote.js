.pragma library

// Quick note capture: one line appended to an "inbox" markdown note of the
// Notes tab (<notes dir>/notes/<id>.md + index.json, format of
// modules/widgets/dashboard/notes/notes_utils.js). Tested in
// tests/quick-note.test.cjs.

function parseIndex(text) {
    try {
        var data = JSON.parse(text || "");
        return {
            "order": Array.isArray(data.order) ? data.order : [],
            "notes": data.notes && typeof data.notes === "object" ? data.notes : {}
        };
    } catch (e) {
        return {
            "order": [],
            "notes": {}
        };
    }
}

// The inbox note of `title` in index text, or a new one.
// Returns {noteId, created, header, indexText}: `header` is the first line
// of a new note ("" when it exists), `indexText` the updated index.
function plan(indexText, title, nowIso, newId) {
    var index = parseIndex(indexText);
    var noteId = "";
    for (var i = 0; i < index.order.length; i++) {
        var meta = index.notes[index.order[i]];
        if (meta && meta.isMarkdown && meta.title === title) {
            noteId = index.order[i];
            break;
        }
    }
    var created = noteId === "";
    if (created) {
        noteId = newId;
        index.order = [noteId].concat(index.order);
        index.notes[noteId] = {
            "title": title,
            "created": nowIso,
            "modified": nowIso,
            "isMarkdown": true
        };
    } else {
        index.notes[noteId].modified = nowIso;
    }
    return {
        "noteId": noteId,
        "created": created,
        "header": created ? "# " + title + "\n\n" : "",
        "indexText": JSON.stringify(index, null, 2)
    };
}

// "- buy milk · 14:05\n"
function line(text, stamp) {
    var t = String(text || "").replace(/\s*\n\s*/g, " ").trim();
    return "- " + t + (stamp ? " · " + stamp : "") + "\n";
}
