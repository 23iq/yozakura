pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

// Foreground ("depth") masks for the desktop depth clock.
//
// Wraps scripts/depth_mask.py, which runs inside an optional, isolated venv
// (scripts/depth_setup.sh). Jobs run one at a time, niced, fully async; the
// script itself caches per wallpaper path + mtime, so repeated requests are
// a ~20 ms cache hit. When the venv is missing every request resolves to
// "unavailable" and the clock simply renders in front of the wallpaper.
//
// Video wallpapers additionally get a "matte video" (scripts/depth_video.py:
// every frame segmented once, colour + mask stacked in one stream) built by
// a single long-running, niced + idle-I/O background job. Wallpapers declare
// what they show with setMatteWanted(); a job whose video nobody shows any
// more is killed (its per-frame masks stay on disk, so it resumes later).
// When a matte lands, the placement results of that video are refreshed and
// carry `matte`/`matteInfo`.
Singleton {
    id: root

    readonly property string dataDir: Brand.dataDir
    readonly property string venvPython: dataDir + "/venv-depth/bin/python"
    readonly property string modelsDir: dataDir + "/depth-models"
    // QUICKSHELL-GIT: readonly property string cacheDir: Quickshell.cachePath("depth")
    readonly property string cacheDir: Brand.cacheDir + "/depth"
    readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("../../scripts/depth_mask.py").toString().replace("file://", ""))
    readonly property string videoScriptPath: decodeURIComponent(Qt.resolvedUrl("../../scripts/depth_video.py").toString().replace("file://", ""))

    // False once a run found no venv; flips back on the next successful run.
    property bool available: true
    // "path|WxH" -> parsed script result (plain JS, read through result()).
    property var results: ({})
    // Bumped on every new result so bindings calling result() re-evaluate.
    property int revision: 0

    // Matte video job: the video being processed ("" when idle) and its
    // progress, 0..1.
    readonly property string matteJob: _matteJob ? _matteJob.path : ""
    property real matteProgress: 0
    // owner (e.g. screen name) -> video path it wants a matte for.
    property var _matteWanted: ({})
    // path -> {error, permanent} for videos whose matte job failed. Only
    // transient failures are retried, the next time the video is shown.
    property var _matteFailed: ({})
    // path -> [{w, h}] screen sizes placement was requested for.
    property var _sizes: ({})
    property var _matteJob: null
    property var _matteFinal: null
    property bool _matteExited: false
    property bool _matteCancelled: false

    property var _queue: []
    property var _job: null
    property int _exitCode: -1
    property bool _exited: false
    property bool _streamDone: false

    function _key(path, w, h) {
        return path + "|" + w + "x" + h;
    }

    function result(path, w, h) {
        root.revision;  // dependency for bindings
        return root.results[_key(path, w, h)] ?? null;
    }

    function request(path, w, h, force) {
        if (!path || w <= 0 || h <= 0)
            return;
        const key = _key(path, w, h);
        const sizes = root._sizes[path] ?? [];
        if (!sizes.some(s => s.w === w && s.h === h))
            root._sizes[path] = sizes.concat([{
                    w: w,
                    h: h
                }]);
        // force: re-run even though a result exists (it is kept until the
        // new one lands, so the clock never falls back in between).
        if (!force && root.results[key] !== undefined)
            return;
        if (root._job && root._job.key === key && !force)
            return;
        for (let i = 0; i < root._queue.length; i++) {
            if (root._queue[i].key === key)
                return;
        }
        root._queue = root._queue.concat([{
                key: key,
                path: path,
                w: w,
                h: h
            }]);
        _next();
    }

    // Declare which video `owner` shows ("" = none) and wants a matte for.
    function setMatteWanted(owner, path) {
        if ((root._matteWanted[owner] ?? "") === (path ?? ""))
            return;
        const next = Object.assign({}, root._matteWanted);
        const failure = path ? root._matteFailed[path] : undefined;
        if (failure && !failure.permanent && !Object.values(next).includes(path)) {
            const failed = Object.assign({}, root._matteFailed);
            delete failed[path];
            root._matteFailed = failed;
        }
        if (path)
            next[owner] = path;
        else
            delete next[owner];
        root._matteWanted = next;
        Qt.callLater(root._scheduleMatte);
    }

    function _hasMatte(path) {
        for (const key in root.results) {
            if (key.startsWith(path + "|") && root.results[key] && root.results[key].matte)
                return true;
        }
        return false;
    }

    function _scheduleMatte() {
        const wanted = Object.values(root._matteWanted);
        if (root._matteJob) {
            if (!wanted.includes(root._matteJob.path) && !root._matteCancelled) {
                root._matteCancelled = true;
                matteProc.signal(15);
            }
            return;
        }
        if (!root.available)
            return;
        for (const path of wanted) {
            if (root._matteFailed[path] !== undefined || root._hasMatte(path))
                continue;
            root._matteJob = {
                path: path
            };
            root._matteFinal = null;
            root._matteExited = false;
            root._matteCancelled = false;
            root.matteProgress = 0;
            // Lowest CPU and I/O priority: this can take minutes on CPU.
            matteProc.command = ["sh", "-c", "test -x \"$1\" || exit 127; command -v ionice >/dev/null 2>&1 && set -- ionice -c 3 \"$@\"; exec nice -n 15 \"$@\"", "depth-video", root.venvPython, root.videoScriptPath, path, "--cache-dir", root.cacheDir, "--models-dir", root.modelsDir];
            matteProc.running = true;
            return;
        }
    }

    function _matteLine(line) {
        let msg = null;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (msg.progress !== undefined)
            root.matteProgress = msg.progress;
        else if (msg.ok !== undefined)
            root._matteFinal = msg;
    }

    function _matteFinish(exitCode) {
        const job = root._matteJob;
        if (!job)
            return;
        const res = root._matteFinal;
        root._matteJob = null;
        root.matteProgress = 0;
        if (exitCode === 127) {
            root.available = false;
        } else if (res && res.ok) {
            // New placement (whole loop) + the matte itself.
            for (const s of (root._sizes[job.path] ?? []))
                root.request(job.path, s.w, s.h, true);
        } else if (!root._matteCancelled) {
            const failed = Object.assign({}, root._matteFailed);
            failed[job.path] = {
                error: res ? res.error : "exit " + exitCode,
                permanent: !!(res && res.permanent)
            };
            root._matteFailed = failed;
            if (!failed[job.path].permanent)
                console.warn("DepthMaskService: no matte for", job.path, failed[job.path].error, (matteErr.text || "").slice(-400));
        }
        root._matteCancelled = false;
        Qt.callLater(root._scheduleMatte);
    }

    function _next() {
        if (root._job || root._queue.length === 0)
            return;
        root._job = root._queue[0];
        root._queue = root._queue.slice(1);
        root._exited = false;
        root._streamDone = false;
        root._exitCode = -1;
        // Exit 127 without starting anything when the venv is not set up.
        proc.command = ["sh", "-c", "test -x \"$1\" || exit 127; exec nice -n 15 \"$@\"", "depth-mask", root.venvPython, root.scriptPath, root._job.path, "--cache-dir", root.cacheDir, "--models-dir", root.modelsDir, "--screen", root._job.w + "x" + root._job.h];
        proc.running = true;
    }

    function _finish() {
        if (!root._exited || !root._streamDone || !root._job)
            return;
        streamGrace.stop();
        const job = root._job;
        let res = null;
        if (root._exitCode === 127) {
            root.available = false;
            res = {
                ok: false,
                error: "venv missing"
            };
        } else {
            const lines = (stdoutCollector.text || "").trim().split("\n");
            try {
                res = JSON.parse(lines[lines.length - 1]);
                root.available = true;
            } catch (e) {
                res = {
                    ok: false,
                    error: "unparsable output"
                };
            }
            if (!res.ok)
                console.warn("DepthMaskService:", job.path, res.error, (stderrCollector.text || "").slice(-400));
        }
        const next = Object.assign({}, root.results);
        next[job.key] = res;
        root.results = next;
        root.revision++;
        root._job = null;
        Qt.callLater(root._next);
    }

    Process {
        id: matteProc
        stdout: SplitParser {
            onRead: line => root._matteLine(line)
        }
        stderr: StdioCollector {
            id: matteErr
        }
        onExited: exitCode => root._matteFinish(exitCode)
    }

    Process {
        id: proc
        stdout: StdioCollector {
            id: stdoutCollector
            onStreamFinished: {
                root._streamDone = true;
                root._finish();
            }
        }
        stderr: StdioCollector {
            id: stderrCollector
        }
        onExited: exitCode => {
            root._exitCode = exitCode;
            root._exited = true;
            root._finish();
            if (root._job)
                streamGrace.restart();
        }
    }

    // Never let a lost streamFinished stall the queue.
    Timer {
        id: streamGrace
        interval: 1500
        onTriggered: {
            root._streamDone = true;
            root._finish();
        }
    }
}
