import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

// Saved chats in ~/.local/share/yozakura/chats/<id>.json (v2 objects; v1 arrays
// are still read). Listing goes through `yozakura chatlist --json`.
QtObject {
    id: root

    property string dir: Brand.dataDir + "/chats"
    // [{id, title, pinned, mode, model, updated, preview, count, search}]
    property var chats: []
    property bool loading: lister.running
    property string _readId: ""
    property string _wantedReadId: ""
    property string _pinId: ""
    property var _editFields: ({})
    property var _editQueue: []

    signal loaded(string id, var data)

    function refresh() {
        if (!lister.running)
            lister.running = true;
    }

    function save(data) {
        if (!data || !data.id)
            return;
        writer.path = dir + "/" + data.id + ".json";
        writer.setText(JSON.stringify(data, null, 1));
        refreshTimer.restart();
    }

    function load(id) {
        _wantedReadId = id;
        if (!reader.running)
            _startRead();
    }

    function _startRead() {
        if (reader.running)
            return;
        _readId = _wantedReadId;
        reader.command = ["cat", dir + "/" + _readId + ".json"];
        reader.running = true;
    }

    function remove(id) {
        remover.command = ["rm", "-f", dir + "/" + id + ".json"];
        remover.running = true;
        chats = chats.filter(c => c.id !== id);
    }

    function setPinned(id, pinned) {
        edit(id, {
            pinned: pinned
        });
    }

    function rename(id, title) {
        edit(id, {
            title: title
        });
    }

    function edit(id, fields) {
        _editQueue = _editQueue.concat([
            {
                id: id,
                fields: Object.assign({}, fields)
            }
        ]);
        chats = chats.map(c => c.id === id ? Object.assign({}, c, fields) : c);
        if (!pinner.running)
            _startEdit();
    }

    function _startEdit() {
        if (pinner.running || !_editQueue.length)
            return;
        const edit = _editQueue[0];
        _editQueue = _editQueue.slice(1);
        _editFields = edit.fields;
        _pinId = edit.id;
        pinner.command = ["cat", dir + "/" + _pinId + ".json"];
        pinner.running = true;
    }

    function _parseList(text) {
        const t = text.trim();
        if (t.startsWith("["))
            return JSON.parse(t);
        // Older `ambxst` binaries print "id|title" lines.
        return t.split("\n").filter(l => l.indexOf("|") > 0).map(l => ({
                    id: l.split("|")[0],
                    title: l.split("|").slice(1).join("|"),
                    pinned: false,
                    mode: "chat",
                    updated: 0,
                    preview: "",
                    search: ""
                }));
    }

    property Timer refreshTimer: Timer {
        interval: 400
        onTriggered: root.refresh()
    }

    property Process mkdir: Process {
        running: true
        command: ["mkdir", "-p", root.dir]
    }

    property FileView writer: FileView {
        atomicWrites: true
        blockWrites: true
        printErrors: false
    }

    property Process lister: Process {
        command: [Brand.appId, "chatlist", root.dir, "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.chats = root._parseList(text);
                } catch (e) {
                    console.warn("ChatStore: bad chat list:", e);
                }
            }
        }
    }

    property Process reader: Process {
        onExited: {
            if (root._readId !== root._wantedReadId)
                Qt.callLater(() => root._startRead());
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (root._readId === root._wantedReadId)
                        root.loaded(root._readId, JSON.parse(text));
                } catch (e) {
                    console.warn("ChatStore: cannot load chat", root._readId, e);
                }
            }
        }
    }

    property Process pinner: Process {
        onExited: Qt.callLater(() => root._startEdit())
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text);
                    if (Array.isArray(data))
                        data = {
                            version: 2,
                            id: root._pinId,
                            messages: data
                        };
                    data = Object.assign(data, root._editFields);
                    data.id = root._pinId;
                    root.save(data);
                } catch (e) {
                    console.warn("ChatStore: cannot pin", root._pinId, e);
                }
            }
        }
    }

    property Process remover: Process {
        onExited: root.refresh()
    }
}
