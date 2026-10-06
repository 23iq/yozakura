pragma Singleton
import QtQuick
import Quickshell
import qs.config
import "ai/UsageFormat.js" as UsageFormat

// Client of the backend usage service (`usage.*`, backend/pkg/svc/usage):
// the token/cost ledger and the subscription limits. Keeps the current
// limits and per-session totals for the composer strip, records HTTP chat
// requests and pushes the ai.usage settings (Claude limit fetcher,
// notification thresholds) to the backend on every (re)connect.
Singleton {
    id: root

    property bool started: false
    property bool connected: false
    // [{provider, source, updatedAt, windows: [{id, usedPercent, resetsAt}]}]
    property var limits: []
    // sessionId -> totals {requests, inputTokens, outputTokens, costUSD, estimated, unpriced}
    property var sessions: ({})
    // Bumped whenever the ledger changes (new record, cleared).
    property int revision: 0
    // {ledgerDir, pricesOverride, thresholds, claudeLimits}
    property var info: ({})
    // Ticks every 30 s so reset countdowns stay current.
    property double now: Date.now()

    readonly property bool claudeLimits: Config.ai.usage.claudeLimits !== false
    readonly property var thresholds: {
        if (Config.ai.usage.notify === false)
            return [];
        const out = [];
        [Config.ai.usage.warnAt, Config.ai.usage.criticalAt].forEach(t => {
            if (t > 0 && out.indexOf(t) < 0)
                out.push(t);
        });
        return out;
    }

    property int _sub: -1
    property var _asked: ({})

    onClaudeLimitsChanged: if (started)
        _pushClaude()
    onThresholdsChanged: if (started)
        _pushThresholds()

    function start() {
        if (started)
            return;
        started = true;
        _sub = BackendService.addSubscription(["usage"], (service, data) => root._onEvent(service, data));
        _pushSettings();
        refreshInfo();
    }

    function _onEvent(service, data) {
        data = data || {};
        if (service === "usage.limits") {
            connected = true;
            limits = data.limits || [];
            // The snapshot sent right after (re)subscribing has no provider:
            // a restarted backend lost the pushed settings.
            if (!data.provider)
                _pushSettings();
        } else if (service === "usage.updated") {
            const rec = data.record || {};
            if (rec.sessionId && data.session) {
                const next = Object.assign({}, sessions);
                next[rec.sessionId] = data.session;
                sessions = next;
            }
            revision++;
        } else if (service === "usage.cleared") {
            sessions = {};
            _asked = {};
            revision++;
        }
    }

    function _pushSettings() {
        _pushClaude();
        _pushThresholds();
    }
    function _pushClaude() {
        BackendService.call("usage.claudeLimits.enable", {
            enabled: claudeLimits
        }, () => {});
    }
    function _pushThresholds() {
        BackendService.call("usage.alerts.set", {
            thresholds: thresholds
        }, () => {});
    }

    function refreshInfo() {
        BackendService.call("usage.info", {}, (res, err) => {
            if (!err && res)
                root.info = res;
        });
    }

    // Totals of a session (null until known); asks the backend once.
    function sessionTotals(id) {
        if (!id)
            return null;
        if (sessions[id])
            return sessions[id];
        if (!_asked[id]) {
            _asked[id] = true;
            // Deferred: this runs inside bindings.
            Qt.callLater(() => root._fetchSession(id));
        }
        return null;
    }
    function _fetchSession(id) {
        BackendService.call("usage.session", {
            sessionId: id
        }, (res, err) => {
            if (err || !res || !res.totals || root.sessions[id])
                return;
            const next = Object.assign({}, root.sessions);
            next[id] = res.totals;
            root.sessions = next;
        });
    }

    // Current window of a subscription ("claude", "codex") for the strip.
    function limitFor(provider) {
        return UsageFormat.pickLimit(limits, provider, Config.ai.usage.limitWindow || "auto");
    }

    function record(params, cb) {
        BackendService.call("usage.record", params, cb || (() => {}));
    }

    // One finished HTTP request: model is the catalog entry, usage
    // {inputTokens (incl. cached), outputTokens, cachedTokens}; space is
    // what it was for: assistant (chat), code, compaction or automation.
    function recordHttp(model, usage, sessionId, space) {
        if (!model || !usage || !model.provider || model.kind === "agent")
            return;
        const input = Math.max(0, Math.round(usage.inputTokens || 0));
        const output = Math.max(0, Math.round(usage.outputTokens || 0));
        if (input + output <= 0)
            return;
        record({
            provider: model.provider,
            model: model.model || "",
            sessionId: sessionId || "",
            space: space || "assistant",
            engine: "http",
            inputTokens: input,
            outputTokens: output,
            cachedTokens: Math.max(0, Math.round(usage.cachedTokens || 0))
        });
    }

    // range today|week|month, groupBy provider|model|day|provider_day.
    function summary(range, groupBy, cb) {
        BackendService.call("usage.summary", {
            range: range,
            groupBy: groupBy
        }, (res, err) => cb(err ? null : res, err));
    }

    function clear(cb) {
        BackendService.call("usage.clear", {
            confirm: true
        }, (res, err) => {
            if (!err) {
                root.sessions = {};
                root._asked = {};
                root.revision++;
            }
            if (cb)
                cb(!err, err);
        });
    }

    function openPrices() {
        const path = info.pricesOverride || "";
        if (!path)
            return;
        // Create the file with an empty override table on first use.
        Quickshell.execDetached(["sh", "-c", 'f="$1"; [ -e "$f" ] || { mkdir -p "$(dirname "$f")" && printf "%s\\n" "{\\"providers\\": {}}" > "$f"; }; xdg-open "$f"', "sh", path]);
    }

    property Timer _tick: Timer {
        interval: 30000
        running: root.started
        repeat: true
        onTriggered: root.now = Date.now()
    }
}
