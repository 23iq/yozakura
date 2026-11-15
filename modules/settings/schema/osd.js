.pragma library

// Panels > Menus & OSD (spliced into menus.js by Categories.js): style,
// edge and timing of the volume /
// brightness OSD (modules/shell/osd).
// Entry format: see modules/settings/AGENTS.md.

var sections = [
    {
        "id": "osd",
        "title": "prefs.osd.section",
        "entries": [
            {
                "key": "layout.osd.style",
                "type": "selector",
                "display": "cards",
                "thumb": "OsdStyleThumb",
                "options": [
                    {
                        "value": "pill",
                        "label": "prefs.osd.style.pill"
                    },
                    {
                        "value": "edge",
                        "label": "prefs.osd.style.edge"
                    },
                    {
                        "value": "island",
                        "label": "prefs.osd.style.island"
                    },
                    {
                        "value": "bar-inline",
                        "label": "prefs.osd.style.bar_inline"
                    },
                    {
                        "value": "gauge",
                        "label": "prefs.osd.style.gauge"
                    }
                ],
                "label": "prefs.label.osd_style",
                "description": "prefs.osd.style.desc",
                "keywords": "osd volume brightness on screen display pill island bar edge gauge needle dial instrument indicator"
            }
        ]
    },
    {
        // where and how long: the edge is also picked on the stage
        "id": "place",
        "title": "prefs.osd.section.place",
        "entries": [
            {
                "key": "layout.osd.position",
                "type": "selector",
                "options": [
                    {
                        "value": "auto",
                        "label": "prefs.osd.position.auto",
                        "icon": "sparkle"
                    },
                    {
                        "value": "top",
                        "label": "prefs.osd.position.top",
                        "icon": "arrowUp"
                    },
                    {
                        "value": "bottom",
                        "label": "prefs.osd.position.bottom",
                        "icon": "arrowDown"
                    },
                    {
                        "value": "left",
                        "label": "prefs.osd.position.left",
                        "icon": "arrowLeft"
                    },
                    {
                        "value": "right",
                        "label": "prefs.osd.position.right",
                        "icon": "arrowRight"
                    }
                ],
                "visibleWhen": {
                    "key": "layout.osd.style",
                    "notEquals": "bar-inline"
                },
                "label": "prefs.osd.position",
                "description": "prefs.osd.position.desc",
                "keywords": "osd position edge side top bottom left right"
            },
            {
                "key": "layout.osd.timeout",
                "type": "slider",
                "min": 800,
                "max": 8000,
                "step": 100,
                "unit": "ms",
                "label": "prefs.osd.timeout",
                "description": "prefs.osd.timeout.desc",
                "keywords": "osd duration timeout how long hide"
            }
        ]
    }
];

