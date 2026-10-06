.pragma library

// Serialised preset preview commands for one switcher session. `run(args,
// cb)` runs `<app> preset <args>` and calls cb when done. One command runs
// at a time; while one runs only the latest waiting command is kept, so
// fast hovering previews just where the pointer stops, and a revert or keep
// always runs after an in-flight preview. The queue holds no QML objects:
// a revert sent while the popup is destroyed still completes.

function create(run) {
    var q = {
        "busy": false,
        "next": null,
        "dirty": false,
        "closed": false
    };

    function send(args) {
        if (q.busy) {
            q.next = args;
            return;
        }
        q.busy = true;
        run(args, function () {
            q.busy = false;
            var n = q.next;
            q.next = null;
            if (n)
                send(n);
        });
    }

    // Live preview (args: ["apply", "--preview", name]).
    q.preview = function (args) {
        if (q.closed)
            return;
        q.dirty = true;
        send(args);
    };

    // Enter: a real apply, which also ends the backend preview.
    q.keep = function (args) {
        if (q.closed)
            return;
        q.closed = true;
        q.dirty = false;
        send(args);
    };

    // Escape or close: back to the look from before the first preview.
    q.revert = function () {
        if (q.closed)
            return;
        q.closed = true;
        if (q.dirty)
            send(["revert"]);
        else
            q.next = null;
        q.dirty = false;
    };

    return q;
}
