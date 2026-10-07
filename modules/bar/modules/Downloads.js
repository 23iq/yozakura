.pragma library

// Pure helpers for DownloadsStack.qml / DownloadsList.qml (tested in tests/panel-modules.test.cjs).

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

// Downloads still in flight among ActivityService transfers (running,
// paused or queued downloads), newest first
function active(transfers) {
    var list = Array.isArray(transfers) ? transfers : [];
    return list.filter(function (t) {
        return t && (t.kind || "download") === "download" && ["running", "paused", "queued"].indexOf(t.state) !== -1;
    }).sort(function (a, b) {
        return (b.startedAt || 0) - (a.startedAt || 0);
    });
}

// Subtitle of a transfer row: "340 MB / 720 MB · 47%", either part alone
function transferLine(sizes, percent) {
    return [sizes, percent].filter(function (s) {
        return s !== undefined && s !== null && String(s) !== "";
    }).join(" · ");
}
