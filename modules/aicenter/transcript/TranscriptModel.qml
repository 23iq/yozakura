import QtQuick
import "Transcript.js" as Transcript

// Mirrors a source ListModel (ChatSession.rows or an agent timeline model)
// into `rows`, a flat ListModel of normalised transcript rows. Each source
// item maps to zero or more rows; a change to one item patches only its
// rows (a streamed token updates one row).
QtObject {
    id: root

    property var source: null           // ListModel
    property string kind: "chat"        // chat | agent
    property bool showThinking: true
    // Undo progress by Transcript.undoKey (Ai.undoStates): copied into the
    // rows, so a recycled delegate never offers a finished Undo again.
    property var undoStates: ({})

    readonly property ListModel rows: ListModel {}
    // Normalised rows of each source item (index = source index).
    property var _items: []

    function kindAt(index) {
        return index >= 0 && index < rows.count ? rows.get(index).kind : "";
    }

    function _normalize(i) {
        const list = Transcript.normalize(kind, source.get(i), i, {
            showThinking: showThinking
        });
        for (const r of list)
            if (r.undo)
                r.undoState = undoStates[Transcript.undoKey(r)] || "";
        return list;
    }

    function _applyUndoStates() {
        for (let i = 0; i < rows.count; i++) {
            const r = rows.get(i);
            if (!r.undo)
                continue;
            const state = undoStates[Transcript.undoKey(r)] || "";
            if (r.undoState !== state)
                rows.setProperty(i, "undoState", state);
        }
        for (const list of _items)
            for (const r of list)
                if (r.undo)
                    r.undoState = undoStates[Transcript.undoKey(r)] || "";
    }

    function _offset(i) {
        let n = 0;
        for (let k = 0; k < i && k < _items.length; k++)
            n += _items[k].length;
        return n;
    }

    function _apply(ops) {
        for (const op of ops) {
            if (op.op === "set")
                rows.set(op.index, op.fields);
            else if (op.op === "insert")
                rows.insert(op.index, op.row);
            else
                rows.remove(op.index, op.count);
        }
    }

    // A rebuild of the same conversation (thinking shown / hidden, rows
    // removed or moved) is announced, so a view can keep its place across
    // it (TranscriptView); a new source is a new conversation (no signals).
    signal reshaping
    signal reshaped
    // rows are being refilled (a view waits for the whole list)
    property bool rebuilding: false

    function rebuild(keepPlace) {
        const keep = keepPlace === true;
        if (keep)
            reshaping();
        rebuilding = true;
        rows.clear();
        _items = [];
        const items = [];
        for (let i = 0; source && i < source.count; i++) {
            const list = _normalize(i);
            items.push(list);
            for (const r of list)
                rows.append(r);
        }
        _items = items;
        rebuilding = false;
        if (keep)
            reshaped();
    }

    function _refresh(first, last) {
        for (let i = first; i <= last && i < _items.length; i++) {
            const next = _normalize(i);
            _apply(Transcript.patch(_items[i], next, _offset(i)));
            _items[i] = next;
        }
    }

    function _inserted(first, last) {
        if (first !== _items.length) {
            rebuild(true); // only appends happen in practice
            return;
        }
        for (let i = first; i <= last; i++) {
            const list = _normalize(i);
            _apply(Transcript.patch([], list, _offset(i)));
            _items.push(list);
        }
    }

    onSourceChanged: rebuild()
    onKindChanged: rebuild()
    onShowThinkingChanged: rebuild(true)
    onUndoStatesChanged: _applyUndoStates()

    readonly property Connections _watch: Connections {
        target: root.source
        ignoreUnknownSignals: true
        function onRowsInserted(parent, first, last) {
            root._inserted(first, last);
        }
        function onDataChanged(topLeft, bottomRight) {
            root._refresh(topLeft.row, bottomRight.row);
        }
        function onRowsRemoved() {
            root.rebuild(true);
        }
        function onModelReset() {
            root.rebuild(true);
        }
        function onRowsMoved() {
            root.rebuild(true);
        }
    }
}
