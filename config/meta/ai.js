.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/ai.js (format: config/meta/Meta.js).
// Most user-facing keys are declared in modules/settings/schema/ai.js.

var description = "AI center: chat models, CLI agents (Claude Code, Codex, OpenCode), shell control over MCP, quick ask, selection actions, prompts and automations.";

var AGENT_CATEGORIES = ["read", "write", "exec", "network", "mcp", "other"];

var keys = {
    "tool": {
        "description": "Legacy tool selection of the old assistant (kept for compatibility)."
    },
    "extraModels": {
        "description": "Extra chat models added to the model picker."
    },
    "defaultModel": {
        "description": "Chat model used by default (id from the model picker)."
    },
    "sidebarWidth": {
        "min": 240,
        "max": 1200,
        "unit": "px",
        "description": "Width of the AI sidebar."
    },
    "sidebarPosition": {
        "enum": Enums.SIDES,
        "description": "Screen side of the AI sidebar."
    },
    "sidebarPinnedOnStartup": {
        "description": "Open the AI sidebar pinned at startup."
    },
    "defaultMode": {
        "enum": Enums.AI_MODES
    },
    "agents": {
        "description": "CLI coding agents run by the backend session manager."
    },
    "agents.defaultAgent": {
        "description": "Agent id used for new agent sessions (claude, codex, opencode)."
    },
    "agents.defaultCwd": {
        "format": "path",
        "description": "Working directory for new agent sessions (empty = home)."
    },
    "agents.recentDirs": {
        "items": {
            "type": "string"
        },
        "description": "Recently used agent working directories (maintained automatically)."
    },
    "agents.autoApprove": {
        "items": {
            "enum": AGENT_CATEGORIES
        },
        "uniqueItems": true,
        "description": "Tool-call categories approved without asking (default: read)."
    },
    "agents.*.enabled": {
        "description": "Offer this agent."
    },
    "agents.*.binary": {
        "format": "path",
        "description": "Agent executable (empty = look it up in PATH)."
    },
    "agents.*.model": {
        "description": "Model passed to the agent (empty = the agent's default)."
    },
    "agents.*.yolo": {
        "description": "Approve every tool call of this agent without asking (dangerous)."
    },
    "agents.*.extraArgs": {
        "items": {
            "type": "string"
        },
        "description": "Extra command-line arguments for the agent."
    },
    "mcp.disabled": {
        "items": {
            "type": "string"
        },
        "description": "Names of imported MCP servers that are turned off."
    },
    "selection": {
        "description": "Actions on the selected text (translate, explain, ...)."
    },
    "selection.actions": {
        "description": "Selection actions: [{id, label, icon, output, prompt}]."
    },
    "prompts": {
        "description": "Prompt library: [{id, name, prompt}] ({date} and similar placeholders are expanded)."
    },
    "automations": {
        "description": "Automations: [{id, name, enabled, trigger: {type, ...}, prompt}] run by the AI center."
    },
    "voice.enabled": {
        "description": "Allow voice input into the AI center."
    }
};
