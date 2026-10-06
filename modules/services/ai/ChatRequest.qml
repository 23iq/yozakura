import QtQuick
import Quickshell
import Quickshell.Io
import "Providers.js" as Providers
import qs.modules.globals

// One streaming chat-completion request (curl). Request body and headers go
// to 0600 files in $XDG_RUNTIME_DIR so API keys never appear in argv; a
// custom curl template reads them from $AI_API_KEY / $AI_ENDPOINT /
// $AI_BODY_PATH instead.
// Usage: set model/apiKey/messages/tools/system, call start(); listen to
// delta() and finished().
QtObject {
    id: root

    property var model: null
    property string apiKey: ""
    property var messages: []
    property var tools: []
    property string system: ""
    property string customCurl: ""
    property string effort: ""
    property int numCtx: 0

    readonly property bool running: curl.running
    property bool aborted: false

    readonly property string dir: Brand.runtimeFile("-ai")
    readonly property string reqId: Math.random().toString(36).slice(2, 10)
    readonly property string bodyPath: dir + "/req-" + reqId + ".json"
    readonly property string headerPath: dir + "/req-" + reqId + ".hdr"

    property var _acc: Providers.newAccumulator()
    property string _raw: ""
    property string _error: ""

    signal delta(string text, string thinking)
    signal finished(var result)

    function start() {
        if (!model) {
            finished({
                error: "No model selected"
            });
            return;
        }
        aborted = false;
        _acc = Providers.newAccumulator();
        _raw = "";
        _error = "";
        prepare.running = true;
    }

    function abort() {
        aborted = true;
        if (curl.running)
            curl.signal(15);
        else
            finished({
                aborted: true
            });
    }

    function _launch() {
        if (aborted)
            return;
        const body = Providers.body(messages, model, tools, {
            system: system,
            effort: effort,
            numCtx: numCtx
        });
        bodyFile.setText(JSON.stringify(body));
        const url = Providers.endpoint(model, apiKey);
        if (customCurl) {
            const c = Providers.customCurl(customCurl, {
                endpoint: url,
                apiKey: apiKey,
                bodyPath: bodyPath
            });
            curl.environment = c.env;
            curl.command = ["bash", "-c", c.script];
        } else {
            headerFile.setText(Providers.headers(model, apiKey).join("\n") + "\n");
            curl.command = ["curl", "-sS", "-N", "--no-buffer", "--connect-timeout", "15", "-X", "POST", url, "-H", "@" + headerPath, "--data-binary", "@" + bodyPath];
        }
        curl.running = true;
    }

    property Process prepare: Process {
        command: ["sh", "-c", "umask 077; mkdir -p \"$1\"", "sh", root.dir]
        onExited: root._launch()
    }

    property FileView bodyFile: FileView {
        path: root.bodyPath
        blockWrites: true
        printErrors: false
    }

    property FileView headerFile: FileView {
        path: root.headerPath
        blockWrites: true
        printErrors: false
    }

    property Process curl: Process {
        stdout: SplitParser {
            onRead: line => {
                if (root._raw.length < 65536)
                    root._raw += line + "\n";
                const r = Providers.parse(root.model.provider, line, root._acc);
                if (r.error && !root._error)
                    root._error = r.error;
                if (r.text || r.thinking)
                    root.delta(r.text, r.thinking);
            }
        }
        stderr: StdioCollector {
            id: curlErr
        }
        onExited: code => {
            root.cleanup.running = true;
            let error = root._error;
            const acc = root._acc;
            if (root.aborted)
                error = "";
            else if (!error && code !== 0)
                error = curlErr.text.trim() || ("curl exited with " + code);
            else if (!error && !acc.text && !acc.thinking && acc.calls.length === 0)
                error = Providers.errorFromBody(root._raw) || "Empty response";
            root.finished({
                text: acc.text,
                thinking: acc.thinking,
                signature: acc.signature,
                toolCalls: Providers.finishTools(acc),
                usage: acc.usage,
                error: error,
                aborted: root.aborted
            });
        }
    }

    property Process cleanup: Process {
        command: ["rm", "-f", root.bodyPath, root.headerPath]
    }
}
