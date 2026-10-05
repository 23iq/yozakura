.pragma library

// Desktop & Clock: desktop icons, the depth clock, desktop widgets and the
// overview wallpaper blur. Entry format: see modules/settings/AGENTS.md.

// Same values as ClockStyleRegistry.INKS / WidgetRegistry.VARIANTS
// (tests/desktop-widgets.test.cjs keeps them in sync); spelled out so the
// label keys stay greppable.
var INK_OPTIONS = [
    {
        "value": "auto",
        "label": "prefs.desktop.ink.auto"
    },
    {
        "value": "primary",
        "label": "prefs.desktop.ink.primary"
    },
    {
        "value": "secondary",
        "label": "prefs.desktop.ink.secondary"
    },
    {
        "value": "tertiary",
        "label": "prefs.desktop.ink.tertiary"
    },
    {
        "value": "primaryFixed",
        "label": "prefs.desktop.ink.primaryFixed"
    },
    {
        "value": "secondaryFixed",
        "label": "prefs.desktop.ink.secondaryFixed"
    },
    {
        "value": "tertiaryFixed",
        "label": "prefs.desktop.ink.tertiaryFixed"
    },
    {
        "value": "overBackground",
        "label": "prefs.desktop.ink.overBackground"
    },
    {
        "value": "background",
        "label": "prefs.desktop.ink.background"
    }
];

var VARIANT_OPTIONS = [
    {
        "value": "pane",
        "label": "prefs.desktop.widget_variant.pane"
    },
    {
        "value": "common",
        "label": "prefs.desktop.widget_variant.common"
    },
    {
        "value": "popup",
        "label": "prefs.desktop.widget_variant.popup"
    },
    {
        "value": "internalbg",
        "label": "prefs.desktop.widget_variant.internalbg"
    },
    {
        "value": "bg",
        "label": "prefs.desktop.widget_variant.bg"
    }
];

var category = {
    "id": "desktop",
    "icon": "monitor",
    "title": "prefs.cat.desktop",
    "description": "prefs.cat.desktop.desc",
    "keywords": "desktop icons clock depth wallpaper widgets",
    "sections": [
        {
            "id": "clock",
            "title": "prefs.desktop.section.clock",
            "entries": [
                {
                    "key": "desktop.depthClock",
                    "type": "toggle",
                    "label": "prefs.desktop.depth_clock",
                    "description": "prefs.desktop.depth_clock.desc",
                    "keywords": "clock time wallpaper depth subject behind big widget"
                },
                {
                    "key": "desktop.depthClockStyle",
                    "type": "custom",
                    "component": "ClockStyleGallery",
                    "visibleWhen": {
                        "key": "desktop.depthClock",
                        "equals": true
                    },
                    "label": "prefs.desktop.depth_clock_style",
                    "description": "prefs.desktop.depth_clock_style.desc",
                    "keywords": "clock style yozakura poster kanji mincho look gallery"
                },
                {
                    "key": "desktop.depthClockPosition",
                    "type": "selector",
                    "options": [
                        {
                            "value": "auto",
                            "label": "common.auto",
                            "icon": "magicWand"
                        },
                        {
                            "value": "left",
                            "label": "shell.desktop.depth_clock_left",
                            "icon": "alignLeft"
                        },
                        {
                            "value": "right",
                            "label": "shell.desktop.depth_clock_right",
                            "icon": "alignRight"
                        }
                    ],
                    "visibleWhen": {
                        "key": "desktop.depthClock",
                        "equals": true
                    },
                    "label": "prefs.desktop.depth_clock_position",
                    "description": "prefs.desktop.depth_clock_position.desc",
                    "keywords": "clock side left right auto placement"
                },
                {
                    "key": "desktop.depthClockInk",
                    "type": "custom",
                    "component": "ColorRoleSwatches",
                    "options": INK_OPTIONS,
                    "visibleWhen": {
                        "key": "desktop.depthClock",
                        "equals": true
                    },
                    "label": "prefs.desktop.depth_clock_ink",
                    "description": "prefs.desktop.depth_clock_ink.desc",
                    "keywords": "clock colour color ink palette role accent"
                },
                {
                    "key": "desktop.depthClockVideo",
                    "type": "toggle",
                    "preview": "DepthMatteStatus",
                    "visibleWhen": {
                        "key": "desktop.depthClock",
                        "equals": true
                    },
                    "label": "prefs.desktop.depth_clock_video",
                    "description": "prefs.desktop.depth_clock_video.desc",
                    "keywords": "clock video animated live matte moving subject"
                }
            ]
        },
        {
            "id": "widgets",
            "title": "prefs.desktop.section.widgets",
            "entries": [
                {
                    "key": "desktop.widgetsEnabled",
                    "type": "toggle",
                    "label": "prefs.desktop.widgets_enabled",
                    "description": "prefs.desktop.widgets_enabled.desc",
                    "keywords": "widgets desktop show hide"
                },
                {
                    "key": "desktop.widgets",
                    "type": "custom",
                    "component": "DesktopWidgetsEditor",
                    "visibleWhen": {
                        "key": "desktop.widgetsEnabled",
                        "equals": true
                    },
                    "label": "prefs.desktop.widgets",
                    "description": "prefs.desktop.widgets.desc",
                    "keywords": "widgets add remove media music calendar events system cpu ram gpu network note sticky weather arrange edit drag"
                },
                {
                    "key": "desktop.widgetVariant",
                    "type": "selector",
                    "options": VARIANT_OPTIONS,
                    "visibleWhen": {
                        "key": "desktop.widgetsEnabled",
                        "equals": true
                    },
                    "label": "prefs.desktop.widget_variant",
                    "description": "prefs.desktop.widget_variant.desc",
                    "keywords": "widget style surface glass background card pane"
                },
                {
                    "key": "desktop.widgetGrid",
                    "type": "slider",
                    "min": 0,
                    "max": 96,
                    "step": 4,
                    "unit": "px",
                    "specialValues": [
                        {
                            "value": 0,
                            "label": "prefs.common.off"
                        }
                    ],
                    "visibleWhen": {
                        "key": "desktop.widgetsEnabled",
                        "equals": true
                    },
                    "label": "prefs.desktop.widget_grid",
                    "description": "prefs.desktop.widget_grid.desc",
                    "keywords": "snap grid align spacing move resize"
                }
            ]
        },
        {
            "id": "icons",
            "title": "prefs.desktop.section.icons",
            "entries": [
                {
                    "key": "desktop.enabled",
                    "type": "toggle",
                    "label": "prefs.desktop.icons",
                    "description": "prefs.desktop.icons.desc",
                    "keywords": "desktop icons files show hide"
                },
                {
                    "key": "desktop.iconSize",
                    "type": "slider",
                    "min": 16,
                    "max": 128,
                    "step": 4,
                    "unit": "px",
                    "visibleWhen": {
                        "key": "desktop.enabled",
                        "equals": true
                    },
                    "label": "prefs.desktop.icon_size",
                    "description": "prefs.desktop.icon_size.desc",
                    "keywords": "icon size width height pixels"
                },
                {
                    "key": "desktop.spacingVertical",
                    "type": "slider",
                    "min": 0,
                    "max": 64,
                    "step": 2,
                    "unit": "px",
                    "visibleWhen": {
                        "key": "desktop.enabled",
                        "equals": true
                    },
                    "label": "prefs.desktop.icon_spacing",
                    "description": "prefs.desktop.icon_spacing.desc",
                    "keywords": "icon spacing vertical gap rows"
                },
                {
                    "key": "desktop.textColor",
                    "type": "custom",
                    "component": "ColorRoleSwatches",
                    "options": [
                        {
                            "value": "overBackground",
                            "label": "prefs.desktop.ink.overBackground"
                        },
                        {
                            "value": "background",
                            "label": "prefs.desktop.ink.background"
                        },
                        {
                            "value": "primary",
                            "label": "prefs.desktop.ink.primary"
                        },
                        {
                            "value": "secondary",
                            "label": "prefs.desktop.ink.secondary"
                        },
                        {
                            "value": "tertiary",
                            "label": "prefs.desktop.ink.tertiary"
                        }
                    ],
                    "visibleWhen": {
                        "key": "desktop.enabled",
                        "equals": true
                    },
                    "label": "prefs.desktop.icon_text",
                    "description": "prefs.desktop.icon_text.desc",
                    "keywords": "icon label text colour color font"
                }
            ]
        },
        {
            "id": "overview",
            "title": "prefs.desktop.section.overview",
            "entries": [
                {
                    "key": "desktop.blurWallpaperOnOverview",
                    "type": "toggle",
                    "label": "prefs.desktop.overview_blur",
                    "description": "prefs.desktop.overview_blur.desc",
                    "keywords": "overview blur wallpaper niri workspaces"
                }
            ]
        }
    ]
};
