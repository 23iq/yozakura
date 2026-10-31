.pragma library

// Wallpaper folders: the primary folder (wallPath in
// ~/.cache/yozakura/wallpapers.json) plus extra folders
// (Config.desktop.wallpaperFolders). Pure helpers shared by Wallpaper.qml
// and the settings; tested in tests/wallpaper-folders.test.cjs.

var EXTENSIONS = ["jpg", "jpeg", "png", "webp", "tif", "tiff", "gif", "mp4", "webm", "mov", "avi", "mkv"];

// Depth maps for the panorama parallax / depth layering live next to their
// image as <name>.depth.png: they are not wallpapers themselves.
var DEPTH_SUFFIX = /\.depth\.png$/i;

function isDepthMap(path) {
    return DEPTH_SUFFIX.test(String(path || ""));
}

// Scan output -> { wallpapers, depthMaps }, both sorted, empties dropped.
function splitScan(files) {
    var walls = [];
    var maps = [];
    (files || []).forEach(function (f) {
        if (!f)
            return;
        (isDepthMap(f) ? maps : walls).push(f);
    });
    return {
        wallpapers: walls.sort(),
        depthMaps: maps.sort()
    };
}

function normalize(path) {
    var p = String(path || "").trim();
    while (p.length > 1 && p.charAt(p.length - 1) === "/")
        p = p.substring(0, p.length - 1);
    return p;
}

// [primary, ...extras] without empties or duplicates, primary first.
function effective(primary, extras) {
    var out = [];
    var all = [primary].concat(extras || []);
    for (var i = 0; i < all.length; i++) {
        var p = normalize(all[i]);
        if (p && out.indexOf(p) === -1)
            out.push(p);
    }
    return out;
}

// BUNDLED is the tail of the example wallpapers folder shipped with the
// shell. Its absolute location moves when the shell does (each Nix update is
// a new store path, mods run from a generation dir), so a saved path into
// an older copy is moved onto the current one; other paths stay as they are.
var BUNDLED = "/assets/wallpapers_example";

function rebaseBundled(path, bundledDir) {
    var p = String(path || "");
    var dir = normalize(bundledDir);
    var at = p.indexOf(BUNDLED);
    if (!dir || at < 0)
        return p;
    var tail = p.substring(at + BUNDLED.length);
    if (tail !== "" && tail.charAt(0) !== "/")
        return p;
    return dir + tail;
}

// Extra folders only (normalized, primary and duplicates removed).
function extras(primary, list) {
    return effective(primary, list).slice(normalize(primary) ? 1 : 0);
}

function isInside(file, folder) {
    var f = normalize(folder);
    return !!f && String(file).indexOf(f === "/" ? "/" : f + "/") === 0;
}

// The deepest folder that contains `file`, or "".
function rootOf(file, folders) {
    var best = "";
    for (var i = 0; i < folders.length; i++) {
        var f = normalize(folders[i]);
        if (isInside(file, f) && f.length > best.length)
            best = f;
    }
    return best;
}

function countIn(paths, folder) {
    var n = 0;
    for (var i = 0; i < paths.length; i++) {
        if (isInside(paths[i], folder))
            n++;
    }
    return n;
}

// Thumbnail of `file` (backend `yozakura thumbs` writes the same paths):
//   primary folder: <cache>/thumbnails/<relative path>.jpg (historical)
//   extra folder R: <cache>/thumbnails/_extra/<md5(R)[0:12]>/<relative>.jpg
function thumbnailPath(file, primary, extraFolders, cacheBase, md5) {
    var base = normalize(primary);
    var root = rootOf(file, extraFolders || []);
    if (root && !(base && isInside(file, base) && base.length >= root.length)) {
        return cacheBase + "/thumbnails/_extra/" + md5(root).substring(0, 12) + "/" + file.substring(root.length + 1) + ".jpg";
    }
    var prefix = base ? base + "/" : "";
    var rel = prefix && file.indexOf(prefix) === 0 ? file.substring(prefix.length) : file.replace(prefix, "");
    var parts = rel.split("/");
    var name = parts.pop();
    return cacheBase + "/thumbnails/" + parts.join("/") + "/" + name + ".jpg";
}

// Media scan over every folder. Run through sh so a missing extra folder
// only drops its own results (find's errors are discarded). Hidden entries
// below a folder are skipped, but a folder that is itself hidden
// (~/.wallpapers) is scanned (-mindepth 1); extensions match any case.
function findCommand(dirs) {
    if (!dirs || dirs.length === 0)
        return ["true"];
    var names = [];
    for (var i = 0; i < EXTENSIONS.length; i++) {
        if (i > 0)
            names.push("-o");
        names.push("-iname", "*." + EXTENSIONS[i]);
    }
    return ["sh", "-c", "find -L \"$@\" -mindepth 1 -name '.*' -prune -o -type f \\( " + names.map(function (a) {
            return a === "-o" || a === "-iname" ? a : "'" + a + "'";
        }).join(" ") + " \\) -print 2>/dev/null || true", "sh"].concat(dirs);
}
