.pragma library
.import "Providers.js" as Providers

// Usage and limits formatting for the AI bar (composer strip, Usage
// screen): token counts, costs ("≈ $0.12"), reset countdowns, which
// subscription window to show and per-day series for sparklines. Pure: the
// data comes from the backend `usage.*` IPC (see UsageService.qml).

function _trim(x) {
    return String(x).replace(/\.0+$/, "").replace(/(\.\d*?)0+$/, "$1");
}

// 950, 1.2k, 12k, 1.2M, 15M.
function tokens(n) {
    n = Math.max(0, Math.round(Number(n) || 0));
    if (n >= 10000000)
        return Math.round(n / 1000000) + "M";
    if (n >= 1000000)
        return _trim((n / 1000000).toFixed(1)) + "M";
    if (n >= 10000)
        return Math.round(n / 1000) + "k";
    if (n >= 1000)
        return _trim((n / 1000).toFixed(1)) + "k";
    return String(n);
}

function _money(v, style, decimals) {
    var s = v.toFixed(decimals);
    return style === "code" ? s + " USD" : "$" + s;
}

// A USD amount. opts: {estimated, style: "symbol"|"code", decimals (2-4)}.
// null/undefined -> "" (unknown); 0 -> "$0"; below the last decimal ->
// "<$0.01"; estimated amounts get "≈ ".
function cost(usd, opts) {
    opts = opts || {};
    if (usd === null || usd === undefined || isNaN(Number(usd)))
        return "";
    usd = Math.max(0, Number(usd));
    var decimals = Math.max(0, Math.min(6, opts.decimals === undefined ? 2 : opts.decimals));
    var style = opts.style || "symbol";
    var min = Math.pow(10, -decimals);
    var text;
    if (usd === 0)
        text = style === "code" ? "0 USD" : "$0";
    else if (usd < min)
        text = "<" + _money(min, style, decimals);
    else
        text = _money(usd, style, decimals);
    return (opts.estimated && usd > 0 ? "≈ " : "") + text;
}

// Cost of a totals record ({costUSD, estimated, unpriced, requests}): "+"
// marks requests whose model has no price. No priced request -> "".
function totalsCost(t, opts) {
    if (!t || !(t.requests > 0))
        return "";
    var priced = (t.requests || 0) - (t.unpriced || 0);
    if (priced <= 0)
        return "";
    var o = Object.assign({}, opts || {}, {
        estimated: !!t.estimated
    });
    return cost(t.costUSD || 0, o) + (t.unpriced > 0 ? "+" : "");
}

// Strip text for a session: "12.4k · ≈ $0.12" (parts can be switched off).
function stripText(t, opts) {
    opts = opts || {};
    if (!t || !(t.requests > 0))
        return "";
    var parts = [];
    if (opts.tokens !== false)
        parts.push(tokens((t.inputTokens || 0) + (t.outputTokens || 0)));
    var c = totalsCost(t, opts);
    if (c && opts.cost !== false)
        parts.push(c);
    return parts.join(" · ");
}

// Countdown: "45m", "2h 10m", "3d 4h", "<1m". units: {d, h, m} suffixes.
function duration(ms, units) {
    units = units || {
        d: "d",
        h: "h",
        m: "m"
    };
    if (!(ms > 0))
        return "";
    var mins = Math.round(ms / 60000);
    if (mins < 1)
        return "<1" + units.m;
    var d = Math.floor(mins / 1440), h = Math.floor((mins % 1440) / 60), m = mins % 60;
    if (d > 0)
        return d + units.d + (h > 0 ? " " + h + units.h : "");
    if (h > 0)
        return h + units.h + (m > 0 ? " " + m + units.m : "");
    return m + units.m;
}

// ms until an RFC3339 time ("" / past -> 0).
function msUntil(iso, now) {
    if (!iso)
        return 0;
    var t = Date.parse(iso);
    if (isNaN(t) || t <= 0)
        return 0;
    return Math.max(0, t - (now === undefined ? Date.now() : now));
}

// Short window label for known ids ("5h", "week" -> translation key).
var WINDOWS = ["5h", "week", "week_opus", "week_sonnet"];
function windowKey(id) {
    return WINDOWS.indexOf(id) >= 0 ? "ai.usage.window." + id : "";
}

function windowOrder(id) {
    var i = WINDOWS.indexOf(id);
    return i >= 0 ? i : WINDOWS.length;
}

// Subscription behind the current engine: Claude Code -> "claude", Codex
// -> "codex"; API keys and local models have none ("").
function subscriptionFor(model) {
    if (!model || model.kind !== "agent")
        return "";
    var id = model.agent || model.model || "";
    return id === "claude" || id === "codex" ? id : "";
}

// "ok" | "warn" | "critical" for a used percentage.
function level(percent, warnAt, criticalAt) {
    if (percent >= (criticalAt || 90))
        return "critical";
    if (percent >= (warnAt || 80))
        return "warn";
    return "ok";
}

// The window to show for provider: `prefer` ("5h"/"week") when present,
// otherwise ("auto") the fullest one. null when there is none.
function pickLimit(limits, provider, prefer) {
    if (!provider)
        return null;
    var entry = null;
    for (var i = 0; i < (limits || []).length; i++)
        if (limits[i] && limits[i].provider === provider)
            entry = limits[i];
    var wins = entry && entry.windows ? entry.windows : [];
    if (wins.length === 0)
        return null;
    var pick = null;
    for (var j = 0; j < wins.length; j++) {
        var w = wins[j];
        if (prefer && prefer !== "auto" && w.id === prefer) {
            pick = w;
            break;
        }
        if (!pick || w.usedPercent > pick.usedPercent || (w.usedPercent === pick.usedPercent && windowOrder(w.id) < windowOrder(pick.id)))
            pick = w;
    }
    return {
        provider: provider,
        id: pick.id,
        percent: Number(pick.usedPercent) || 0,
        fraction: Math.max(0, Math.min(1, (Number(pick.usedPercent) || 0) / 100)),
        resetsAt: pick.resetsAt || ""
    };
}

// Windows of every provider, sorted for the Subscriptions section.
function windows(limits) {
    var out = [];
    (limits || []).forEach(function (l) {
        (l.windows || []).slice().sort(function (a, b) {
            return windowOrder(a.id) - windowOrder(b.id) || (a.id < b.id ? -1 : 1);
        }).forEach(function (w) {
            out.push({
                provider: l.provider,
                source: l.source || "",
                id: w.id,
                percent: Number(w.usedPercent) || 0,
                resetsAt: w.resetsAt || "",
                updatedAt: l.updatedAt || ""
            });
        });
    });
    return out;
}

function _hidden(hidden) {
    var set = {};
    (hidden || []).forEach(function (h) {
        var k = String(h || "").trim().toLowerCase();
        if (k)
            set[k] = true;
    });
    return set;
}

// Drops rows (provider or model rows) of hidden providers.
function visibleRows(rows, hidden) {
    var set = _hidden(hidden);
    return (rows || []).filter(function (r) {
        return !set[String(r.provider || r.key || "").toLowerCase()];
    });
}

function isHidden(provider, hidden) {
    return !!_hidden(hidden)[String(provider || "").toLowerCase()];
}

// Totals of the visible provider rows (the backend totals include hidden
// providers).
function sumRows(rows) {
    var t = {
        requests: 0,
        inputTokens: 0,
        outputTokens: 0,
        cachedTokens: 0,
        costUSD: 0,
        estimated: false,
        unpriced: 0
    };
    (rows || []).forEach(function (r) {
        t.requests += r.requests || 0;
        t.inputTokens += r.inputTokens || 0;
        t.outputTokens += r.outputTokens || 0;
        t.cachedTokens += r.cachedTokens || 0;
        t.costUSD += r.costUSD || 0;
        t.unpriced += r.unpriced || 0;
        t.estimated = t.estimated || !!r.estimated;
    });
    return t;
}

function _dayKey(d) {
    function two(n) {
        return n < 10 ? "0" + n : String(n);
    }
    return d.getFullYear() + "-" + two(d.getMonth() + 1) + "-" + two(d.getDate());
}

// Local day keys from `from` up to today (or `to`, whichever is first).
function days(fromIso, toIso, now) {
    var from = new Date(fromIso), to = new Date(toIso);
    var end = new Date(now === undefined ? Date.now() : now);
    if (isNaN(from.getTime()))
        return [];
    if (!isNaN(to.getTime()) && to.getTime() - 1 < end.getTime())
        end = new Date(to.getTime() - 1);
    var out = [];
    var d = new Date(from.getFullYear(), from.getMonth(), from.getDate());
    while (d.getTime() <= end.getTime() && out.length < 62) {
        out.push(_dayKey(d));
        d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1);
    }
    return out;
}

// Tokens per day of one provider from `provider_day` summary rows.
function series(rows, provider, dayKeys) {
    var by = {};
    (rows || []).forEach(function (r) {
        if (!provider || r.provider === provider)
            by[r.key] = (by[r.key] || 0) + (r.inputTokens || 0) + (r.outputTokens || 0);
    });
    return (dayKeys || []).map(function (k) {
        return by[k] || 0;
    });
}

// Model rows of one provider (from a `model` summary).
function modelsOf(rows, provider) {
    return (rows || []).filter(function (r) {
        return r.provider === provider;
    });
}

// Display name and icon file (assets/aiproviders/) of a ledger provider:
// API providers from Providers.js, CLI agents and subscriptions here.
var AGENTS = {
    claude: {
        label: "Claude Code",
        icon: "anthropic.svg"
    },
    codex: {
        label: "Codex",
        icon: "openai.svg"
    },
    opencode: {
        label: "OpenCode",
        icon: ""
    }
};

function providerLabel(id) {
    if (AGENTS[id])
        return AGENTS[id].label;
    var p = Providers.PROVIDERS[id];
    return p ? p.label : String(id || "");
}

function providerIcon(id) {
    if (AGENTS[id])
        return AGENTS[id].icon;
    var p = Providers.PROVIDERS[id];
    return p ? p.icon : "";
}
