.pragma library

// Unified diff parser for agent diffs (git diffs, Codex turn diffs, plain
// hunks from Claude's structuredPatch). Output:
// [{path, oldPath, added, removed, binary, hunks: [{header, lines: [{kind, text, oldNo, newNo}]}]}]
// kind: "add" | "del" | "ctx" | "note" (e.g. "\ No newline at end of file").

var HUNK = /^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@ ?(.*)$/;

function _stripPrefix(p) {
    if (!p || p === "/dev/null")
        return "";
    var s = p.replace(/\t.*$/, "");
    if (s.indexOf("a/") === 0 || s.indexOf("b/") === 0)
        return s.substring(2);
    return s;
}

function _newFile(path) {
    return { path: path || "", oldPath: "", added: 0, removed: 0, binary: false, hunks: [] };
}

function parse(text, fallbackPath) {
    var files = [];
    var file = null;
    var hunk = null;
    var oldNo = 0;
    var newNo = 0;
    var oldLeft = 0;
    var newLeft = 0;
    var counted = false; // hunk header carried line counts
    var lines = String(text || "").split("\n");
    if (lines.length > 0 && lines[lines.length - 1] === "")
        lines.pop();

    function ensureFile() {
        if (!file) {
            file = _newFile(fallbackPath);
            files.push(file);
        }
        return file;
    }

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var inHunk = hunk !== null && (!counted || oldLeft > 0 || newLeft > 0 || line.charAt(0) === "\\");
        if (!inHunk) {
            hunk = null;
            if (line.indexOf("diff --git ") === 0) {
                var m = /^diff --git a\/(.*) b\/(.*)$/.exec(line);
                file = _newFile(m ? m[2] : fallbackPath);
                files.push(file);
                continue;
            }
            if (line.indexOf("--- ") === 0 && i + 1 < lines.length && lines[i + 1].indexOf("+++ ") === 0) {
                var oldP = _stripPrefix(line.substring(4));
                var newP = _stripPrefix(lines[i + 1].substring(4));
                if (!file || file.hunks.length > 0) {
                    file = _newFile(newP || oldP);
                    files.push(file);
                }
                file.path = newP || oldP || file.path;
                file.oldPath = oldP;
                i++;
                continue;
            }
            if (line.indexOf("Binary files") === 0) {
                ensureFile().binary = true;
                continue;
            }
        }
        var h = HUNK.exec(line);
        if (h) {
            ensureFile();
            oldNo = parseInt(h[1], 10);
            newNo = parseInt(h[3], 10);
            oldLeft = h[2] === undefined ? 1 : parseInt(h[2], 10);
            newLeft = h[4] === undefined ? 1 : parseInt(h[4], 10);
            counted = true;
            hunk = { header: line, oldStart: oldNo, newStart: newNo, lines: [] };
            file.hunks.push(hunk);
            continue;
        }
        if (!hunk) {
            // Headerless hunk body (structuredPatch lines without "@@").
            if (/^[ +\-\\]/.test(line) && !/^(index |new file mode|deleted file mode|similarity index|rename |old mode|new mode|===|Index: )/.test(line)) {
                ensureFile();
                oldNo = 1;
                newNo = 1;
                counted = false;
                hunk = { header: "", oldStart: 1, newStart: 1, lines: [] };
                file.hunks.push(hunk);
            } else {
                continue;
            }
        }
        var c = line.charAt(0);
        if (c === "+") {
            hunk.lines.push({ kind: "add", text: line.substring(1), oldNo: 0, newNo: newNo++ });
            file.added++;
            newLeft--;
        } else if (c === "-") {
            hunk.lines.push({ kind: "del", text: line.substring(1), oldNo: oldNo++, newNo: 0 });
            file.removed++;
            oldLeft--;
        } else if (c === "\\") {
            hunk.lines.push({ kind: "note", text: line.substring(1).trim(), oldNo: 0, newNo: 0 });
        } else {
            hunk.lines.push({ kind: "ctx", text: line.length > 0 ? line.substring(1) : "", oldNo: oldNo++, newNo: newNo++ });
            oldLeft--;
            newLeft--;
        }
    }
    return files;
}

// Flattened rows for a ListView: hunk headers + lines, each with the file path.
function rows(files) {
    var out = [];
    for (var f = 0; f < files.length; f++) {
        var file = files[f];
        for (var h = 0; h < file.hunks.length; h++) {
            var hunk = file.hunks[h];
            if (hunk.header)
                out.push({ kind: "hunk", text: hunk.header, oldNo: 0, newNo: 0, path: file.path });
            for (var l = 0; l < hunk.lines.length; l++) {
                var row = hunk.lines[l];
                out.push({ kind: row.kind, text: row.text, oldNo: row.oldNo, newNo: row.newNo, path: file.path });
            }
        }
    }
    return out;
}

function stats(files) {
    var added = 0;
    var removed = 0;
    for (var i = 0; i < files.length; i++) {
        added += files[i].added;
        removed += files[i].removed;
    }
    return { files: files.length, added: added, removed: removed };
}

// Minimal line diff (LCS) for old/new snapshots -> unified diff text.
// Used when an agent reports full before/after contents instead of a patch.
function unified(oldText, newText, path, context) {
    var ctx = context === undefined ? 3 : context;
    var a = String(oldText || "").split("\n");
    var b = String(newText || "").split("\n");
    if (a.length > 2000 || b.length > 2000)
        return "";
    var n = a.length;
    var m = b.length;
    var dp = [];
    for (var i = 0; i <= n; i++) {
        dp.push(new Array(m + 1).fill(0));
    }
    for (i = n - 1; i >= 0; i--)
        for (var j = m - 1; j >= 0; j--)
            dp[i][j] = a[i] === b[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    var ops = [];
    i = 0;
    j = 0;
    while (i < n && j < m) {
        if (a[i] === b[j]) {
            ops.push({ k: " ", t: a[i], o: i + 1, n: j + 1 });
            i++;
            j++;
        } else if (dp[i + 1][j] >= dp[i][j + 1]) {
            ops.push({ k: "-", t: a[i], o: i + 1, n: j + 1 });
            i++;
        } else {
            ops.push({ k: "+", t: b[j], o: i + 1, n: j + 1 });
            j++;
        }
    }
    while (i < n) {
        ops.push({ k: "-", t: a[i], o: i + 1, n: j + 1 });
        i++;
    }
    while (j < m) {
        ops.push({ k: "+", t: b[j], o: i + 1, n: j + 1 });
        j++;
    }
    var out = ["--- a/" + (path || "file"), "+++ b/" + (path || "file")];
    var idx = 0;
    while (idx < ops.length) {
        while (idx < ops.length && ops[idx].k === " ")
            idx++;
        if (idx >= ops.length)
            break;
        var start = Math.max(0, idx - ctx);
        var end = idx;
        var lastChange = idx;
        while (end < ops.length) {
            if (ops[end].k !== " ")
                lastChange = end;
            else if (end - lastChange > ctx * 2)
                break;
            end++;
        }
        end = Math.min(ops.length, lastChange + ctx + 1);
        var oldCount = 0;
        var newCount = 0;
        for (var k = start; k < end; k++) {
            if (ops[k].k !== "+")
                oldCount++;
            if (ops[k].k !== "-")
                newCount++;
        }
        out.push("@@ -" + ops[start].o + "," + oldCount + " +" + ops[start].n + "," + newCount + " @@");
        for (k = start; k < end; k++)
            out.push(ops[k].k + ops[k].t);
        idx = end;
    }
    return out.length > 2 ? out.join("\n") + "\n" : "";
}
