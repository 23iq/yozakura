.pragma library

// AI > usage and subscription limits (spliced into schema/ai.js after the
// model/effort/context sections). Entry format: see modules/settings/AGENTS.md.

function opt(value, label) {
    return { "value": value, "label": label };
}

var sections = [
    {
        "id": "usage_limits",
        "title": "prefs.ai.section.usage",
        "entries": [
            {
                "key": "ai.usage.headerButton",
                "type": "toggle",
                "label": "prefs.ai.usage_header_button",
                "description": "prefs.ai.usage_header_button.desc",
                "keywords": "usage button header chart cost screen"
            },
            {
                "key": "ai.usage.stripTokens",
                "type": "toggle",
                "visibleWhen": { "key": "ai.strip.cost", "equals": true },
                "label": "prefs.ai.usage_strip_tokens",
                "description": "prefs.ai.usage_strip_tokens.desc",
                "keywords": "usage tokens strip session count"
            },
            {
                "key": "ai.usage.limitWindow",
                "type": "selector",
                "visibleWhen": { "key": "ai.strip.limit", "equals": true },
                "label": "prefs.ai.usage_limit_window",
                "description": "prefs.ai.usage_limit_window.desc",
                "keywords": "subscription limit window five hour weekly strip",
                "options": [opt("auto", "prefs.ai.usage_limit_window.auto"), opt("5h", "ai.usage.window.5h"), opt("week", "ai.usage.window.week")]
            },
            {
                "key": "ai.usage.claudeLimits",
                "type": "toggle",
                "label": "prefs.ai.usage_claude_limits",
                "description": "prefs.ai.usage_claude_limits.desc",
                "keywords": "claude subscription limits pro max usage oauth"
            },
            {
                "key": "ai.usage.notify",
                "type": "toggle",
                "label": "prefs.ai.usage_notify",
                "description": "prefs.ai.usage_notify.desc",
                "keywords": "subscription limit notification alert warning threshold"
            },
            {
                "key": "ai.usage.warnAt",
                "type": "slider",
                "min": 50,
                "max": 100,
                "step": 5,
                "unit": "%",
                "label": "prefs.ai.usage_warn_at",
                "description": "prefs.ai.usage_warn_at.desc",
                "keywords": "limit warning amber threshold percent"
            },
            {
                "key": "ai.usage.criticalAt",
                "type": "slider",
                "min": 50,
                "max": 100,
                "step": 5,
                "unit": "%",
                "label": "prefs.ai.usage_critical_at",
                "description": "prefs.ai.usage_critical_at.desc",
                "keywords": "limit critical red second threshold percent"
            },
            {
                "key": "ai.usage.currencyStyle",
                "type": "selector",
                "label": "prefs.ai.usage_currency",
                "description": "prefs.ai.usage_currency.desc",
                "keywords": "cost currency dollar usd format price",
                "options": [opt("symbol", "prefs.ai.usage_currency.symbol"), opt("code", "prefs.ai.usage_currency.code")]
            },
            {
                "key": "ai.usage.decimals",
                "type": "slider",
                "min": 2,
                "max": 4,
                "step": 1,
                "label": "prefs.ai.usage_decimals",
                "description": "prefs.ai.usage_decimals.desc",
                "keywords": "cost decimals precision cents"
            },
            {
                "key": "ai.usage.defaultRange",
                "type": "selector",
                "label": "prefs.ai.usage_default_range",
                "description": "prefs.ai.usage_default_range.desc",
                "keywords": "usage screen range today week month",
                "options": [opt("today", "ai.usage.range.today"), opt("week", "ai.usage.range.week"), opt("month", "ai.usage.range.month")]
            },
            {
                "key": "ai.usage.sparklines",
                "type": "toggle",
                "label": "prefs.ai.usage_sparklines",
                "description": "prefs.ai.usage_sparklines.desc",
                "keywords": "usage chart sparkline per day graph"
            },
            {
                "key": "ai.usage.hiddenProviders",
                "type": "list",
                "itemType": "text",
                "placeholder": "prefs.ai.usage_hidden.placeholder",
                "addLabel": "prefs.ai.usage_hidden.add",
                "label": "prefs.ai.usage_hidden",
                "description": "prefs.ai.usage_hidden.desc",
                "keywords": "hide providers usage screen ollama local"
            },
            {
                "id": "ai.usage.data",
                "type": "custom",
                "component": "AiUsageData",
                "resettable": false,
                "label": "prefs.ai.usage_data",
                "description": "prefs.ai.usage_data.desc",
                "keywords": "usage history ledger clear reset prices override file"
            }
        ]
    }
];
