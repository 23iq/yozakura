.pragma library

// File search for the launcher: argv for fd / plocate (scoped to $HOME,
// excludes applied) and parsing of their output. Every line the wrapper
// prints is "<d|f>\t<path>" (directories are told apart in the shell so the
// tools' own output formats do not matter).

// Picks the backend: "fd" | "plocate" | "" (none installed).
function backend(pref, tools) {
    tools = tools || {};
    if (pref === "fd" && tools.fd)
        return "fd";
    if (pref === "plocate" && tools.plocate)
        return "plocate";
    if (tools.fd)
        return "fd";
    if (tools.plocate)
        return "plocate";
    return "";
}

// sh -c scripts; every value (binary, limits, query, home, excludes) is a
// positional argument. Each prints "<d|f>\t<path>" per match.
//   fd:      $1 binary, $2 max results, $3 query, $4 home, then --exclude pairs
//   plocate: $1 limit, $2 query, $3 home prefix, $4 head count
var FD_SCRIPT = 'bin=$1; n=$2; q=$3; home=$4; shift 4; "$bin" --ignore-case --fixed-strings --hidden --max-results "$n" "$@" -- "$q" "$home" 2>/dev/null | while IFS= read -r p; do if [ -d "$p" ]; then printf "d\\t%s\\n" "$p"; else printf "f\\t%s\\n" "$p"; fi; done';
var PLOCATE_SCRIPT = 'plocate --ignore-case --limit "$1" -- "$2" 2>/dev/null | grep -F -- "$3" | head -n "$4" | while IFS= read -r p; do if [ -d "$p" ]; then printf "d\\t%s\\n" "$p"; else printf "f\\t%s\\n" "$p"; fi; done';

// argv that prints "<d|f>\t<path>" for at most `limit` matches of `query`
// under `home` (null when there is nothing to search).
//   tools.fd: the fd binary name ("fd" or Debian's "fdfind")
function command(kind, query, home, excludes, limit, tools) {
    const q = String(query || "").trim();
    if (q === "" || !kind)
        return null;
    limit = Math.max(1, limit || 30);
    if (kind === "fd") {
        const bin = (tools && typeof tools.fd === "string") ? tools.fd : "fd";
        const ex = [];
        (excludes || []).forEach(e => ex.push("--exclude", String(e)));
        return ["sh", "-c", FD_SCRIPT, "file-search", bin, String(limit * 5), q, String(home)].concat(ex);
    }
    if (kind === "plocate") {
        // plocate has no scope or exclude flags: over-fetch, then filter.
        return ["sh", "-c", PLOCATE_SCRIPT, "file-search", String(limit * 20), q, home + "/", String(limit * 4)];
    }
    return null;
}

function excluded(path, home, excludes) {
    const rel = path.indexOf(home + "/") === 0 ? path.substring(home.length + 1) : path;
    const segs = "/" + rel + "/";
    return (excludes || []).some(e => {
        const x = String(e).replace(/^\/+|\/+$/g, "");
        return x !== "" && segs.indexOf("/" + x + "/") !== -1;
    });
}

// Parses wrapper output into [{path, name, dir, isDir}] (home-scoped,
// excludes applied, best matches first: name match before path match,
// shallower first).
function parse(text, query, home, excludes, limit) {
    const q = String(query || "").trim().toLowerCase();
    const out = [];
    const seen = {};
    String(text || "").split("\n").forEach(line => {
        const tab = line.indexOf("\t");
        if (tab < 0)
            return;
        let path = line.substring(tab + 1).replace(/\/+$/, "");
        if (path === "" || seen[path])
            return;
        if (home && path.indexOf(home + "/") !== 0)
            return;
        if (excluded(path, home, excludes))
            return;
        seen[path] = true;
        const slash = path.lastIndexOf("/");
        out.push({
            "path": path,
            "name": path.substring(slash + 1),
            "dir": path.substring(0, slash),
            "isDir": line[0] === "d"
        });
    });
    const rank = f => {
        const n = f.name.toLowerCase();
        let r = n === q ? 0 : n.indexOf(q) === 0 ? 1 : n.indexOf(q) !== -1 ? 2 : 3;
        return r * 1000 + f.path.split("/").length;
    };
    out.sort((a, b) => rank(a) - rank(b));
    return out.slice(0, limit || out.length);
}

// "~/Documents/x" for display.
function pretty(path, home) {
    if (home && path.indexOf(home) === 0)
        return "~" + path.substring(home.length);
    return path;
}

var EXT_ICONS = {
    "image": ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "avif", "heic", "tiff"],
    "musicNotes": ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac"],
    "screencast": ["mp4", "mkv", "webm", "mov", "avi"],
    "fileCode": ["js", "ts", "qml", "py", "go", "rs", "c", "h", "cpp", "java", "sh", "lua", "json", "toml", "yaml", "yml", "html", "css"],
    "fileText": ["txt", "md", "pdf", "doc", "docx", "odt", "rtf", "org", "tex", "csv"],
    "cube": ["zip", "tar", "gz", "xz", "zst", "7z", "rar", "deb", "rpm"]
};

// Icons glyph name for a file.
function iconName(file) {
    if (file.isDir)
        return "folder";
    const dot = file.name.lastIndexOf(".");
    const ext = dot > 0 ? file.name.substring(dot + 1).toLowerCase() : "";
    for (const k in EXT_ICONS) {
        if (EXT_ICONS[k].indexOf(ext) !== -1)
            return k;
    }
    return "file";
}
