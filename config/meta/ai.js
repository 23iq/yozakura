.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/ai.js (format: config/meta/Meta.js).
// Most user-facing keys are declared in modules/settings/schema/ai.js.

var description = "AI bar: Assistant space (any model, desktop control over MCP) and Code space (CLI agents: Claude Code, Codex, OpenCode), quick ask, selection actions, prompts and automations.";

var AGENT_CATEGORIES = ["read", "write", "exec", "network", "mcp", "other"];

var keys = {
    "extraModels": {
        "description": "Extra chat models added to the model picker."
    },
    "defaultModel": {
        "description": "Initial assistant engine or API model ID. The last model picked in the bar wins afterwards (remembered per space); changing this setting later makes it the newer choice."
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
    "agents.*.effort": {
        "description": "Reasoning effort for new agent sessions; empty uses the engine default. Supported values depend on the installed engine and selected model."
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
        "description": "Automations: [{id, name, enabled, trigger: {type, ...}, prompt, output, routine}] run by the AI center; output \"routine\" runs the routine `routine` (svc/routines) without a model."
    },
    "appearance": {
        "description": "Look of the AI bar (sizes, message style, density, fonts)."
    },
    "behavior": {
        "description": "Behaviour of the AI bar (spaces, sending, suggestions, scrolling)."
    },
    "strip": {
        "description": "Items of the status strip above the AI bar composer."
    },
    "voice.enabled": {
        "description": "Allow voice input into the AI center."
    },
    "providers": {
        "description": "Chat providers: request timeout and retries, picker visibility, local auto-probe, custom endpoint headers."
    },
    "providers.hidden": {
        "items": {
            "type": "string",
            "enum": ["openai", "anthropic", "gemini", "mistral", "groq", "minimax", "openrouter", "deepseek", "lmstudio", "ollama", "custom"]
        },
        "description": "Provider ids hidden from the model picker (not listed, not probed, never shown as not connected)."
    },
    "lmstudio": {
        "description": "LM Studio (local OpenAI-compatible server)."
    },
    "tasks": {
        "description": "Code space tasks: agents run prompts in git worktrees, a check verifies the result, the user reviews and accepts (backend svc/tasks)."
    },
    "tasks.defaultAgents": {
        "items": {
            "enum": ["claude", "codex", "opencode"]
        },
        "uniqueItems": true,
        "description": "Agents preselected for a new task (several = best-of-N)."
    },
    "tasks.notifyEvents": {
        "items": {
            "enum": ["permission", "plan", "review", "failed", "limit"]
        },
        "uniqueItems": true,
        "description": "Task events that send a desktop notification."
    }
};
