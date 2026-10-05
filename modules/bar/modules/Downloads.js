.pragma library

// Pure helpers for DownloadsStack.qml (tested in tests/panel-modules.test.cjs).

var IMAGE = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif"];
var KINDS = {
    "pdf": "application-pdf",
    "zip": "package-x-generic",
    "gz": "package-x-generic",
    "xz": "package-x-generic",
    "zst": "package-x-generic",
    "7z": "package-x-generic",
    "rar": "package-x-generic",
    "tar": "package-x-generic",
    "deb": "package-x-generic",
    "rpm": "package-x-generic",
    "appimage": "application-x-executable",
    "iso": "media-optical",
    "mp4": "video-x-generic",
    "mkv": "video-x-generic",
    "webm": "video-x-generic",
    "mov": "video-x-generic",
    "mp3": "audio-x-generic",
    "flac": "audio-x-generic",
    "ogg": "audio-x-generic",
    "wav": "audio-x-generic",
    "txt": "text-x-generic",
    "md": "text-x-generic",
    "json": "text-x-generic",
    "doc": "x-office-document",
    "docx": "x-office-document",
    "odt": "x-office-document",
    "xls": "x-office-spreadsheet",
    "xlsx": "x-office-spreadsheet",
    "ods": "x-office-spreadsheet",
    "ppt": "x-office-presentation",
    "pptx": "x-office-presentation",
    "torrent": "application-x-bittorrent"
};

function extension(name) {
    var s = String(name || "");
    var dot = s.lastIndexOf(".");
    return dot > 0 ? s.slice(dot + 1).toLowerCase() : "";
}

function isImage(name) {
    return IMAGE.indexOf(extension(name)) !== -1;
}

// Theme icon for a file (images are shown as themselves)
function iconFor(name) {
    return KINDS[extension(name)] || "text-x-generic";
}

// Partial downloads are not offered
function isPartial(name) {
    var e = extension(name);
    return e === "part" || e === "crdownload" || e === "tmp" || e === "download";
}

// macOS-like fan: `count` tiles rising from the stack along an arc that
// bends towards `side` (+1 right, -1 left). Returns [{x, y, rotation}]
// offsets from the stack's center, nearest first; `step` px apart.
function fan(count, step, side) {
    var out = [];
    var dir = side < 0 ? -1 : 1;
    for (var i = 0; i < count; i++) {
        var t = i + 1;
        var y = -t * step;
        // Quadratic drift sideways: the fan curls as it rises
        var x = dir * 0.035 * step * t * t;
        out.push({
            "x": Math.round(x),
            "y": Math.round(y),
            "rotation": dir * Math.min(18, 1.6 * t * t * 0.5)
        });
    }
    return out;
}
