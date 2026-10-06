.pragma library
.import "aimodels.js" as AiModels
.import "aiusage.js" as AiUsage

// AI bar: general, look and behaviour of the bar, quick ask, CLI agents,
// MCP servers, selection actions, prompt library and automations. Entry format: see
// modules/settings/AGENTS.md.

var category = {
    "id": "ai",
    "icon": "robot",
    "title": "prefs.cat.ai",
    "description": "prefs.cat.ai.desc",
    "keywords": "ai assistant chat sidebar model llm agent claude codex opencode ollama mcp automation prompt",
    "sections": [
        {
            "id": "center",
            "title": "ai.settings_general",
            "entries": [
                {
                    "key": "ai.enabled",
                    "type": "toggle",
                    "label": "ai.enable_center",
                    "description": "ai.settings_general_desc",
                    "keywords": "ai assistant enable sidebar"
                },
                {
                    "key": "ai.showThinking",
                    "type": "toggle",
                    "label": "ai.show_thinking",
                    "description": "prefs.ai.show_thinking.desc",
                    "keywords": "thinking reasoning thought"
                },
                {
                    "key": "ai.chatTools",
                    "type": "toggle",
                    "label": "ai.chat_tools",
                    "description": "prefs.ai.chat_tools.desc",
                    "keywords": "tools mcp function calling"
                },
                {
                    "key": "ai.maxToolRounds",
                    "type": "number",
                    "label": "ai.max_tool_rounds",
                    "description": "prefs.ai.max_tool_rounds.desc",
                    "keywords": "tool rounds loop limit",
                    "min": 1,
                    "max": 30
                },
                {
                    "key": "ai.unloadAfterMinutes",
                    "type": "number",
                    "label": "ai.unload_after",
                    "description": "prefs.ai.unload_after.desc",
                    "keywords": "memory unload idle performance",
                    "min": 1,
                    "max": 240,
                    "unit": "min"
                },
                {
                    "key": "ai.systemPrompt",
                    "type": "text",
                    "label": "ai.system_prompt",
                    "description": "prefs.ai.system_prompt.desc",
                    "keywords": "system prompt instructions persona"
                }
            ]
        },
        {
            "id": "bar_appearance",
            "title": "prefs.ai.bar_appearance",
            "entries": [
                {
                    "key": "ai.appearance.defaultSize",
                    "type": "selector",
                    "label": "prefs.ai.default_size",
                    "description": "prefs.ai.default_size.desc",
                    "keywords": "size compact wide fullscreen width layout",
                    "options": [
                        {
                            "value": "compact",
                            "label": "prefs.ai.size_compact",
                            "icon": "sidebar"
                        },
                        {
                            "value": "wide",
                            "label": "prefs.ai.size_wide",
                            "icon": "columns"
                        },
                        {
                            "value": "fullscreen",
                            "label": "prefs.ai.size_fullscreen",
                            "icon": "arrowsOutSimple"
                        }
                    ]
                },
                {
                    "key": "ai.sidebarPosition",
                    "type": "selector",
                    "label": "prefs.ai.side",
                    "description": "prefs.ai.side.desc",
                    "keywords": "side left right position edge",
                    "options": [
                        {
                            "value": "left",
                            "label": "prefs.ai.side_left"
                        },
                        {
                            "value": "right",
                            "label": "prefs.ai.side_right"
                        }
                    ]
                },
                {
                    "key": "ai.sidebarWidth",
                    "type": "slider",
                    "label": "prefs.ai.compact_width",
                    "description": "prefs.ai.compact_width.desc",
                    "keywords": "compact width sidebar size",
                    "min": 320,
                    "max": 900,
                    "step": 10,
                    "unit": "px"
                },
                {
                    "key": "ai.wideWidth",
                    "type": "slider",
                    "label": "ai.wide_width",
                    "description": "prefs.ai.wide_width.desc",
                    "keywords": "wide layout width",
                    "min": 600,
                    "max": 2400,
                    "step": 20,
                    "unit": "px"
                },
                {
                    "key": "ai.appearance.messageStyle",
                    "type": "selector",
                    "label": "prefs.ai.message_style",
                    "description": "prefs.ai.message_style.desc",
                    "keywords": "message bubble flat chat style",
                    "options": [
                        {
                            "value": "bubble",
                            "label": "prefs.ai.style_bubble",
                            "icon": "chatTeardrop"
                        },
                        {
                            "value": "flat",
                            "label": "prefs.ai.style_flat",
                            "icon": "alignLeft"
                        }
                    ]
                },
                {
                    "key": "ai.appearance.density",
                    "type": "selector",
                    "label": "prefs.ai.density",
                    "description": "prefs.ai.density.desc",
                    "keywords": "density compact comfortable spacing",
                    "options": [
                        {
                            "value": "compact",
                            "label": "prefs.ai.density_compact"
                        },
                        {
                            "value": "comfortable",
                            "label": "prefs.ai.density_comfortable"
                        }
                    ]
                },
                {
                    "key": "ai.appearance.fontScale",
                    "type": "slider",
                    "label": "prefs.ai.font_scale",
                    "description": "prefs.ai.font_scale.desc",
                    "keywords": "font size scale text zoom",
                    "min": 0.8,
                    "max": 1.4,
                    "step": 0.05,
                    "unit": "×"
                },
                {
                    "key": "ai.appearance.showAvatars",
                    "type": "toggle",
                    "label": "prefs.ai.show_avatars",
                    "description": "prefs.ai.show_avatars.desc",
                    "keywords": "avatar icon engine picture"
                },
                {
                    "key": "ai.appearance.showTimestamps",
                    "type": "toggle",
                    "label": "prefs.ai.show_timestamps",
                    "description": "prefs.ai.show_timestamps.desc",
                    "keywords": "time timestamp clock message"
                },
                {
                    "key": "ai.appearance.animations",
                    "type": "toggle",
                    "label": "prefs.ai.animations",
                    "description": "prefs.ai.animations.desc",
                    "keywords": "animation motion transition"
                },
                {
                    "key": "ai.appearance.glass",
                    "type": "toggle",
                    "label": "prefs.ai.glass",
                    "description": "prefs.ai.glass.desc",
                    "keywords": "glass blur translucent surface"
                },
                {
                    "key": "ai.appearance.opacity",
                    "type": "slider",
                    "label": "prefs.ai.opacity",
                    "description": "prefs.ai.opacity.desc",
                    "keywords": "opacity transparency background surface",
                    "min": 0.4,
                    "max": 1,
                    "step": 0.05
                }
            ]
        },
        {
            "id": "bar_behavior",
            "title": "prefs.ai.bar_behavior",
            "entries": [
                {
                    "key": "ai.behavior.defaultSpace",
                    "type": "selector",
                    "label": "prefs.ai.default_space",
                    "description": "prefs.ai.default_space.desc",
                    "keywords": "space assistant code default startup",
                    "options": [
                        {
                            "value": "last",
                            "label": "prefs.ai.space_last",
                            "icon": "clockCounterClockwise"
                        },
                        {
                            "value": "assistant",
                            "label": "ai.space_assistant",
                            "icon": "sparkle"
                        },
                        {
                            "value": "code",
                            "label": "ai.space_code",
                            "icon": "code"
                        }
                    ]
                },
                {
                    "key": "ai.defaultModel",
                    "type": "text",
                    "label": "prefs.ai.default_engine",
                    "description": "prefs.ai.default_engine.desc",
                    "keywords": "default engine model assistant provider",
                    "placeholder": "prefs.ai.default_engine.placeholder"
                },
                {
                    "key": "ai.agents.defaultAgent",
                    "type": "selector",
                    "label": "prefs.ai.default_agent",
                    "description": "prefs.ai.default_agent.desc",
                    "keywords": "default agent code claude codex opencode",
                    "options": [
                        {
                            "value": "claude",
                            "label": "prefs.ai.agent_claude"
                        },
                        {
                            "value": "codex",
                            "label": "prefs.ai.agent_codex"
                        },
                        {
                            "value": "opencode",
                            "label": "prefs.ai.agent_opencode"
                        }
                    ]
                },
                {
                    "key": "ai.behavior.enterToSend",
                    "type": "toggle",
                    "label": "prefs.ai.enter_to_send",
                    "description": "prefs.ai.enter_to_send.desc",
                    "keywords": "enter send ctrl newline keyboard"
                },
                {
                    "key": "ai.behavior.suggestions",
                    "type": "toggle",
                    "label": "prefs.ai.suggestions",
                    "description": "prefs.ai.suggestions.desc",
                    "keywords": "suggestions chips empty start ideas"
                },
                {
                    "key": "ai.behavior.suggestionKinds",
                    "type": "multiselect",
                    "label": "prefs.ai.suggestion_kinds",
                    "description": "prefs.ai.suggestion_kinds.desc",
                    "keywords": "suggestions clipboard selection media timer window",
                    "options": [
                        {
                            "value": "clipboard",
                            "label": "prefs.ai.sug_kind_clipboard",
                            "icon": "clipboardText"
                        },
                        {
                            "value": "selection",
                            "label": "prefs.ai.sug_kind_selection",
                            "icon": "cursorText"
                        },
                        {
                            "value": "media",
                            "label": "prefs.ai.sug_kind_media",
                            "icon": "musicNotes"
                        },
                        {
                            "value": "timer",
                            "label": "prefs.ai.sug_kind_timer",
                            "icon": "timer"
                        },
                        {
                            "value": "window",
                            "label": "prefs.ai.sug_kind_window",
                            "icon": "appWindow"
                        },
                        {
                            "value": "desktop",
                            "label": "prefs.ai.sug_kind_desktop",
                            "icon": "palette"
                        },
                        {
                            "value": "time",
                            "label": "prefs.ai.sug_kind_time",
                            "icon": "sun"
                        }
                    ],
                    "visibleWhen": {
                        "key": "ai.behavior.suggestions",
                        "equals": true
                    }
                },
                {
                    "key": "ai.behavior.restoreLastSession",
                    "type": "toggle",
                    "label": "prefs.ai.restore_last",
                    "description": "prefs.ai.restore_last.desc",
                    "keywords": "restore last session conversation reopen"
                },
                {
                    "key": "ai.behavior.autoScroll",
                    "type": "toggle",
                    "label": "prefs.ai.auto_scroll",
                    "description": "prefs.ai.auto_scroll.desc",
                    "keywords": "scroll follow stream bottom"
                },
                {
                    "key": "ai.behavior.thinkingExpanded",
                    "type": "toggle",
                    "label": "prefs.ai.thinking_expanded",
                    "description": "prefs.ai.thinking_expanded.desc",
                    "keywords": "thinking reasoning expanded collapsed",
                    "visibleWhen": {
                        "key": "ai.showThinking",
                        "equals": true
                    }
                },
                {
                    "key": "ai.behavior.collapseTools",
                    "type": "toggle",
                    "label": "prefs.ai.collapse_tools",
                    "description": "prefs.ai.collapse_tools.desc",
                    "keywords": "tool action details collapse expand"
                }
            ]
        },
        {
            "id": "bar_strip",
            "title": "prefs.ai.bar_strip",
            "entries": [
                {
                    "key": "ai.strip.engine",
                    "type": "toggle",
                    "label": "prefs.ai.strip_engine",
                    "description": "prefs.ai.strip_engine.desc",
                    "keywords": "status strip engine model effort"
                },
                {
                    "key": "ai.strip.effort",
                    "type": "toggle",
                    "label": "prefs.ai.strip_effort",
                    "description": "prefs.ai.strip_effort.desc",
                    "keywords": "status strip reasoning effort thinking level"
                },
                {
                    "key": "ai.strip.context",
                    "type": "toggle",
                    "label": "prefs.ai.strip_context",
                    "description": "prefs.ai.strip_context.desc",
                    "keywords": "status strip context window tokens"
                },
                {
                    "key": "ai.strip.cost",
                    "type": "toggle",
                    "label": "prefs.ai.strip_cost",
                    "description": "prefs.ai.strip_cost.desc",
                    "keywords": "status strip cost tokens price"
                },
                {
                    "key": "ai.strip.limit",
                    "type": "toggle",
                    "label": "prefs.ai.strip_limit",
                    "description": "prefs.ai.strip_limit.desc",
                    "keywords": "status strip subscription limit usage"
                }
            ]
        },
        {
            "id": "quickask",
            "title": "ai.quick_enabled",
            "entries": [
                {
                    "key": "ai.quickAsk.enabled",
                    "type": "toggle",
                    "label": "ai.quick_enabled",
                    "description": "prefs.ai.quick.desc",
                    "keywords": "quick ask notch"
                },
                {
                    "key": "ai.quickAsk.model",
                    "type": "text",
                    "label": "ai.quick_model",
                    "description": "ai.quick_model_hint",
                    "keywords": "quick ask model"
                },
                {
                    "key": "ai.quickAsk.width",
                    "type": "number",
                    "label": "prefs.ai.quick_width",
                    "description": "prefs.ai.quick_width.desc",
                    "keywords": "quick ask width",
                    "min": 380,
                    "max": 1200,
                    "unit": "px"
                }
            ]
        },
        {
            "id": "agents",
            "title": "ai.settings_agents",
            "entries": [
                {
                    "id": "ai.agents.list",
                    "type": "custom",
                    "component": "AiAgentsEditor",
                    "keys": [
                        "ai.agents.autoApprove",
                        "ai.agents.claude.enabled",
                        "ai.agents.claude.binary",
                        "ai.agents.claude.model",
                        "ai.agents.claude.effort",
                        "ai.agents.claude.yolo",
                        "ai.agents.codex.enabled",
                        "ai.agents.codex.binary",
                        "ai.agents.codex.model",
                        "ai.agents.codex.effort",
                        "ai.agents.codex.yolo",
                        "ai.agents.opencode.enabled",
                        "ai.agents.opencode.binary",
                        "ai.agents.opencode.model",
                        "ai.agents.opencode.effort",
                        "ai.agents.opencode.yolo"
                    ],
                    "label": "ai.settings_agents",
                    "description": "ai.settings_agents_desc",
                    "keywords": "claude code codex opencode cli agent yolo permissions binary model"
                }
            ]
        },
        {
            "id": "mcp",
            "title": "ai.settings_mcp",
            "entries": [
                {
                    "key": "ai.mcp.yozakura",
                    "type": "toggle",
                    "label": "ai.mcp_yozakura",
                    "description": "prefs.ai.mcp_yozakura.desc",
                    "keywords": "mcp yozakura desktop control tools"
                },
                {
                    "key": "ai.mcp.importClaude",
                    "type": "toggle",
                    "label": "ai.mcp_import_claude",
                    "description": "prefs.ai.mcp_import.desc",
                    "keywords": "mcp import claude"
                },
                {
                    "key": "ai.mcp.importCodex",
                    "type": "toggle",
                    "label": "ai.mcp_import_codex",
                    "description": "prefs.ai.mcp_import.desc",
                    "keywords": "mcp import codex"
                },
                {
                    "key": "ai.mcp.importOpencode",
                    "type": "toggle",
                    "label": "ai.mcp_import_opencode",
                    "description": "prefs.ai.mcp_import.desc",
                    "keywords": "mcp import opencode"
                },
                {
                    "id": "ai.mcp.servers",
                    "type": "custom",
                    "component": "AiMcpEditor",
                    "keys": [
                        "ai.mcp.disabled"
                    ],
                    "label": "prefs.ai.mcp_servers",
                    "description": "ai.settings_mcp_desc",
                    "keywords": "mcp servers tools enable disable"
                }
            ]
        },
        {
            "id": "selection",
            "title": "ai.settings_prompts",
            "entries": [
                {
                    "key": "ai.selection.enabled",
                    "type": "toggle",
                    "label": "ai.selection_enabled",
                    "description": "prefs.ai.selection.desc",
                    "keywords": "selection actions popup translate rewrite explain"
                },
                {
                    "key": "ai.selection.language",
                    "type": "text",
                    "label": "ai.translate_to",
                    "description": "prefs.ai.translate_to.desc",
                    "keywords": "translate language"
                },
                {
                    "key": "ai.selection.output",
                    "type": "selector",
                    "label": "ai.selection_output",
                    "description": "prefs.ai.selection_output.desc",
                    "keywords": "replace clipboard sidebar output",
                    "options": [
                        {
                            "value": "replace",
                            "label": "ai.output_replace"
                        },
                        {
                            "value": "clipboard",
                            "label": "ai.output_clipboard"
                        },
                        {
                            "value": "sidebar",
                            "label": "ai.output_sidebar"
                        }
                    ]
                },
                {
                    "id": "ai.prompts.lists",
                    "type": "custom",
                    "component": "AiPromptsEditor",
                    "keys": [
                        "ai.selection.actions",
                        "ai.prompts"
                    ],
                    "label": "ai.prompt_library",
                    "description": "ai.settings_prompts_desc",
                    "keywords": "prompt library templates variables selection actions"
                }
            ]
        },
        {
            "id": "automations",
            "title": "ai.settings_automations",
            "entries": [
                {
                    "id": "ai.automations.list",
                    "type": "custom",
                    "component": "AiAutomationsEditor",
                    "keys": [
                        "ai.automations"
                    ],
                    "label": "ai.settings_automations",
                    "description": "ai.settings_automations_desc",
                    "keywords": "automation schedule cron trigger clipboard screenshot login briefing download"
                }
            ]
        },
        {
            "id": "providers",
            "title": "ai.providers",
            "entries": [
                {
                    "id": "ai.providers.link",
                    "type": "custom",
                    "component": "LegacyLink",
                    "target": "ai-providers",
                    "resettable": false,
                    "label": "ai.providers",
                    "description": "prefs.ai.providers.desc",
                    "keywords": "api key provider openai anthropic gemini mistral groq ollama custom endpoint"
                }
            ]
        }
    ]
};

// Model picker, effort and context sections (schema/aimodels.js) go right
// after the status strip.
category.sections.splice(category.sections.findIndex(s => s.id === "bar_strip") + 1, 0, ...AiModels.sections);
// Usage and limits (schema/aiusage.js) after the model/effort/context ones.
category.sections.splice(category.sections.findIndex(s => s.id === "bar_strip") + 1 + AiModels.sections.length, 0, ...AiUsage.sections);
