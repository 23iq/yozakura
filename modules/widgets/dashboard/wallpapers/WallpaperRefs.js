.pragma library

// How wallpapers.json refers to a wallpaper (currentWall,
// perScreenWallpapers) and which one is shown when the saved one is gone.
//
// The bundled example wallpapers live inside the shell, whose absolute
// location changes on every Nix rebuild (a new /nix/store path) or mods
// generation. They are stored as a location-independent id,
// "bundled:<path relative to the bundled folder>", and resolved against the
// running shell's folder at load. Older files hold the absolute path into
// some copy of the folder: anything after "/assets/wallpapers_example/" is
// taken as the id. When that file is no longer bundled (renamed between
// releases) the basename is matched against the current set.
// Tested in tests/wallpaper-refs.test.cjs; the backend twin is
// backend/pkg/wallref.

var PREFIX = "bundled:";
var MARKER = "/assets/wallpapers_example/";

var IMAGE_EXT = ["jpg", "jpeg", "png", "webp", "tif", "tiff", "bmp"];
var VIDEO_EXT = ["mp4", "webm", "mov", "avi", "mkv"];

function _trim(dir) {
    var d = String(dir || "");
    while (d.length > 1 && d.charAt(d.length - 1) === "/")
        d = d.substring(0, d.length - 1);
    return d;
}

function isBundledId(stored) {
    return String(stored || "").indexOf(PREFIX) === 0;
}

// Path relative to the bundled folder ("" when `path` is not a bundled
// wallpaper of this or any older copy of the shell).
function bundledRel(path, bundledDir) {
    var p = String(path || "");
    if (isBundledId(p))
        return p.substring(PREFIX.length);
    var dir = _trim(bundledDir);
    if (dir && p.indexOf(dir + "/") === 0)
        return p.substring(dir.length + 1);
    var at = p.lastIndexOf(MARKER);
    return at >= 0 ? p.substring(at + MARKER.length) : "";
}

// Absolute path (what the shell shows) -> value saved in wallpapers.json.
function toStored(path, bundledDir) {
    var rel = bundledRel(path, bundledDir);
    return rel ? PREFIX + rel : String(path || "");
}

// Saved value -> absolute path in the running shell.
function fromStored(stored, bundledDir) {
    var rel = bundledRel(stored, bundledDir);
    var dir = _trim(bundledDir);
    return rel && dir ? dir + "/" + rel : String(stored || "");
}

function _base(path) {
    var p = String(path || "");
    return p.substring(p.lastIndexOf("/") + 1);
}

// fromStored, checked against the current bundled files when known: a
// bundled id that no longer exists falls back to the file with the same
// name, or "" when there is none.
function resolveSaved(stored, bundledDir, bundledFiles) {
    var abs = fromStored(stored, bundledDir);
    if (!bundledRel(stored, bundledDir) || !bundledFiles || bundledFiles.length === 0)
        return abs;
    if (bundledFiles.indexOf(abs) >= 0)
        return abs;
    var name = _base(abs);
    for (var i = 0; i < bundledFiles.length; i++) {
        if (_base(bundledFiles[i]) === name)
            return bundledFiles[i];
    }
    return "";
}

// Map of screen -> saved value, converted with `fn` (toStored/fromStored).
function mapScreens(screens, bundledDir, fn) {
    var out = {};
    for (var name in (screens || {}))
        out[name] = fn(screens[name], bundledDir);
    return out;
}

function kind(path) {
    var ext = String(path || "").toLowerCase().split(".").pop();
    if (IMAGE_EXT.indexOf(ext) >= 0)
        return "image";
    if (ext === "gif")
        return "gif";
    if (VIDEO_EXT.indexOf(ext) >= 0)
        return "video";
    return "unknown";
}

// Wallpaper shown when nothing valid is saved: the first still image, then
// the first GIF, then whatever comes first (a video decodes all the time).
function preferredIndex(paths) {
    var list = paths || [];
    if (list.length === 0)
        return -1;
    var order = ["image", "gif"];
    for (var k = 0; k < order.length; k++) {
        for (var i = 0; i < list.length; i++) {
            if (kind(list[i]) === order[k])
                return i;
        }
    }
    return 0;
}

// Selection after a scan. `saved` is the resolved saved wallpaper ("" for
// none). A saved bundled wallpaper outside the scanned folders stays
// selected: it is appended to the list. Returns {paths, index, found}.
function choose(paths, saved, bundledFiles) {
    var list = (paths || []).slice();
    var index = saved ? list.indexOf(saved) : -1;
    if (index < 0 && saved && (bundledFiles || []).indexOf(saved) >= 0) {
        list.push(saved);
        index = list.length - 1;
    }
    var found = index >= 0;
    if (!found)
        index = preferredIndex(list);
    return {
        "paths": list,
        "index": index,
        "found": found
    };
}

// Scan output of the scanned folders plus the bundled folder, split into
// the wallpapers of `dirs` and the bundled files (a file can be both when
// the bundled folder is one of `dirs`).
function partition(files, dirs, bundledDir) {
    var walls = [];
    var bundled = [];
    var b = _trim(bundledDir);
    var roots = (dirs || []).map(_trim).filter(function (d) {
        return d !== "";
    });
    (files || []).forEach(function (f) {
        if (!f)
            return;
        if (b && f.indexOf(b + "/") === 0)
            bundled.push(f);
        for (var i = 0; i < roots.length; i++) {
            if (f.indexOf(roots[i] === "/" ? "/" : roots[i] + "/") === 0) {
                walls.push(f);
                return;
            }
        }
    });
    return {
        "wallpapers": walls,
        "bundled": bundled.sort()
    };
}
