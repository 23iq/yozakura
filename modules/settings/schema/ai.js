.pragma library

// AI center: modes, quick ask, CLI agents, MCP servers, shell control,
// selection actions, prompt library and automations. Entry format: see
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
                    "key": "ai.defaultMode",
                    "type": "selector",
                    "label": "ai.default_mode",
                    "description": "prefs.ai.default_mode.desc",
                    "keywords": "mode chat agent shell default",
                    "options": [
                        {
                            "value": "chat",
                            "label": "ai.mode_chat",
                            "icon": "chatTeardrop"
                        },
                        {
                            "value": "agent",
                            "label": "ai.mode_agent",
                            "icon": "terminalWindow"
                        },
                        {
                            "value": "shell",
                            "label": "ai.mode_shell",
                            "icon": "command"
                        }
                    ]
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
                    "key": "ai.wideWidth",
                    "type": "number",
                    "label": "ai.wide_width",
                    "description": "prefs.ai.wide_width.desc",
                    "keywords": "wide layout width agent",
                    "min": 600,
                    "max": 2400,
                    "unit": "px"
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
                        "ai.agents.claude.yolo",
                        "ai.agents.codex.enabled",
                        "ai.agents.codex.binary",
                        "ai.agents.codex.model",
                        "ai.agents.codex.yolo",
                        "ai.agents.opencode.enabled",
                        "ai.agents.opencode.binary",
                        "ai.agents.opencode.model",
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
            "id": "shell",
            "title": "ai.mode_shell",
            "entries": [
                {
                    "key": "ai.shell.enabled",
                    "type": "toggle",
                    "label": "prefs.ai.shell_enabled",
                    "description": "prefs.ai.shell_enabled.desc",
                    "keywords": "shell control desktop voice commands"
                },
                {
                    "key": "ai.shell.target",
                    "type": "text",
                    "label": "prefs.ai.shell_target",
                    "description": "prefs.ai.shell_target.desc",
                    "keywords": "shell control model agent target"
                },
                {
                    "key": "ai.shell.systemPrompt",
                    "type": "text",
                    "label": "ai.system_prompt",
                    "description": "prefs.ai.shell_prompt.desc",
                    "keywords": "shell control prompt"
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
