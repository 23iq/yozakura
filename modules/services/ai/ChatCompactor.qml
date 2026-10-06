import QtQuick
import "Compaction.js" as Compaction

// Runs one compaction of an HTTP chat: asks `model` to summarise the rows
// Compaction.plan() picked and inserts the summary row into the session.
// run(session, model, apiKey, customCurl, keepTurns, cb(ok, error, aborted)).
QtObject {
    id: root

    property bool running: false
    property var _request: null

    readonly property Component requestFactory: Component {
        ChatRequest {}
    }

    function run(session, model, apiKey, customCurl, keepTurns, cb) {
        const done = cb || (() => {});
        if (running || !session || session.busy || !model) {
            done(false, "");
            return;
        }
        const rows = [];
        for (let i = 0; i < session.rows.count; i++)
            rows.push(session.rows.get(i));
        const p = Compaction.plan(rows, keepTurns);
        if (!p) {
            done(false, "");
            return;
        }
        running = true;
        session.compacting = true;
        const req = requestFactory.createObject(root, {
            model: model,
            apiKey: apiKey || "",
            customCurl: customCurl || "",
            system: Compaction.PROMPT,
            messages: Compaction.request(rows, p),
            tools: [],
            usageSession: session.chatId || "",
            usageSpace: "compaction"
        });
        _request = req;
        req.finished.connect(result => {
            _request = null;
            req.destroy();
            running = false;
            session.compacting = false;
            const text = String(result.text || "").trim();
            if (result.error || result.aborted || !text) {
                done(false, result.error || "", !!result.aborted);
                return;
            }
            session.insertSummary(p.cut, text);
            done(true, "");
        });
        req.start();
    }

    function abort() {
        if (_request)
            _request.abort();
    }
}
