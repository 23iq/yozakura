.pragma library

// Pure helpers of the tmux tab: tmux command lines, output parsers, the
// session list (with its "create" row) and the row geometry shared by the
// list, its highlight and its click-outside overlay.

// Row geometry: a collapsed row, an option row of the expanded menu and
// the menu's fixed entries (Open, Rename, Quit).
var ROW_HEIGHT = 48;
var OPTION_HEIGHT = 36;
var OPTION_COUNT = 3;

function expandedRowHeight() {
    return ROW_HEIGHT + 4 + OPTION_HEIGHT * OPTION_COUNT + 8;
}

// Height of row `index`; only the expanded row grows, and not while a
// rename/delete is in progress (`editing`).
function rowHeight(index, expandedIndex, editing) {
    return index === expandedIndex && !editing ? expandedRowHeight() : ROW_HEIGHT;
}

// Y offset of row `index` within the list content.
function rowY(index, expandedIndex, editing, count) {
    var y = 0;
    for (var i = 0; i < index && i < count; i++)
        y += rowHeight(i, expandedIndex, editing);
    return y;
}

// ---- tmux command lines (argv for Process, shell strings for terminals)

var LIST_SESSIONS = ["tmux", "list-sessions", "-F", "#{session_name}"];

function listWindowsCommand(session) {
    return ["tmux", "list-windows", "-t", session, "-F", "#{window_index}:#{window_name}:#{window_active}"];
}

function listPanesCommand(session) {
    return ["tmux", "list-panes", "-t", session, "-F", "#{pane_index}:#{pane_width}:#{pane_height}:#{pane_top}:#{pane_left}:#{pane_active}:#{pane_current_command}"];
}

function killCommand(session) {
    return ["tmux", "kill-session", "-t", session];
}

function renameCommand(session, newName) {
    return ["tmux", "rename-session", "-t", session, newName];
}

function selectWindowCommand(session, windowIndex) {
    return ["tmux", "select-window", "-t", `${session}:${windowIndex}`];
}

function selectPaneCommand(session, paneIndex) {
    return ["tmux", "select-pane", "-t", `${session}.${paneIndex}`];
}

// Shell lines for TerminalService (run via `sh -c`); session names are data.
function _shq(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

function newSessionShell(session) {
    return session ? "tmux new -s " + _shq(session) : "tmux";
}

function attachShell(session) {
    return "tmux attach-session -t " + _shq(session);
}

// ---- output parsers

function _lines(text) {
    return String(text || "").trim().split('\n');
}

function parseSessions(text) {
    var sessions = [];
    for (var line of _lines(text)) {
        if (line.trim().length > 0) {
            sessions.push({
                name: line.trim(),
                isCreateButton: false,
                icon: "terminal"
            });
        }
    }
    return sessions;
}

function parseWindows(text) {
    var windows = [];
    for (var line of _lines(text)) {
        if (line.trim().length > 0) {
            var parts = line.split(':');
            if (parts.length >= 3) {
                windows.push({
                    index: parts[0],
                    name: parts[1],
                    active: parts[2] === '1'
                });
            }
        }
    }
    return windows;
}

// Panes with their cell geometry; every pane also carries the layout's
// total size (totalWidth/totalHeight) so the preview can scale it.
function parsePanes(text) {
    var panes = [];
    var maxWidth = 0;
    var maxHeight = 0;
    for (var line of _lines(text)) {
        if (line.trim().length > 0) {
            var parts = line.split(':');
            if (parts.length >= 7) {
                var width = parseInt(parts[1]);
                var height = parseInt(parts[2]);
                var top = parseInt(parts[3]);
                var left = parseInt(parts[4]);
                maxWidth = Math.max(maxWidth, left + width);
                maxHeight = Math.max(maxHeight, top + height);
                panes.push({
                    index: parts[0],
                    width: width,
                    height: height,
                    top: top,
                    left: left,
                    active: parts[5] === '1',
                    command: parts[6]
                });
            }
        }
    }
    for (var pane of panes) {
        pane.totalWidth = maxWidth;
        pane.totalHeight = maxHeight;
    }
    return panes;
}

// ---- session list

function isCreateRow(session) {
    return !!(session && (session.isCreateButton || session.isCreateSpecificButton));
}

// Sessions matching `searchText`, led by a "create" row unless a rename or
// delete is in progress: a generic one, or one creating `searchText` when
// no session has exactly that name.
function buildSessionList(sessions, searchText, withCreateRow) {
    var list;
    var createButtonText = "Create new session";
    var isCreateSpecific = false;
    var sessionNameToCreate = "";
    if (searchText.length === 0) {
        list = sessions.slice();
    } else {
        var query = searchText.toLowerCase();
        list = sessions.filter(session => session.name.toLowerCase().includes(query));
        var exactMatch = sessions.find(session => session.name.toLowerCase() === query);
        if (!exactMatch) {
            createButtonText = `Create session "${searchText}"`;
            isCreateSpecific = true;
            sessionNameToCreate = searchText;
        }
    }
    if (withCreateRow) {
        list.unshift({
            name: createButtonText,
            isCreateButton: !isCreateSpecific,
            isCreateSpecificButton: isCreateSpecific,
            sessionNameToCreate: sessionNameToCreate,
            icon: "terminal"
        });
    }
    return list;
}

// ListModel row of a session (the create row is keyed "__create__").
function modelRow(session) {
    return {
        sessionId: isCreateRow(session) ? "__create__" : session.name,
        sessionData: session
    };
}
