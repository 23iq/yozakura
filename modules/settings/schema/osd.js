.pragma library

// Popups > On-screen display: style, edge and timing of the volume /
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
                    }
                ],
                "label": "prefs.osd.style",
                "description": "prefs.osd.style.desc",
                "keywords": "osd volume brightness on screen display pill island bar edge indicator"
            },
            {
                "key": "layout.osd.position",
                "type": "selector",
                "options": [
                    {
                        "value": "auto",
                        "label": "prefs.osd.position.auto"
                    },
                    {
                        "value": "top",
                        "label": "prefs.osd.position.top"
                    },
                    {
                        "value": "bottom",
                        "label": "prefs.osd.position.bottom"
                    },
                    {
                        "value": "left",
                        "label": "prefs.osd.position.left"
                    },
                    {
                        "value": "right",
                        "label": "prefs.osd.position.right"
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

var category = {
    "id": "osd",
    "icon": "speakerHigh",
    "title": "prefs.cat.osd",
    "description": "prefs.cat.osd.desc",
    "keywords": "osd on-screen display volume brightness level indicator popup island",
    "sections": sections
};
