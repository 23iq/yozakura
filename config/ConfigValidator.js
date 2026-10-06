.pragma library
.import "../modules/bar/workspaces/WorkspaceNumerals.js" as WorkspaceNumerals
.import "../modules/desktop/clockstyles/ClockStyleRegistry.js" as ClockStyles
.import "../modules/lockscreen/styles/LockStyleRegistry.js" as LockStyles
.import "meta/Enums.js" as Enums
.import "meta/KeyAliases.js" as KeyAliases

function clone(obj) {
    return JSON.parse(JSON.stringify(obj));
}

// Key-alias migration (config/meta/KeyAliases.js) over the raw, not yet
// validated, domain objects {domain: object|null}; mutates them. Copies
// each present `from` value to an absent `to` (through `transform`), then
// removes `from`. A target domain without a file (null) keeps the source
// for a later run. Returns the names of the changed domains.
function migrateAliases(raws, list) {
    var changed = [];
    function mark(d) {
        if (changed.indexOf(d) === -1)
            changed.push(d);
    }
    (list || KeyAliases.aliases).forEach(function (a) {
        var from = String(a.from).split(".");
        var to = String(a.to).split(".");
        var src = raws[from[0]];
        var dst = raws[to[0]];
        if (!isObject(src) || !isObject(dst))
            return;
        var parent = walk(src, from.slice(1, -1), false);
        var leaf = from[from.length - 1];
        if (!parent || !(leaf in parent))
            return;
        var value = parent[leaf];
        delete parent[leaf];
        mark(from[0]);
        var target = walk(dst, to.slice(1, -1), false);
        if (target && target[to[to.length - 1]] !== undefined)
            return;
        try {
            value = a.transform ? a.transform(value) : value;
        } catch (e) {
            console.warn("config alias " + a.from + " -> " + a.to + ": " + e);
            return;
        }
        walk(dst, to.slice(1, -1), true)[to[to.length - 1]] = value;
        mark(to[0]);
    });
    return changed;
}

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// The object at `path` under `obj`; `create` adds missing levels.
function walk(obj, path, create) {
    var cur = obj;
    for (var i = 0; i < path.length; i++) {
        if (!isObject(cur[path[i]])) {
            if (!create)
                return null;
            cur[path[i]] = {};
        }
        cur = cur[path[i]];
    }
    return cur;
}

function validate(current, defaults, keyName) {
    if (current === undefined || current === null) {
        return clone(defaults);
    }

    if (Array.isArray(defaults)) {
        if (!Array.isArray(current)) {
            return clone(defaults);
        }
        return current;
    }

    if (typeof defaults === 'object') {
        if (typeof current !== 'object' || Array.isArray(current)) {
            return clone(defaults);
        }

        var result = {};
        for (var key in defaults) {
            result[key] = validate(current[key], defaults[key], key);
        }
        return result;
    }

    if (typeof current !== typeof defaults) {
        return defaults;
    }

    if (keyName === "depthClockStyle" && !ClockStyles.has(current)) {
        return defaults;
    }

    // lockscreen.style / .tone / .blur (-1 = the style's own blur)
    if (keyName === "style" && defaults === LockStyles.DEFAULT_ID && !LockStyles.has(current)) {
        return defaults;
    }

    if (keyName === "tone" && LockStyles.TONES.indexOf(current) === -1) {
        return defaults;
    }

    if (keyName === "blur" && defaults === LockStyles.BLUR_STYLE_DEFAULT && !(current === -1 || (current >= 0 && current <= 1))) {
        return defaults;
    }

    if (keyName === "depthClockPosition" && Enums.CLOCK_POSITIONS.indexOf(current) === -1) {
        return defaults;
    }

    if (keyName === "depthClockInk" && Enums.CLOCK_INKS.indexOf(current) === -1) {
        return defaults;
    }

    if (keyName === "widgetVariant" && Enums.WIDGET_VARIANTS.indexOf(current) === -1) {
        return defaults;
    }

    if (keyName === "activation" && Enums.VOICE_ACTIVATIONS.indexOf(current) === -1) {
        return defaults;
    }

    if (keyName === "typingMethod" && Enums.VOICE_TYPING_METHODS.indexOf(current) === -1) {
        return defaults;
    }

    if (keyName === "vadSensitivity" && (current < 0 || current > 1)) {
        return defaults;
    }

    if (keyName === "gradientType") {
        if (Enums.GRADIENT_TYPES.indexOf(current) === -1) {
            return defaults;
        }
    }

    if (keyName === "wallpaperTransition") {
        if (Enums.WALLPAPER_TRANSITIONS.indexOf(current) === -1) {
            return defaults;
        }
    }

    if (keyName === "style" && typeof defaults === "string" && (defaults === "classic" || defaults === "islands")) {
        if (Enums.BAR_STYLES.indexOf(current) === -1) {
            return defaults;
        }
    }

    if (keyName === "numeralStyle" && !WorkspaceNumerals.isValid(current)) {
        return defaults;
    }

    if (keyName === "surfaceEffect" && Enums.surfaceEffects().indexOf(current) === -1) {
        return defaults;
    }

    if (keyName === "indicatorStyle" && Enums.indicatorStyles().indexOf(current) === -1) {
        return defaults;
    }

    // bar.activities.maxVisible: at least one island, never a wall of them
    if (keyName === "maxVisible" && typeof defaults === "number") {
        if (!isFinite(current)) {
            return defaults;
        }
        return Math.max(1, Math.min(8, Math.round(current)));
    }

    // notch.expandOn
    if (keyName === "expandOn" && defaults === "hover") {
        if (Enums.EXPAND_ON.indexOf(current) === -1) {
            return defaults;
        }
    }

    // bar.activities.presentation
    if (keyName === "presentation" && defaults === "notch") {
        if (Enums.ACTIVITY_PRESENTATIONS.indexOf(current) === -1) {
            return defaults;
        }
    }

    if (keyName === "noMediaDisplay") {
        if (Enums.NO_MEDIA_DISPLAY.indexOf(current) === -1) {
            return defaults;
        }
    }

    return current;
}
