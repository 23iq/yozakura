.pragma library
.import "clipboard_utils.js" as ClipboardUtils

// Pure helpers of the clipboard tab: row geometry, list filtering/sync and
// the texts of rows, previews and metadata. No QML state in here.

var ROW_HEIGHT = 48;
var OPTION_HEIGHT = 36;
var MAX_VISIBLE_OPTIONS = 5;

var MONTH_KEYS = ["calendar.month.january", "calendar.month.february", "calendar.month.march", "calendar.month.april", "calendar.month.may", "calendar.month.june", "calendar.month.july", "calendar.month.august", "calendar.month.september", "calendar.month.october", "calendar.month.november", "calendar.month.december"];

// Files, images and URLs get an extra "Open" option.
function canOpen(item) {
    return !!(item && (item.isFile || item.isImage || ClipboardUtils.isUrl(item.preview)));
}

// Copy, (Open), Pin, Alias, Delete
function optionsCount(item) {
    return canOpen(item) ? 5 : 4;
}

function optionsListHeight(item) {
    return OPTION_HEIGHT * Math.min(MAX_VISIBLE_OPTIONS, optionsCount(item));
}

// Height of a row: collapsed, or expanded with its options list.
function rowHeight(item, expanded) {
    if (!expanded)
        return ROW_HEIGHT;
    return ROW_HEIGHT + 4 + optionsListHeight(item) + 8;
}

// Y of row `index` given which row (if any) is expanded. `itemAt(i)` returns
// the item data of row i; `expandable` is false in delete/alias mode.
function rowY(index, count, expandedIndex, expandable, itemAt) {
    var y = 0;
    for (var i = 0; i < index && i < count; i++)
        y += rowHeight(i === expandedIndex && expandable ? itemAt(i) : null, i === expandedIndex && expandable);
    return y;
}

// New contentY that brings [top, top + height) into the viewport, or -1
// when it is already fully visible.
function scrollToShow(top, height, contentY, viewHeight, maxContentY) {
    if (top < contentY)
        return top;
    if (top + height > contentY + viewHeight)
        return maxContentY === undefined ? top + height - viewHeight : Math.min(top + height - viewHeight, maxContentY);
    return -1;
}

// Items whose content or alias contains `search` (case-insensitive).
function filterItems(items, search) {
    var needle = (search || "").toLowerCase();
    var out = [];
    for (var i = 0; i < items.length; i++) {
        var item = items[i];
        var content = item.preview || "";
        var alias = item.alias || "";
        if (needle.length === 0 || content.toLowerCase().includes(needle) || alias.toLowerCase().includes(needle))
            out.push(item);
    }
    return out;
}

// Sync a ListModel of {itemId, itemData} to `items` with minimal changes
// (update in place, move, insert, append, trim) so delegates survive.
function syncModel(model, items) {
    var modelIndex = 0;
    for (var newIndex = 0; newIndex < items.length; newIndex++) {
        var newItem = items[newIndex];
        var newItemId = newItem.id;
        if (modelIndex < model.count) {
            var current = model.get(modelIndex);
            if (current.itemId === newItemId) {
                if (current.itemData !== newItem)
                    model.set(modelIndex, {
                        itemData: newItem
                    });
            } else {
                var foundLaterIndex = -1;
                for (var j = modelIndex + 1; j < model.count; j++) {
                    if (model.get(j).itemId === newItemId) {
                        foundLaterIndex = j;
                        break;
                    }
                }
                if (foundLaterIndex !== -1) {
                    model.move(foundLaterIndex, modelIndex, 1);
                    model.set(modelIndex, {
                        itemData: newItem
                    });
                } else {
                    model.insert(modelIndex, {
                        itemId: newItemId,
                        itemData: newItem
                    });
                }
            }
        } else {
            model.append({
                itemId: newItemId,
                itemData: newItem
            });
        }
        modelIndex++;
    }
    if (modelIndex < model.count)
        model.remove(modelIndex, model.count - modelIndex);
}

function indexOfId(items, id) {
    for (var i = 0; i < items.length; i++) {
        if (items[i].id === id)
            return i;
    }
    return -1;
}

function singleLine(text) {
    return text.replace(/\n/g, ' ').replace(/\r/g, '');
}

// Text of a list row.
function rowText(item, inDeleteMode) {
    if (inDeleteMode) {
        var preview = singleLine(item.alias || item.preview || "");
        return "Delete \"" + preview.substring(0, 20) + (preview.length > 20 ? '...' : '') + "\"?";
    }
    if (item.isImage)
        return item.alias || "Image";
    return singleLine(item.alias || item.preview || "");
}

// "just now", "5 min ago", ... or "<Month> <day>, <year>"; `t` is I18n.t.
function relativeTime(createdAt, now, t) {
    if (!createdAt)
        return "";
    var date = new Date(createdAt);
    var diffMins = Math.floor(Math.floor((now - date) / 1000) / 60);
    var diffHours = Math.floor(diffMins / 60);
    var diffDays = Math.floor(diffHours / 24);
    if (diffMins < 1)
        return t("clipboard.just_now");
    if (diffMins < 60)
        return t("clipboard.min_ago", diffMins);
    if (diffHours < 24)
        return t("clipboard.hours_ago", diffHours);
    if (diffDays < 7)
        return t("clipboard.days_ago", diffDays);
    return t(MONTH_KEYS[date.getMonth()]) + " " + date.getDate() + ", " + date.getFullYear();
}

// "<Month> <day>, <year> h:mm:ss AM/PM"
function fullDate(createdAt, t) {
    var date = new Date(createdAt);
    var h = date.getHours();
    var m = String(date.getMinutes()).padStart(2, "0");
    var s = String(date.getSeconds()).padStart(2, "0");
    var ap = h >= 12 ? "PM" : "AM";
    var h12 = h % 12 || 12;
    return t(MONTH_KEYS[date.getMonth()]) + " " + date.getDate() + ", " + date.getFullYear() + " " + h12 + ":" + m + ":" + s + " " + ap;
}

function formatSize(bytes) {
    bytes = bytes || 0;
    if (bytes < 1024)
        return bytes + " B";
    if (bytes < 1024 * 1024)
        return (bytes / 1024).toFixed(1) + " KB";
    return (bytes / (1024 * 1024)).toFixed(1) + " MB";
}

// First and last 8 characters of a long hash.
function shortHash(hash) {
    if (!hash)
        return "N/A";
    if (hash.length > 16)
        return hash.substring(0, 8) + "..." + hash.substring(hash.length - 8);
    return hash;
}

function filePathFromUri(content) {
    if (!content || !content.startsWith("file://"))
        return "";
    return decodeURIComponent(content.substring(7).trim());
}

function isImagePath(filePath) {
    if (!filePath)
        return false;
    var ext = filePath.split('.').pop().toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico'].indexOf(ext) !== -1;
}

// GIF by MIME type, or a file URI ending in .gif.
function isGif(item, content) {
    if (!item)
        return false;
    if (item.mime === "image/gif")
        return true;
    if (item.isFile) {
        var filePath = filePathFromUri(content);
        if (filePath)
            return filePath.split('.').pop().toLowerCase() === "gif";
    }
    return false;
}

// File name / parent directory of a file:// URI (URL-decoded).
function uriFileName(content) {
    if (content.startsWith("file://"))
        return decodeURIComponent(content.substring(7).trim().split('/').pop());
    return content;
}

function uriDirectory(content) {
    if (!content.startsWith("file://"))
        return "";
    var parts = content.substring(7).trim().split('/');
    parts.pop();
    return parts.map(function (part) {
        return decodeURIComponent(part);
    }).join('/');
}

// Host of a URL, or its first 40 characters when it does not parse.
function hostLabel(url) {
    try {
        return new URL(url.trim()).hostname;
    } catch (e) {
        return url.substring(0, 40) + (url.length > 40 ? "..." : "");
    }
}

// Drag-and-drop MIME data of an item: files as URI list, materialized
// images as file URI, anything else as plain text.
function dragMimeData(item, content, imagePath) {
    if (!item)
        return {};
    if (item.isFile)
        return {
            "text/uri-list": content
        };
    if (item.isImage && imagePath)
        return {
            "text/uri-list": "file://" + imagePath
        };
    return {
        "text/plain": content
    };
}
