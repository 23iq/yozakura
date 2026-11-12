.pragma library

// A downloaded notification image as a data: URL (Notifications.qml,
// cacheImageAsBase64). Unit tested in tests/notification-image.test.cjs.

// Images above this are not cached: the notification keeps its URL (cutting
// the bytes would store a corrupt image).
var MAX_BYTES = 1024 * 1024;
// Bytes per btoa() call: a multiple of 3, so the chunks' base64 concatenate
// into the base64 of the whole, and small enough for Function.apply.
var CHUNK = 3 * 1024;

function mimeFor(url) {
    var lower = String(url || "").toLowerCase();
    if (lower.includes(".jpg") || lower.includes(".jpeg"))
        return "image/jpeg";
    if (lower.includes(".gif"))
        return "image/gif";
    if (lower.includes(".webp"))
        return "image/webp";
    return "image/png";
}

// `bytes` (Uint8Array) as a data: URL typed after `url`, or "" when there is
// nothing to cache (empty, or larger than MAX_BYTES). `btoa` encodes a binary
// string.
function dataUrl(bytes, url, btoa) {
    if (!bytes || bytes.length === 0 || bytes.length > MAX_BYTES)
        return "";
    var parts = [];
    for (var i = 0; i < bytes.length; i += CHUNK)
        parts.push(btoa(String.fromCharCode.apply(null, bytes.subarray(i, i + CHUNK))));
    return "data:" + mimeFor(url) + ";base64," + parts.join("");
}
