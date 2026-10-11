.pragma library

// Pure helpers of the composer's @file mentions and paste/drop handling.

// The `@query` token that ends at `cursor` (a mention starts at the line start
// or after whitespace and has no spaces), or null.
function activeMention(text, cursor) {
    const before = String(text || "").slice(0, cursor);
    const m = /(^|\s)@([^\s@]*)$/.exec(before);
    if (!m)
        return null;
    return {
        start: before.length - m[2].length - 1,
        end: cursor,
        query: m[2]
    };
}

// Text after accepting `path` for `mention`: the token becomes `@path ` and
// the cursor goes behind it.
function accept(text, mention, path) {
    const insert = "@" + path + " ";
    const rest = String(text).slice(mention.end).replace(/^ /, "");
    return {
        text: String(text).slice(0, mention.start) + insert + rest,
        cursor: mention.start + insert.length
    };
}

// `path` relative to `root` when it lies inside it.
function relative(path, root) {
    const base = String(root || "").replace(/\/+$/, "") + "/";
    return base.length > 1 && String(path).startsWith(base) ? String(path).slice(base.length) : String(path);
}

// `file://` URIs of a text/uri-list into local paths.
function uriPaths(text) {
    return String(text || "").split("\n").map(l => l.trim()).filter(l => l.startsWith("file://")).map(l => {
        try {
            return decodeURIComponent(l.slice(7));
        } catch (e) {
            return l.slice(7);
        }
    });
}

// What Ctrl+V should additionally attach for a clipboard offering `types`
// (wl-paste --list-types): plain text pastes as text (nothing to attach),
// copied files attach as files, a bare image attaches as an image.
function pasteKind(types) {
    const list = (types || []).map(t => String(t).trim()).filter(t => t);
    if (list.some(t => t.startsWith("text/plain") || t === "UTF8_STRING" || t === "STRING"))
        return "text";
    if (list.indexOf("text/uri-list") >= 0)
        return "files";
    if (list.some(t => t.startsWith("image/")))
        return "image";
    return "none";
}

// Whether `path` is already attached.
function attached(attachments, path) {
    return (attachments || []).some(a => a.path === path);
}
