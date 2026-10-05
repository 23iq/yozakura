.pragma library
.import "../modules/bar/workspaces/WorkspaceNumerals.js" as WorkspaceNumerals
.import "../modules/desktop/clockstyles/ClockStyleRegistry.js" as ClockStyles
.import "../modules/lockscreen/styles/LockStyleRegistry.js" as LockStyles
.import "meta/Enums.js" as Enums

function clone(obj) {
    return JSON.parse(JSON.stringify(obj));
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
