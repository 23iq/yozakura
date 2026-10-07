.pragma library

// Appearance > Glass: the master amount (+ live preview), the advanced
// curve overrides and the per-surface overrides of `theme.glass`
// (modules/theme/GlassModel.js). -1 = auto / inherit everywhere.
// Entry format: see modules/settings/AGENTS.md.

var sections = [
    {
        "id": "glass",
        "title": "prefs.appearance.section.glass",
        "entries": [
            {
                "key": "theme.glass.enabled",
                "type": "toggle",
                "label": "prefs.glass.enabled",
                "description": "prefs.glass.enabled.desc",
                "keywords": "glass glassy blur transparency translucent frosted acrylic mica liquid see-through solid opaque"
            },
            {
                "key": "theme.glass.amount",
                "type": "custom",
                "component": "GlassAmountEditor",
                "keys": [
                    "theme.glass.amount"
                ],
                "preview": "GlassPreview",
                "visibleWhen": {
                    "key": "theme.glass.enabled",
                    "equals": true
                },
                "label": "prefs.glass.amount",
                "description": "prefs.glass.amount.desc",
                "keywords": "glass amount glassiness blur transparency translucent frosted more less slider"
            }
        ]
    },
    {
        "id": "glassAdvanced",
        "title": "prefs.appearance.section.glass_advanced",
        "collapsible": true,
        "collapsed": true,
        "entries": [
            {
                "key": "theme.glass.advanced.opacity",
                "type": "slider",
                "min": 0.2,
                "max": 1,
                "step": 0.01,
                "specialValues": [
                    {
                        "value": -1,
                        "label": "prefs.glass.auto"
                    }
                ],
                "visibleWhen": {
                    "key": "theme.glass.enabled",
                    "equals": true
                },
                "label": "prefs.glass.opacity",
                "description": "prefs.glass.opacity.desc",
                "keywords": "glass opacity transparency translucent alpha see-through"
            },
            {
                "key": "theme.glass.advanced.tintStrength",
                "type": "slider",
                "min": 0,
                "max": 0.6,
                "step": 0.01,
                "specialValues": [
                    {
                        "value": -1,
                        "label": "prefs.glass.auto"
                    }
                ],
                "visibleWhen": {
                    "key": "theme.glass.enabled",
                    "equals": true
                },
                "label": "prefs.glass.tint_strength",
                "description": "prefs.glass.tint_strength.desc",
                "keywords": "glass tint color accent wash"
            },
            {
                "key": "theme.glass.advanced.borderHighlight",
                "type": "slider",
                "min": 0,
                "max": 1,
                "step": 0.01,
                "specialValues": [
                    {
                        "value": -1,
                        "label": "prefs.glass.auto"
                    }
                ],
                "visibleWhen": {
                    "key": "theme.glass.enabled",
                    "equals": true
                },
                "label": "prefs.glass.border_highlight",
                "description": "prefs.glass.border_highlight.desc",
                "keywords": "glass highlight edge rim light line border shine"
            },
            {
                "key": "theme.glass.tintRole",
                "type": "selector",
                "options": [
                    {
                        "value": "primary",
                        "label": "prefs.glass.role.primary"
                    },
                    {
                        "value": "secondary",
                        "label": "prefs.glass.role.secondary"
                    },
                    {
                        "value": "tertiary",
                        "label": "prefs.glass.role.tertiary"
                    },
                    {
                        "value": "surfaceBright",
                        "label": "prefs.glass.role.surfaceBright"
                    }
                ],
                "visibleWhen": {
                    "key": "theme.glass.enabled",
                    "equals": true
                },
                "label": "prefs.glass.tint_role",
                "description": "prefs.glass.tint_role.desc",
                "keywords": "glass tint color role accent"
            },
            {
                "key": "theme.glass.highlightRole",
                "type": "selector",
                "options": [
                    {
                        "value": "overBackground",
                        "label": "prefs.glass.role.overBackground"
                    },
                    {
                        "value": "primary",
                        "label": "prefs.glass.role.primary"
                    },
                    {
                        "value": "secondary",
                        "label": "prefs.glass.role.secondary"
                    },
                    {
                        "value": "outline",
                        "label": "prefs.glass.role.outline"
                    },
                    {
                        "value": "surfaceBright",
                        "label": "prefs.glass.role.surfaceBright"
                    }
                ],
                "visibleWhen": {
                    "key": "theme.glass.enabled",
                    "equals": true
                },
                "label": "prefs.glass.highlight_role",
                "description": "prefs.glass.highlight_role.desc",
                "keywords": "glass highlight edge color role"
            }
        ]
    },
    {
        "id": "glassSurfaces",
        "title": "prefs.appearance.section.glass_surfaces",
        "collapsible": true,
        "collapsed": true,
        "entries": [
            {
                "id": "theme.glass.surfaces",
                "type": "custom",
                "component": "GlassSurfacesEditor",
                "keys": [
                    "theme.glass.surfaces.windows.amount",
                    "theme.glass.surfaces.terminal.amount",
                    "theme.glass.surfaces.popups.amount",
                    "theme.glass.surfaces.bar.amount",
                    "theme.glass.surfaces.notch.amount",
                    "theme.glass.surfaces.dock.amount",
                    "theme.glass.surfaces.sidebars.amount",
                    "theme.glass.surfaces.lockscreen.amount",
                    "theme.glass.surfaces.settings.amount"
                ],
                "visibleWhen": {
                    "key": "theme.glass.enabled",
                    "equals": true
                },
                "label": "prefs.glass.surfaces",
                "description": "prefs.glass.surfaces.desc",
                "keywords": "glass per surface override windows terminal kitty popups bar panels notch dock sidebar ai center lockscreen settings"
            },
            {
                "key": "theme.glass.surfaces.windows.activeOpacity",
                "type": "slider",
                "min": 0.3,
                "max": 1,
                "step": 0.01,
                "specialValues": [
                    {
                        "value": -1,
                        "label": "prefs.glass.auto"
                    }
                ],
                "visibleWhen": {
                    "key": "theme.glass.enabled",
                    "equals": true
                },
                "label": "prefs.glass.active_opacity",
                "description": "prefs.glass.active_opacity.desc",
                "keywords": "glass window opacity active focused transparent"
            },
            {
                "key": "theme.glass.surfaces.windows.inactiveOpacity",
                "type": "slider",
                "min": 0.3,
                "max": 1,
                "step": 0.01,
                "specialValues": [
                    {
                        "value": -1,
                        "label": "prefs.glass.auto"
                    }
                ],
                "visibleWhen": {
                    "key": "theme.glass.enabled",
                    "equals": true
                },
                "label": "prefs.glass.inactive_opacity",
                "description": "prefs.glass.inactive_opacity.desc",
                "keywords": "glass window opacity inactive unfocused transparent"
            }
        ]
    }
];
