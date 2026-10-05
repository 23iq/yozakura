.pragma library
.import "glass.js" as Glass

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
        },
        {
            "id": "motion",
            "title": "prefs.appearance.section.motion",
            "entries": [
                {
                    "key": "theme.animDuration",
                    "type": "slider",
                    "min": 0,
                    "max": 1000,
                    "step": 25,
                    "unit": "ms",
                    "specialValues": [
                        {
                            "value": 0,
                            "label": "prefs.common.off"
                        }
                    ],
                    "preview": "MotionPreview",
                    "label": "settings.theme.animation",
                    "description": "prefs.appearance.anim.desc",
                    "keywords": "animation speed duration fast slow motion reduce"
                },
                {
                    "key": "theme.paletteTransitionDuration",
                    "type": "slider",
                    "min": 0,
                    "max": 1500,
                    "step": 50,
                    "unit": "ms",
                    "specialValues": [
                        {
                            "value": 0,
                            "label": "prefs.common.instant"
                        }
                    ],
                    "preview": "PaletteFadePreview",
                    "label": "settings.theme.palette_transition",
                    "description": "prefs.appearance.palette_transition.desc",
                    "keywords": "palette colors crossfade fade wallpaper change transition"
                }
            ]
        }
    ]
};

// Glass sections (schema/glass.js) go right after "shape".
category.sections.splice(category.sections.findIndex(s => s.id === "shape") + 1, 0, ...Glass.sections);
