.pragma library

// Pure helpers of the Code folder picker (FolderPicker.qml): the path field
// ("~/src/yo" = browse ~/src filtered by "yo"; text without a leading "/"
// or "~" searches the recent folders and the discovered repositories),
// breadcrumbs, the row list with section headers and keyboard stepping.

function trimSlash(p) {
    var s = String(p || "");
    while (s.length > 1 && s.charAt(s.length - 1) === "/")
        s = s.substring(0, s.length - 1);
    return s;
}

// "/home/u/src" -> "~/src" (display form).
function tilde(path, home) {
    var p = trimSlash(path);
    if (home && (p === home || p.indexOf(home + "/") === 0))
        return "~" + p.substring(home.length);
    return p;
}

// "~/src" -> "/home/u/src"; "" for text that is not a path.
function expand(text, home) {
    var t = String(text || "").trim();
    if (t === "~" || t.indexOf("~/") === 0)
        t = (home || "") + t.substring(1);
    return t.charAt(0) === "/" ? trimSlash(t) : "";
}

function isPath(text) {
    var t = String(text || "").trim();
    return t.charAt(0) === "/" || t.charAt(0) === "~";
}

// The field split into the folder to list and the name typed after its
// last "/": {dir, partial}. Search text gives {dir: "", partial: text}.
function split(text, home) {
    var t = String(text || "").trim();
    if (!isPath(t))
        return { dir: "", partial: t };
    if (t === "~")
        return { dir: home || "/", partial: "" };
    var cut = t.lastIndexOf("/");
    var head = t.substring(0, cut + 1);
    return { dir: expand(head, home) || "/", partial: t.substring(cut + 1) };
}

// Field text that browses `dir` (trailing slash: list its subfolders).
function browseText(dir, home) {
    var t = tilde(dir, home);
    return t === "/" ? "/" : t + "/";
}

function parent(dir) {
    var p = trimSlash(dir);
    var cut = p.lastIndexOf("/");
    return cut <= 0 ? "/" : p.substring(0, cut);
}

function baseName(path) {
    var parts = trimSlash(path).split("/").filter(function (x) { return x; });
    return parts.length ? parts[parts.length - 1] : "/";
}

// [{label, path}] from the root ("/" or "~") down to `dir`.
function crumbs(dir, home) {
    var p = trimSlash(dir);
    if (!p)
        return [];
    var inHome = home && (p === home || p.indexOf(home + "/") === 0);
    var out = [inHome ? { label: "~", path: home } : { label: "/", path: "/" }];
    var rest = inHome ? p.substring(home.length) : p;
    var acc = inHome ? home : "";
    rest.split("/").forEach(function (part) {
        if (!part)
            return;
        acc = acc + "/" + part;
        out.push({ label: part, path: acc });
    });
    return out;
}

// 3: same name, 2: prefix, 1: substring (case-insensitive), 0: no match.
function score(name, query) {
    var q = String(query || "").toLowerCase();
    if (!q)
        return 1;
    var n = String(name || "").toLowerCase();
    if (n === q)
        return 3;
    if (n.indexOf(q) === 0)
        return 2;
    return n.indexOf(q) >= 0 ? 1 : 0;
}

// Items that match `query` by name (prefix first) or, weaker, anywhere in
// their path; stable otherwise.
function filtered(items, query, nameOf, pathOf) {
    var scored = [];
    for (var i = 0; i < items.length; i++) {
        var s = score(nameOf(items[i]), query);
        if (s === 0 && pathOf && score(pathOf(items[i]), query) > 0)
            s = 0.5;
        if (s > 0)
            scored.push({ item: items[i], s: s, i: i });
    }
    scored.sort(function (a, b) { return b.s - a.s || a.i - b.i; });
    return scored.map(function (x) { return x.item; });
}

// Rows of the picker list. o: {text, home, entries (fs.list), recents
// (paths), repos (fs.repos), hidden (show dot folders), limit}.
// Row: {type: "header", label} | {type: "dir"|"recent"|"repo", path, name,
// git, detail}.
function rows(o) {
    var home = o.home || "";
    var f = split(o.text, home);
    var out = [];
    var limit = o.limit || 200;
    if (!f.dir) {
        var recents = filtered((o.recents || []).filter(function (p) { return !!p; }), f.partial, baseName, function (p) {
            return tilde(p, home);
        }).slice(0, f.partial ? 8 : 5);
        var known = {};
        recents.forEach(function (p) { known[p] = true; });
        var repos = filtered((o.repos || []).filter(function (r) { return !known[r.path]; }), f.partial, function (r) {
            return r.name || baseName(r.path);
        }, function (r) {
            return tilde(r.path, home);
        }).slice(0, limit);
        if (recents.length) {
            out.push({ type: "header", label: "recent" });
            recents.forEach(function (p) {
                out.push({ type: "recent", path: p, name: baseName(p), git: false, detail: tilde(parent(p), home) });
            });
        }
        if (repos.length) {
            out.push({ type: "header", label: "repos" });
            repos.forEach(function (r) {
                out.push({ type: "repo", path: r.path, name: r.name || baseName(r.path), git: true, detail: tilde(parent(r.path), home) });
            });
        }
        return out;
    }
    var entries = (o.entries || []).filter(function (e) {
        return o.hidden || !e.hidden || (f.partial && f.partial.charAt(0) === ".");
    });
    var dirs = filtered(entries, f.partial, function (e) { return e.name; }).slice(0, limit);
    if (dirs.length)
        out.push({ type: "header", label: "folders" });
    dirs.forEach(function (e) {
        out.push({ type: "dir", path: e.path, name: e.name, git: !!e.git, detail: "" });
    });
    return out;
}

// Next selectable row from `index` in direction `dir` (+1/-1); headers
// are skipped, the ends stop (-1 = nothing selected).
function step(list, index, dir) {
    var i = index;
    for (var n = 0; n < list.length; n++) {
        i += dir;
        if (i < 0 || i >= list.length)
            return dir < 0 ? -1 : index;
        if (list[i].type !== "header")
            return i;
    }
    return index;
}

// First selectable row (or -1).
function first(list) {
    return step(list, -1, 1);
}

// Folder the picker would choose: the selected row, else the listed folder
// when nothing is typed after its "/", else a typed path.
function target(list, index, text, home) {
    var row = list[index];
    if (row && row.type !== "header")
        return row.path;
    var f = split(text, home);
    if (!f.dir)
        return "";
    return f.partial ? trimSlash(f.dir === "/" ? "/" + f.partial : f.dir + "/" + f.partial) : f.dir;
}
