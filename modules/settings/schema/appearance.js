.pragma library
.import "glass.js" as Glass
.import "motion.js" as Motion
.import "surfaces.js" as Surfaces

// Appearance: theme mode, palette, typography, shape, glass and motion.
// Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "appearance",
    "icon": "paintBrush",
    "title": "prefs.cat.appearance",
    "description": "prefs.cat.appearance.desc",
    "keywords": "theme look style colors fonts dark light",
    "sections": [
        {
            "id": "mode",
            "title": "prefs.appearance.section.mode",
            "entries": [
                {
                    "id": "theme.mode",
                    "type": "custom",
                    "component": "ThemeModeCards",
                    "keys": ["theme.lightMode", "theme.oledMode"],
                    "label": "prefs.appearance.mode",
                    "description": "prefs.appearance.mode.desc",
                    "keywords": "dark light oled amoled black night day"
                }
            ]
        },
        {
            "id": "palette",
            "title": "prefs.appearance.section.palette",
            "entries": [
                {
                    "id": "wallpaper.matugenScheme",
                    "type": "custom",
                    "component": "SchemeGallery",
                    "keys": ["wallpaper.matugenScheme", "wallpaper.activeColorPreset"],
                    "label": "prefs.appearance.scheme",
                    "description": "prefs.appearance.scheme.desc",
                    "keywords": "matugen palette scheme material you colors tonal vibrant preset"
                },
                {
                    "key": "theme.tintIcons",
                    "type": "toggle",
                    "label": "settings.theme.tint_icons",
                    "description": "prefs.appearance.tint_icons.desc",
                    "keywords": "icons monochrome tint color"
                }
            ]
        },
        {
            "id": "typography",
            "title": "prefs.appearance.section.typography",
            "entries": [
                {
                    "key": "theme.font",
                    "type": "font",
                    "keys": ["theme.font", "theme.fontSize"],
                    "sizeKey": "theme.fontSize",
                    "label": "settings.theme.ui_font",
                    "description": "prefs.appearance.ui_font.desc",
                    "keywords": "font typeface family text size typography"
                },
                {
                    "key": "theme.monoFont",
                    "type": "font",
                    "keys": ["theme.monoFont", "theme.monoFontSize"],
                    "sizeKey": "theme.monoFontSize",
                    "monospace": true,
                    "label": "settings.theme.mono_font",
                    "description": "prefs.appearance.mono_font.desc",
                    "keywords": "monospace code terminal font typeface"
                }
            ]
        },
        {
            "id": "shape",
            "title": "prefs.appearance.section.shape",
            "entries": [
                {
                    "key": "theme.roundness",
                    "type": "slider",
                    "min": 0,
                    "max": 20,
                    "step": 1,
                    "unit": "px",
                    "preview": "RoundnessPreview",
                    "label": "settings.theme.roundness",
                    "description": "prefs.appearance.roundness.desc",
                    "keywords": "radius corners rounded square shape"
                },
                {
                    "key": "theme.enableCorners",
                    "type": "toggle",
                    "label": "settings.theme.enable_corners",
                    "description": "prefs.appearance.corners.desc",
                    "keywords": "screen corners rounded display edges"
                },
                {
                    "key": "theme.shape.corners",
                    "type": "selector",
                    "label": "prefs.appearance.corner_style",
                    "description": "prefs.appearance.corner_style.desc",
                    "keywords": "corner style shape squircle cut chamfer tab rounded",
                    "options": [
                        { "value": "round", "label": "prefs.appearance.corner_style.round" },
                        { "value": "squircle", "label": "prefs.appearance.corner_style.squircle" },
                        { "value": "cut", "label": "prefs.appearance.corner_style.cut" },
                        { "value": "tab", "label": "prefs.appearance.corner_style.tab" }
                    ]
                },
                {
                    "key": "theme.shape.popupCorners",
                    "type": "selector",
                    "label": "prefs.appearance.popup_corners",
                    "description": "prefs.appearance.popup_corners.desc",
                    "keywords": "popup menu corner style shape squircle cut tab",
                    "options": [
                        { "value": "", "label": "prefs.appearance.popup_corners.inherit" },
                        { "value": "round", "label": "prefs.appearance.corner_style.round" },
                        { "value": "squircle", "label": "prefs.appearance.corner_style.squircle" },
                        { "value": "cut", "label": "prefs.appearance.corner_style.cut" },
                        { "value": "tab", "label": "prefs.appearance.corner_style.tab" }
                    ]
                },
                {
                    "key": "theme.shape.cutSize",
                    "type": "slider",
                    "min": 2,
                    "max": 32,
                    "step": 1,
                    "unit": "px",
                    "visibleWhen": { "any": [{ "key": "theme.shape.corners", "equals": "cut" }, { "key": "theme.shape.popupCorners", "equals": "cut" }] },
                    "label": "prefs.appearance.cut_size",
                    "description": "prefs.appearance.cut_size.desc",
                    "keywords": "cut chamfer size corner"
                },
                {
                    "key": "compositor.syncRoundness",
                    "advanced": true,
                    "type": "toggle",
                    "label": "prefs.windows.sync_rounding",
                    "description": "prefs.windows.sync_rounding.desc",
                    "keywords": "sync rounding roundness corners shell theme"
                },
                {
                    "key": "compositor.rounding",
                    "advanced": true,
                    "type": "slider",
                    "min": 0,
                    "max": 40,
                    "step": 1,
                    "unit": "px",
                    "visibleWhen": {
                        "key": "compositor.syncRoundness",
                    "advanced": true,
                        "equals": false
                    },
                    "label": "prefs.windows.rounding",
                    "description": "prefs.windows.rounding.desc",
                    "keywords": "rounding radius corners round"
                }
            ]
        },
        {
            "id": "effects",
            "title": "prefs.appearance.section.effects",
            "entries": [
                {
                    "key": "theme.surfaceEffect",
                    "type": "custom",
                    "component": "SurfaceEffectCards",
                    "label": "prefs.effects.effect",
                    "description": "prefs.effects.effect.desc",
                    "keywords": "surface effect texture crt scanlines retro phosphor vignette ink sumi-e paper grain brush"
                },
                {
                    "key": "theme.surfaceEffectOptions.intensity",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "visibleWhen": {
                        "key": "theme.surfaceEffect",
                        "notEquals": "none"
                    },
                    "label": "prefs.effects.intensity",
                    "description": "prefs.effects.intensity.desc",
                    "keywords": "effect intensity strength amount"
                },
                {
                    "key": "theme.surfaceEffectOptions.flicker",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "theme.surfaceEffect",
                        "equals": "crt"
                    },
                    "label": "prefs.effects.flicker",
                    "description": "prefs.effects.flicker.desc",
                    "keywords": "crt flicker power on phosphor"
                },
                {
                    "key": "theme.surfaceEffectOptions.grain",
                    "type": "slider",
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "visibleWhen": {
                        "key": "theme.surfaceEffect",
                        "equals": "ink"
                    },
                    "label": "prefs.effects.grain",
                    "description": "prefs.effects.grain.desc",
                    "keywords": "ink paper grain texture rice paper"
                },
                {
                    "key": "theme.surfaceEffectOptions.brushHighlights",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "theme.surfaceEffect",
                        "equals": "ink"
                    },
                    "label": "prefs.effects.brush_highlights",
                    "description": "prefs.effects.brush_highlights.desc",
                    "keywords": "ink brush stroke highlight selection focus sumi-e"
                }
            ]
        }
    ]
};

// Glass sections (schema/glass.js) go right after "shape".
category.sections.splice(category.sections.findIndex(s => s.id === "shape") + 1, 0, ...Glass.sections);

// Surface roles and the shell shadow (schema/surfaces.js), then Motion
// (schema/motion.js: profile, speed, shell timing) close the page.
category.sections.push(...Surfaces.sections);
category.sections.push(...Motion.sections);
