.pragma library

// AI > Providers: connect chat providers (the AI bar's Connect sheet),
// default model, picker visibility, request policy, custom endpoint
// headers and local servers (Ollama, LM Studio). Entry format: see
// modules/settings/AGENTS.md.

var category = {
    "id": "ai-providers",
    "icon": "plugsConnected",
    "title": "ai.providers",
    "description": "prefs.ai.providers.desc",
    "keywords": "ai api key provider connect openai anthropic gemini mistral groq minimax deepseek openrouter lm studio ollama custom endpoint local",
    "sections": [
        {
            "id": "connections",
            "title": "prefs.ai.providers.connections",
            "entries": [
                {
                    "id": "ai.providers.connect",
                    "type": "custom",
                    "component": "AiProvidersEditor",
                    "resettable": false,
                    "label": "prefs.ai.providers.connect",
                    "description": "prefs.ai.providers.connect.desc",
                    "keywords": "connect api key test disconnect provider openai anthropic gemini mistral groq minimax deepseek openrouter lm studio ollama custom"
                }
            ]
        },
        {
            "id": "defaults",
            "title": "prefs.ai.providers.defaults",
            "entries": [
                {
                    "key": "ai.defaultModel",
                    "type": "custom",
                    "component": "AiDefaultModel",
                    "label": "prefs.ai.default_engine",
                    "description": "prefs.ai.default_engine.desc",
                    "keywords": "default engine model assistant provider"
                },
                {
                    "key": "ai.providers.hidden",
                    "type": "custom",
                    "component": "AiProviderVisibility",
                    "label": "prefs.ai.providers.visible",
                    "description": "prefs.ai.providers.visible.desc",
                    "keywords": "hide show provider picker enable disable list"
                }
            ]
        },
        {
            "id": "requests",
            "title": "prefs.ai.providers.requests",
            "entries": [
                {
                    "key": "ai.providers.timeout",
                    "type": "number",
                    "label": "prefs.ai.providers.timeout",
                    "description": "prefs.ai.providers.timeout.desc",
                    "keywords": "timeout request seconds slow hang",
                    "min": 0,
                    "max": 3600,
                    "step": 30,
                    "unit": "s",
                    "specialValues": [{ "value": 0, "label": "prefs.ai.providers.timeout.none" }]
                },
                {
                    "key": "ai.providers.retries",
                    "type": "number",
                    "label": "prefs.ai.providers.retries",
                    "description": "prefs.ai.providers.retries.desc",
                    "keywords": "retry retries rate limit 429 overloaded network error",
                    "min": 0,
                    "max": 5
                },
                {
                    "key": "ai.providers.openrouterAttribution",
                    "type": "toggle",
                    "label": "prefs.ai.providers.openrouter_attribution",
                    "description": "prefs.ai.providers.openrouter_attribution.desc",
                    "keywords": "openrouter referer title attribution headers app"
                },
                {
                    "key": "ai.providers.customHeaders",
                    "type": "list",
                    "fields": [
                        {
                            "key": "name",
                            "type": "text",
                            "monospace": true,
                            "flex": 0.4,
                            "pattern": "^[A-Za-z0-9-]*$",
                            "placeholder": "prefs.ai.providers.header_name.placeholder",
                            "label": "prefs.ai.providers.header_name"
                        },
                        {
                            "key": "value",
                            "type": "text",
                            "monospace": true,
                            "placeholder": "prefs.ai.providers.header_value.placeholder",
                            "label": "prefs.ai.providers.header_value"
                        }
                    ],
                    "newItem": {
                        "name": "",
                        "value": ""
                    },
                    "itemLabel": "prefs.ai.providers.header_n",
                    "addLabel": "prefs.ai.providers.header_add",
                    "emptyLabel": "prefs.ai.providers.headers.empty",
                    "label": "prefs.ai.providers.headers",
                    "description": "prefs.ai.providers.headers.desc",
                    "keywords": "custom endpoint headers proxy auth authorization openai compatible"
                }
            ]
        },
        {
            "id": "local",
            "title": "prefs.ai.providers.local",
            "entries": [
                {
                    "key": "ai.ollama.endpoint",
                    "type": "text",
                    "label": "prefs.ai.ollama_endpoint",
                    "description": "prefs.ai.ollama_endpoint.desc",
                    "keywords": "ollama endpoint url host port server remote local",
                    "placeholder": "prefs.ai.ollama_endpoint.placeholder",
                    "pattern": "^$|^https?://\\S+$"
                },
                {
                    "key": "ai.ollama.keepAlive",
                    "type": "text",
                    "label": "prefs.ai.ollama_keep_alive",
                    "description": "prefs.ai.ollama_keep_alive.desc",
                    "keywords": "ollama keep alive unload memory vram minutes",
                    "placeholder": "prefs.ai.ollama_keep_alive.placeholder",
                    "pattern": "^$|^-?\\d+(\\.\\d+)?(ms|s|m|h)?$"
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
                    "key": "ai.lmstudio.endpoint",
                    "type": "text",
                    "label": "prefs.ai.lmstudio_endpoint",
                    "description": "prefs.ai.lmstudio_endpoint.desc",
                    "keywords": "lm studio lmstudio endpoint url server port local",
                    "placeholder": "prefs.ai.lmstudio_endpoint.placeholder",
                    "pattern": "^$|^https?://\\S+$"
                },
                {
                    "key": "ai.providers.probeInterval",
                    "type": "number",
                    "label": "prefs.ai.providers.probe_interval",
                    "description": "prefs.ai.providers.probe_interval.desc",
                    "keywords": "probe detect auto refresh interval local ollama lm studio",
                    "min": 0,
                    "max": 3600,
                    "step": 15,
                    "unit": "s",
                    "specialValues": [{ "value": 0, "label": "prefs.ai.providers.probe_interval.manual" }]
                }
            ]
        }
    ]
};
