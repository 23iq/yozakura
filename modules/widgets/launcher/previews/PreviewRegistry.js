.pragma library

// Which results have a preview, and which component draws it. One entry per
// kind; PreviewPane loads the component lazily. Pure; tests/launcher-styles.test.cjs.

var KINDS = {
    "file": "previews/FilePreview.qml",
    "calc": "previews/CalcPreview.qml",
    "clipboard": "previews/ClipboardPreview.qml"
};

var IMAGE = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif"];
var TEXT = ["txt", "md", "json", "js", "ts", "qml", "py", "go", "sh", "toml", "yaml", "yml", "conf", "ini", "css", "html", "xml", "rs", "c", "h", "cpp", "log", "csv", "fish", "lua", "nix"];
var TEXT_NAMES = ["makefile", "readme", "license", "dockerfile"];

function previewFor(item) {
    if (!item || item.inert)
        return null;
    var kind = "";
    if (item.provider === "files" && item.data && item.data.path)
        kind = "file";
    else if (item.provider === "calculator" && (item.key === "calc" || item.key === "convert"))
        kind = "calc";
    else if (item.provider === "clipboard" && item.data)
        kind = "clipboard";
    return kind ? { "kind": kind, "file": KINDS[kind] } : null;
}

// Whether the selected result gets the detail pane (icon, name, type,
// description, actions): every runnable result, never a hint row.
function hasDetail(item) {
    return !!item && !item.inert;
}

// The actions listed in the detail pane: the provider's options (the main
// one has id ""), or just the main action (what Enter does) when it has none.
function actions(item, options) {
    if (options && options.length > 0)
        return options;
    if (!item || !item.hint)
        return [];
    return [{
            "id": "",
            "text": item.hint,
            "icon": item.icon || ""
        }];
}

function fileKind(path) {
    var name = String(path).split("/").pop().toLowerCase();
    var dot = name.lastIndexOf(".");
    var ext = dot >= 0 ? name.slice(dot + 1) : "";
    if (IMAGE.indexOf(ext) >= 0)
        return "image";
    if (TEXT.indexOf(ext) >= 0 || TEXT_NAMES.indexOf(name) >= 0)
        return "text";
    return "other";
}

function firstLines(text, n) {
    return text ? String(text).split("\n").slice(0, n).join("\n") : "";
}
