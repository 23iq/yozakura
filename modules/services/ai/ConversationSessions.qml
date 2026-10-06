import QtQuick

// Owns live HTTP sessions independently of the view that currently displays them.
QtObject {
    id: root

    property var makeSession: null
    property var sessions: []
    property var active: null
    property int revision: 0
    property var _drafts: ({})
    property var _scrolls: ({})
    property int _serial: 0

    signal selected(var session)

    readonly property var summaries: {
        revision;
        return sessions.filter(s => s.persist !== false).map(s => ({
                    id: s.chatId,
                    title: s.title,
                    mode: s.mode,
                    model: s.engineId,
                    pinned: s.pinned,
                    busy: s.busy,
                    pending: s.pendingApprovals || 0,
                    updated: s.updated || s.created
                }));
    }

    function registerSession(s) {
        sessions = sessions.concat([s]);
        s.changed.connect(() => root.revision++);
        s.busyChanged.connect(() => root.revision++);
        return s;
    }

    function newSession(kind, persist, engineId) {
        const s = makeSession(kind, persist);
        s.chatId = Date.now().toString() + "-" + (++_serial);
        s.engineId = engineId || "";
        registerSession(s);
        active = s;
        selected(s);
        return s;
    }

    function select(id) {
        const s = sessions.find(x => x.chatId === id);
        if (!s)
            return false;
        active = s;
        selected(s);
        return true;
    }

    function open(data) {
        if (!data)
            return;
        if (select(data.id))
            return;
        const s = makeSession(data.mode || "chat", true);
        s.load(data);
        s.engineId = data.model || "";
        registerSession(s);
        active = s;
        selected(s);
    }

    function remove(id) {
        const s = sessions.find(x => x.chatId === id);
        if (s) {
            s.stop();
            sessions = sessions.filter(x => x !== s);
            if (active === s)
                active = null;
            s.destroy();
        }
        const d = Object.assign({}, _drafts);
        delete d[id];
        delete d["chat:" + id];
        _drafts = d;
        const p = Object.assign({}, _scrolls);
        delete p[id];
        delete p["chat:" + id];
        _scrolls = p;
    }

    function draft(key) {
        return _drafts[key] || {
            text: "",
            attachments: []
        };
    }

    function setDraft(key, text, attachments) {
        if (key)
            _drafts = Object.assign({}, _drafts, {
                [key]: {
                    text: text,
                    attachments: (attachments || []).slice()
                }
            });
    }

    function scroll(key) {
        return _scrolls[key] || 0;
    }

    function setScroll(key, y) {
        if (key)
            _scrolls = Object.assign({}, _scrolls, {
                [key]: y
            });
    }
}
