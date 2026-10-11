.pragma library
.import "KeyNames.js" as KeyNames

// What the running compositor can and cannot do with binds, and the notes
// the editor shows for binds it left out (pure; tests/keybinds-support.test.cjs).

// Recording holds the compositor's binds off through a submap (see
// KeybindsStore): only Hyprland has one the shell can enter.
function canSuppress(compositor) {
    return compositor === "hyprland";
}

// Native (non-shell) binds: hyprctl on Hyprland, `yozd config list-binds`
// (the compositor's config files) on niri and MangoWC.
function nativeSource(compositor) {
    return compositor === "hyprland" ? "hyprctl" : (compositor === "niri" || compositor === "mango" ? "yozd" : "");
}

// Binds the generator drops are only known for niri.
function reportsSkipped(compositor) {
    return compositor === "niri";
}

// yozd `Config.ListBinds` entries as hyprctl-like objects (BindModel.nativeBinds).
function fromListBinds(list) {
    var out = [];
    (Array.isArray(list) ? list : []).forEach(function (b) {
        if (!b || !b.key || b.mouse)
            return;
        out.push({
            "modifiers": b.modifiers || [],
            "key": b.key,
            "submap": b.submap || "",
            "release": !!b.release,
            "dispatcher": b.dispatcher || "",
            "arg": b.arg || "",
            "has_description": !!b.description,
            "description": b.description || ""
        });
    });
    return out;
}

// Duplicates are already shown as conflicts between rows.
function isDuplicateReason(reason) {
    return String(reason || "").indexOf("same key combo") === 0;
}

// yozd `Config.SkippedBinds` text -> {comboId: reason}.
function parseSkipped(text) {
    var list;
    try {
        list = JSON.parse(text);
    } catch (e) {
        return {};
    }
    var out = {};
    (Array.isArray(list) ? list : []).forEach(function (s) {
        if (!s || !s.key || isDuplicateReason(s.reason))
            return;
        var id = KeyNames.comboId(s.modifiers || [], s.key);
        if (id)
            out[id] = String(s.reason || "");
    });
    return out;
}

// Reason one of the row's key combos was left out, or "".
function noteFor(keys, skipped) {
    var list = keys || [];
    for (var i = 0; i < list.length; i++) {
        var id = KeyNames.comboId(list[i].modifiers || [], list[i].key);
        if (id && skipped[id])
            return skipped[id];
    }
    return "";
}
