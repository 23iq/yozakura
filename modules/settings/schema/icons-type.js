.pragma library

// Look > Icons & type: icon font weight, UI/mono fonts and the heading
// role (font + letter case). Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "icons-type",
    "icon": "textAa",
    "title": "prefs.cat.icons_type",
    "description": "prefs.cat.icons_type.desc",
    "keywords": "icons weight phosphor regular bold fill fonts typography heading title case uppercase typeface",
    "sections": [
        {
            "id": "icons",
            "title": "prefs.icons_type.section.icons",
            "entries": [
                {
                    "key": "theme.icons.weight",
                    "type": "selector",
                    "label": "prefs.icons_type.weight",
                    "description": "prefs.icons_type.weight.desc",
                    "keywords": "icon weight stroke thin solid filled phosphor",
                    "options": [
                        { "value": "regular", "label": "prefs.icons_type.weight.regular" },
                        { "value": "bold", "label": "prefs.icons_type.weight.bold" },
                        { "value": "fill", "label": "prefs.icons_type.weight.fill" }
                    ]
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
            "id": "headings",
            "title": "prefs.icons_type.section.headings",
            "entries": [
                {
                    "key": "theme.type.heading",
                    "type": "text",
                    "placeholder": "prefs.icons_type.heading_font.placeholder",
                    "label": "prefs.icons_type.heading_font",
                    "description": "prefs.icons_type.heading_font.desc",
                    "keywords": "heading title font typeface family display"
                },
                {
                    "key": "theme.type.headingCase",
                    "type": "selector",
                    "label": "prefs.icons_type.heading_case",
                    "description": "prefs.icons_type.heading_case.desc",
                    "keywords": "heading title case uppercase lowercase capitalize caps",
                    "options": [
                        { "value": "none", "label": "prefs.icons_type.case.none" },
                        { "value": "upper", "label": "prefs.icons_type.case.upper" },
                        { "value": "lower", "label": "prefs.icons_type.case.lower" },
                        { "value": "title", "label": "prefs.icons_type.case.title" }
                    ]
                }
            ]
        }
    ]
};
