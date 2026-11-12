.pragma library
.import "../modules/bar/workspaces/WorkspaceNumerals.js" as WorkspaceNumerals
.import "../modules/desktop/clockstyles/ClockStyleRegistry.js" as ClockStyles
.import "../modules/lockscreen/styles/LockStyleRegistry.js" as LockStyles
.import "meta/Enums.js" as Enums
.import "meta/KeyAliases.js" as KeyAliases
.import "meta/AdapterTypes.js" as AdapterTypes
.import "JsonUtil.js" as JsonUtil

// Key-alias migration (config/meta/KeyAliases.js) over the raw, not yet
// validated, domain objects {domain: object|null}; mutates them. Copies
// each present `from` value to an absent `to` (through `transform`; an
// undefined result writes nothing), then removes `from`. A `to` that holds
// one of the alias's `replaces` values (its untouched default) counts as
// absent. A target domain that could not be read (null) keeps the source
// untouched; AliasGate supplies {} for files confirmed missing. Returns the names of the changed domains.
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
        var current = target ? target[to[to.length - 1]] : undefined;
        if (current !== undefined && (a.replaces || []).indexOf(current) === -1)
            return;
        try {
            value = a.transform ? a.transform(value) : value;
        } catch (e) {
            console.warn("config alias " + a.from + " -> " + a.to + ": " + e);
            return;
        }
        if (value === undefined)
            return;
        walk(dst, to.slice(1, -1), true)[to[to.length - 1]] = value;
        mark(to[0]);
    });
    return changed;
}

// `over` laid onto a copy of `base`: objects merge, anything else replaces.
function overlay(base, over) {
    if (!isObject(over))
        return JsonUtil.clone(over);
    var out = isObject(base) ? JsonUtil.clone(base) : {};
    for (var k in over) {
        if (!ownKey(over, k))
            continue;
        out[k] = isObject(over[k]) ? overlay(hasOwn(out, k) ? out[k] : undefined, over[k]) : JsonUtil.clone(over[k]);
    }
    return out;
}

function isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

function hasOwn(obj, key) {
    return Object.prototype.hasOwnProperty.call(obj, key);
}

// A key of `obj` that may be copied into a plain object: its own, and never
// "__proto__" (JSON.parse makes it an own key; assigning it would replace
// the prototype of the result instead of adding a key).
function ownKey(obj, key) {
    return key !== "__proto__" && hasOwn(obj, key);
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

// Dotted paths of a domain's free-form maps ("var" in meta/AdapterTypes.js):
// their keys are not config keys, so the user's own keys are kept.
function freeFormPaths(domain) {
    var types = (AdapterTypes.types || {})[domain] || {};
    return Object.keys(types).filter(function (p) {
        return types[p] === "var";
    });
}

// validate() for a whole domain file: like validate(), but inside the
// domain's free-form maps the keys the defaults do not list are kept
// (cloned) instead of dropped. Keys the defaults list are validated as
// everywhere else.
function validateDomain(current, defaults, domain) {
    return validateNode(current, defaults, undefined, "", false, freeFormPaths(domain));
}

function validate(current, defaults, keyName) {
    return validateNode(current, defaults, keyName, "", false, []);
}

// `path`: dotted path of this value inside the domain; `free`: it is (or
// lies inside) a free-form map; `freePaths`: the domain's free-form paths.
function validateNode(current, defaults, keyName, path, free, freePaths) {
    if (current === undefined || current === null) {
        return JsonUtil.clone(defaults);
    }

    if (Array.isArray(defaults)) {
        if (!Array.isArray(current)) {
            return JsonUtil.clone(defaults);
        }
        return current;
    }

    if (typeof defaults === 'object') {
        if (typeof current !== 'object' || Array.isArray(current)) {
            return JsonUtil.clone(defaults);
        }

        var result = {};
        for (var key in defaults) {
            var childPath = path ? path + "." + key : key;
            var childFree = free || freePaths.indexOf(childPath) !== -1;
            result[key] = validateNode(current[key], defaults[key], key, childPath, childFree, freePaths);
        }
        if (free) {
            for (var extra in current) {
                if (ownKey(current, extra) && !hasOwn(defaults, extra) && current[extra] !== undefined)
                    result[extra] = JsonUtil.clone(current[extra]);
            }
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

    if (keyName === "branchBlossom" && Enums.branchBlossoms().indexOf(current) === -1) {
        return defaults;
    }

    if (keyName === "branchColor" && Enums.COLOR_ROLES.indexOf(current) === -1) {
        return defaults;
    }

    // notch.liveActivities.maxVisible: at least one island, never a wall of them
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

    // notch.liveActivities.presentation
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
