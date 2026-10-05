.pragma library

// Wallpaper folders: the primary folder (wallPath in
// ~/.cache/yozakura/wallpapers.json) plus extra folders
// (Config.desktop.wallpaperFolders). Pure helpers shared by Wallpaper.qml
// and the settings; tested in tests/wallpaper-folders.test.cjs.

var EXTENSIONS = ["jpg", "jpeg", "png", "webp", "tif", "tiff", "gif", "mp4", "webm", "mov", "avi", "mkv"];

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
// only drops its own results (find's errors are discarded).
function findCommand(dirs) {
    if (!dirs || dirs.length === 0)
        return ["true"];
    var names = [];
    for (var i = 0; i < EXTENSIONS.length; i++) {
        if (i > 0)
            names.push("-o");
        names.push("-name", "*." + EXTENSIONS[i]);
    }
    return ["sh", "-c", "find -L \"$@\" -name '.*' -prune -o -type f \\( " + names.map(function (a) {
            return a === "-o" ? a : (a === "-name" ? a : "'" + a + "'");
        }).join(" ") + " \\) -print 2>/dev/null || true", "sh"].concat(dirs);
}
