.pragma library
.import "DryRunMethods.js" as Methods

// Dry-run backend (`<app> onboarding --dry-run`, DryRun singleton): the
// answers BackendService gives to every call DryRunMethods.js does not let
// through, and the fake events that follow (display keep/revert countdown,
// install progress). Reads go to the real daemon; overlay() makes their
// answers agree with what was faked (an app "installed" here stays
// installed when the real detection says missing). Pure: time is passed in
// (ms), delayed events wait in state.queue until due() hands them out.

var SESSION_SECONDS = 15;
var INSTALL_MS = 4000;
var INSTALL_STEP_MS = 500;

function isMutating(method, params) {
    return Methods.isMutating(method, params);
}

function readParams(method, params) {
    return Methods.readParams(method, params);
}

function create(failIds) {
    return {
        "nextId": 1,
        "queue": [],
        "outputs": [],
        "status": null,
        "installed": {},
        "loginShell": "",
        "exclusive": null,
        // job id -> {kind, entries} of every fake job
        "jobs": {},
        "fail": failIds || []
    };
}

function hasPending(state) {
    return state.queue.length > 0;
}

function _id(state, kind) {
    return "dryrun-" + kind + "-" + (state.nextId++);
}

function _at(state, at, tag, service, data, line) {
    state.queue.push({
        "at": at,
        "tag": tag,
        "service": service,
        "data": data,
        "line": line || null
    });
}

function _drop(state, tag) {
    state.queue = state.queue.filter(function (e) {
        return e.tag !== tag;
    });
}

function _session(id, st, remaining) {
    return {
        "session": id,
        "state": st,
        "remaining": remaining,
        "live": true
    };
}

// One fake job: queued now, progress every INSTALL_STEP_MS, done (or failed
// with reason "network") after INSTALL_MS. Returns the job ref.
function _job(state, kind, entries, label, now, onDone) {
    var id = _id(state, "job");
    state.jobs[id] = {
        "kind": kind,
        "entries": entries.slice()
    };
    var failed = entries.concat([label]).some(function (e) {
        return state.fail.indexOf(e) >= 0;
    });
    var base = function (st, pct, phase) {
        return {
            "job": id,
            "kind": kind,
            "entries": entries.slice(),
            "state": st,
            "percent": pct,
            "phase": phase
        };
    };
    var steps = Math.round(INSTALL_MS / INSTALL_STEP_MS);
    for (var k = 1; k < steps; k++)
        _at(state, now + k * INSTALL_STEP_MS, id, "extras.progress", base("running", Math.round(k * 100 / steps), "dry run: " + label));
    var last = failed ? Object.assign(base("failed", 100, "dry run: " + label), {
        "reason": "network"
    }) : base("done", 100, "dry run: " + label);
    _at(state, now + INSTALL_MS, id, "extras.progress", last, (failed ? "failed (network): " : "done: ") + label);
    if (!failed && onDone)
        state.queue[state.queue.length - 1].onDone = onDone;
    return {
        "ref": {
            "id": id,
            "kind": kind,
            "entries": entries.slice()
        },
        "first": base("queued", 0, "dry run: queued")
    };
}

function _jobsResult(jobs) {
    return {
        "jobs": jobs.map(function (j) {
            return j.ref;
        })
    };
}

function _progressEvents(jobs) {
    return jobs.map(function (j) {
        return {
            "service": "extras.progress",
            "data": j.first,
            "line": null
        };
    });
}

function _install(state, params, now) {
    var ids = (params && params.ids) || [];
    var ok = ids.filter(function (i) {
        return state.fail.indexOf(i) < 0;
    });
    var bad = ids.filter(function (i) {
        return state.fail.indexOf(i) >= 0;
    });
    var jobs = [];
    [ok, bad].forEach(function (group) {
        if (group.length === 0)
            return;
        jobs.push(_job(state, "system", group, "install " + group.join(", "), now, function (s) {
            group.forEach(function (i) {
                s.installed[i] = true;
            });
            return s.status ? {
                "service": "extras.status",
                "data": overlay(s, "extras.status", s.status)
            } : null;
        }));
    });
    return jobs;
}

// The answer to a mutating call: {result, error, line, events}; `events`
// are emitted right after the callback, later ones wait in the queue.
function handle(state, method, params, now) {
    var out = {
        "result": {},
        "error": null,
        "line": Methods.line(method, params, state),
        "events": []
    };
    var p = params || {};
    var jobs;
    switch (method) {
    case "displays.apply":
        var sid = _id(state, "session");
        out.result = {
            "session": sid,
            "revertIn": SESSION_SECONDS,
            "live": true
        };
        for (var k = 1; k < SESSION_SECONDS; k++)
            _at(state, now + k * 1000, sid, "displays.session", _session(sid, "pending", SESSION_SECONDS - k));
        _at(state, now + SESSION_SECONDS * 1000, sid, "displays.session", _session(sid, "reverted", 0), "display change reverted (no answer in " + SESSION_SECONDS + " s)");
        break;
    case "displays.keep":
    case "displays.revert":
        _drop(state, p.session);
        out.events.push({
            "service": "displays.session",
            "data": _session(p.session, method === "displays.keep" ? "kept" : "reverted", 0),
            "line": null
        });
        break;
    case "displays.identify":
        // numbers on this instance's screens only (the real shell sees nothing)
        out.events.push({
            "service": "displays.identify",
            "data": {
                "outputs": state.outputs.map(function (o, i) {
                    return {
                        "name": o.name,
                        "index": i + 1
                    };
                })
            },
            "line": null
        });
        break;
    case "keystore.list":
        out.result = [];
        break;
    case "displays.moveConflicts":
        out.result = {
            "outputs": []
        };
        break;
    case "extras.install":
        jobs = _install(state, p, now);
        out.result = _jobsResult(jobs);
        out.events = _progressEvents(jobs);
        break;
    case "extras.ollamaPull":
        jobs = [_job(state, "ollama", [], String(p.model), now, null)];
        out.result = _jobsResult(jobs);
        out.events = _progressEvents(jobs);
        break;
    case "extras.setLoginShell":
        jobs = [_job(state, "loginshell", [], "login shell " + p.shell, now, function (s) {
                s.loginShell = String(p.shell);
                return null;
            })];
        out.result = _jobsResult(jobs);
        out.events = _progressEvents(jobs);
        break;
    case "extras.upgradeAndRetry":
        var orig = state.jobs[p.job] || {
            "kind": "system",
            "entries": []
        };
        jobs = [_job(state, "upgrade", orig.entries, "upgrade the system and retry", now, null)];
        out.result = _jobsResult(jobs);
        out.events = _progressEvents(jobs);
        break;
    case "extras.cancel":
        var before = state.queue.length;
        var known = state.jobs[p.job] || {
            "kind": "system",
            "entries": []
        };
        _drop(state, p.job);
        if (state.queue.length !== before)
            out.events.push({
                "service": "extras.progress",
                "data": {
                    "job": p.job,
                    "kind": known.kind,
                    "entries": known.entries.slice(),
                    "state": "cancelled",
                    "percent": -1,
                    "phase": "dry run: cancelled"
                },
                "line": null
            });
        break;
    case "term.apply":
        out.result = null;
        break;
    case "exclusive.enable":
    case "exclusive.restore":
        state.exclusive = method === "exclusive.enable";
        out.result = {
            "active": state.exclusive,
            "backup": "",
            "disabledUnits": [],
            "compositor": "hyprland",
            "reason": "",
            "replaced": ""
        };
        break;
    }
    return out;
}

// Queued events whose time has come, in order: [{service, data, line}].
function due(state, now) {
    var ready = state.queue.filter(function (e) {
        return e.at <= now;
    }).sort(function (a, b) {
        return a.at - b.at;
    });
    state.queue = state.queue.filter(function (e) {
        return e.at > now;
    });
    var out = [];
    ready.forEach(function (e) {
        out.push({
            "service": e.service,
            "data": e.data,
            "line": e.line
        });
        if (e.onDone) {
            var extra = e.onDone(state);
            if (extra)
                out.push({
                    "service": extra.service,
                    "data": extra.data,
                    "line": null
                });
        }
    });
    return out;
}

// A real read answer made consistent with the faked changes (also records
// what later journal lines and events compare against).
function overlay(state, method, result) {
    if (!result || typeof result !== "object")
        return result;
    switch (method) {
    case "displays.list":
        state.outputs = Array.isArray(result) ? result : [];
        return result;
    case "extras.status":
        state.status = result;
        var st = Object.assign({}, result);
        Object.keys(state.installed).forEach(function (id) {
            st[id] = Object.assign({}, st[id] || {}, {
                "id": id,
                "state": "installed",
                "source": "dry-run"
            });
        });
        return st;
    case "exclusive.status":
        return state.exclusive === null ? result : Object.assign({}, result, {
            "active": state.exclusive
        });
    case "term.status":
        if (!state.loginShell && !state.installed.fish)
            return result;
        return Object.assign({}, result, {
            "fishInstalled": result.fishInstalled || !!state.installed.fish,
            "fishIsLoginShell": result.fishIsLoginShell || /fish$/.test(state.loginShell)
        });
    }
    return result;
}

// Same for pushed events (a real detection must not undo a fake install).
function overlayEvent(state, service, data) {
    return service === "extras.status" ? overlay(state, service, data) : data;
}
