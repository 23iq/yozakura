.pragma library

// AI > model picker, reasoning effort and context window (spliced into
// schema/ai.js after the status strip section). Entry format: see
// modules/settings/AGENTS.md.

function level(value) {
    return { "value": value, "label": "ai.effort_level." + value };
}

var sections = [
    {
        "id": "model_effort",
        "title": "prefs.ai.section.model_effort",
        "entries": [
            {
                "key": "ai.effort.defaultLevel",
                "type": "selector",
                "label": "prefs.ai.effort_default",
                "description": "prefs.ai.effort_default.desc",
                "keywords": "reasoning effort thinking default level budget",
                "options": [{ "value": "auto", "label": "prefs.ai.effort_auto" }, level("off"), level("low"), level("medium"), level("high"), level("max")]
            },
            {
                "key": "ai.picker.showCapabilities",
                "type": "toggle",
                "label": "prefs.ai.picker_capabilities",
                "description": "prefs.ai.picker_capabilities.desc",
                "keywords": "model picker capabilities badges tools vision thinking context"
            },
            {
                "key": "ai.picker.groupByProvider",
                "type": "toggle",
                "label": "prefs.ai.picker_group",
                "description": "prefs.ai.picker_group.desc",
                "keywords": "model picker group provider sections"
            },
            {
                "key": "ai.picker.showRecent",
                "type": "toggle",
                "label": "prefs.ai.picker_recent",
                "description": "prefs.ai.picker_recent.desc",
                "keywords": "model picker recent last used"
            },
            {
                "key": "ai.picker.showUnconnected",
                "type": "toggle",
                "label": "prefs.ai.picker_unconnected",
                "description": "prefs.ai.picker_unconnected.desc",
                "keywords": "model picker providers not connected connect api key"
            }
        ]
    },
    {
        "id": "context",
        "title": "prefs.ai.section.context",
        "entries": [
            {
                "key": "ai.context.warnAt",
                "type": "slider",
                "label": "prefs.ai.context_warn",
                "description": "prefs.ai.context_warn.desc",
                "keywords": "context window warning amber threshold percent full",
                "min": 50,
                "max": 95,
                "step": 5,
                "unit": "%"
            },
            {
                "key": "ai.context.criticalAt",
                "type": "slider",
                "label": "prefs.ai.context_critical",
                "description": "prefs.ai.context_critical.desc",
                "keywords": "context window critical red threshold percent full",
                "min": 60,
                "max": 100,
                "step": 1,
                "unit": "%"
            },
            {
                "key": "ai.context.autoCompact",
                "type": "toggle",
                "label": "prefs.ai.auto_compact",
                "description": "prefs.ai.auto_compact.desc",
                "keywords": "auto compact compaction summarize summary context history"
            },
            {
                "key": "ai.context.autoCompactAt",
                "type": "slider",
                "label": "prefs.ai.auto_compact_at",
                "description": "prefs.ai.auto_compact_at.desc",
                "keywords": "auto compact threshold percent context",
                "min": 50,
                "max": 100,
                "step": 1,
                "unit": "%",
                "visibleWhen": { "key": "ai.context.autoCompact", "equals": true }
            },
            {
                "key": "ai.context.keepTurns",
                "type": "number",
                "label": "prefs.ai.keep_turns",
                "description": "prefs.ai.keep_turns.desc",
                "keywords": "compact keep recent turns messages verbatim",
                "min": 0,
                "max": 20
            },
            {
                "key": "ai.context.compactModel",
                "type": "text",
                "label": "prefs.ai.compact_model",
                "description": "prefs.ai.compact_model.desc",
                "keywords": "compact summary model cheap fast",
                "placeholder": "prefs.ai.compact_model.placeholder"
            },
            {
                "key": "ai.ollama.numCtx",
                "type": "number",
                "label": "prefs.ai.ollama_num_ctx",
                "description": "prefs.ai.ollama_num_ctx.desc",
                "keywords": "ollama num_ctx context length tokens memory vram local",
                "min": 0,
                "max": 1048576,
                "step": 1024,
                "specialValues": [{ "value": 0, "label": "prefs.ai.ollama_num_ctx.model_max" }]
            },
            {
                "key": "ai.context.overrides",
                "type": "list",
                "fields": [
                    {
                        "key": "model",
                        "type": "text",
                        "monospace": true,
                        "placeholder": "prefs.ai.context_override_model.placeholder",
                        "label": "prefs.ai.context_override_model"
                    },
                    {
                        "key": "contextWindow",
                        "type": "number",
                        "min": 1024,
                        "max": 10000000,
                        "step": 1024,
                        "flex": 0.5,
                        "label": "prefs.ai.context_override_window"
                    }
                ],
                "newItem": {
                    "model": "",
                    "contextWindow": 128000
                },
                "itemLabel": "prefs.ai.context_override_n",
                "addLabel": "prefs.ai.context_override_add",
                "emptyLabel": "prefs.ai.context_overrides.empty",
                "label": "prefs.ai.context_overrides",
                "description": "prefs.ai.context_overrides.desc",
                "keywords": "context window override model size tokens custom"
            }
        ]
    }
];
