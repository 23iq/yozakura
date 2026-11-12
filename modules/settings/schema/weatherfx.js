.pragma library

// Appearance > Effects: weather on surfaces (theme.weatherFx,
// modules/theme/WeatherFx.qml). Appended to the "effects" section by
// appearance.js. Entry format: see modules/settings/AGENTS.md.

var shown = {
    "key": "theme.weatherFx.mode",
    "notEquals": "off"
};

function toggle(id, keywords) {
    return {
        "key": "theme.weatherFx." + id,
        "type": "toggle",
        // which effects show: fine tuning, out of the window
        "advanced": true,
        "visibleWhen": shown,
        "label": "prefs.weatherfx." + id,
        "description": "prefs.weatherfx." + id + ".desc",
        "keywords": keywords
    };
}

var entries = [
    {
        "key": "theme.weatherFx.mode",
        "type": "selector",
        "label": "prefs.weatherfx.mode",
        "description": "prefs.weatherfx.mode.desc",
        "options": [
            {
                "value": "off",
                "label": "prefs.common.off"
            },
            {
                "value": "subtle",
                "label": "prefs.weatherfx.mode.subtle"
            },
            {
                "value": "vivid",
                "label": "prefs.weatherfx.mode.vivid"
            }
        ],
        "keywords": "weather on surfaces rain droplets snow frost heat fog mist petals leaves season ambient"
    },
    toggle("rain", "rain drizzle droplets drops water glass"),
    toggle("frost", "frost ice snow cold winter flakes freezing"),
    toggle("heat", "heat hot shimmer summer haze"),
    toggle("fog", "fog mist haze"),
    toggle("seasonal", "season petals leaves spring autumn fall sakura maple")
];
