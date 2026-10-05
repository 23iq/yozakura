.pragma library

var data = {
    "enabled": true,
    "systemPrompt": "You are a helpful assistant running on a Linux system. You have access to some tools to control the system.",
    "tool": "none",
    "extraModels": [],
    "defaultModel": "gemini-2.0-flash",
    "sidebarWidth": 400,
    "sidebarPosition": "right",
    "sidebarPinnedOnStartup": false,
    "wideWidth": 1040,
    "defaultMode": "chat",
    "showThinking": true,
    "chatTools": true,
    "maxToolRounds": 8,
    "unloadAfterMinutes": 10,
    "agents": {
        "defaultAgent": "claude",
        "defaultCwd": "",
        "recentDirs": [],
        "autoApprove": ["read"],
        "claude": { "enabled": true, "binary": "", "model": "", "yolo": false, "extraArgs": [] },
        "codex": { "enabled": true, "binary": "", "model": "", "yolo": false, "extraArgs": [] },
        "opencode": { "enabled": true, "binary": "", "model": "", "yolo": false, "extraArgs": [] }
    },
    "mcp": {
        "yozakura": true,
        "importClaude": true,
        "importCodex": true,
        "importOpencode": true,
        "disabled": []
    },
    "shell": {
        "enabled": true,
        "target": "",
        "systemPrompt": "You control the user's Yozakura desktop shell through the yozakura MCP tools (config, presets, wallpaper, windows, workspaces, notifications, clipboard, screenshots, media, do-not-disturb). Inspect state with the read-only tools first, then make the smallest change that fulfils the request and say what you changed in one sentence."
    },
    "quickAsk": {
        "enabled": true,
        "model": "",
        "width": 560
    },
    "selection": {
        "enabled": true,
        "language": "English",
        "output": "replace",
        "actions": [
            { "id": "translate", "label": "", "icon": "translate", "output": "", "prompt": "Translate the text below to {language}. If it already is {language}, translate it to Spanish. Reply with the translation only, keeping formatting.\n\n{selection}" },
            { "id": "explain", "label": "", "icon": "lightbulb", "output": "sidebar", "prompt": "Explain the following clearly and briefly:\n\n{selection}" },
            { "id": "rewrite", "label": "", "icon": "magicWand", "output": "", "prompt": "Rewrite the text below to be clearer and more natural, same language and meaning. Reply with the rewritten text only.\n\n{selection}" },
            { "id": "fix", "label": "", "icon": "bug", "output": "", "prompt": "Fix bugs and obvious mistakes in this code. Reply with the corrected code only, no fences, no commentary.\n\n{selection}" },
            { "id": "summarize", "label": "", "icon": "list", "output": "sidebar", "prompt": "Summarize in 3 bullet points:\n\n{selection}" }
        ]
    },
    "prompts": [
        { "id": "briefing", "name": "Morning briefing", "prompt": "Today is {date}. Give me a short, upbeat morning briefing: a focus suggestion for the day and one tip about my Linux desktop.", "output": "notify" },
        { "id": "explain-error", "name": "Explain error", "prompt": "Explain this error and how to fix it, briefly:\n\n{clipboard}", "output": "sidebar" },
        { "id": "commit-msg", "name": "Commit message", "prompt": "Write a conventional commit message for this diff:\n\n{clipboard}", "output": "clipboard" }
    ],
    "automations": [
        { "id": "morning", "name": "Morning briefing", "enabled": false, "trigger": { "type": "login", "cron": "", "pattern": "", "kinds": [] }, "prompt": "Today is {date}. Give me a short, upbeat morning briefing: a focus suggestion for the day and one tip about my Linux desktop.", "model": "", "output": "notify", "offer": false },
        { "id": "stacktrace", "name": "Explain copied errors", "enabled": false, "trigger": { "type": "clipboard", "cron": "", "pattern": "(Traceback \\(most recent call last\\)|Exception in thread|panic: |error\\[E\\d+\\]|at .+\\(.+:\\d+:\\d+\\)|Segmentation fault)", "kinds": [] }, "prompt": "Explain this error and how to fix it, briefly:\n\n{clipboard}", "model": "", "output": "sidebar", "offer": true },
        { "id": "download-done", "name": "Summarize finished downloads", "enabled": false, "trigger": { "type": "transfer", "cron": "", "pattern": "", "kinds": ["download"] }, "prompt": "A download just finished: {input}. In one sentence, tell me what it probably is and what to do next.", "model": "", "output": "notify", "offer": false },
        { "id": "screenshot-ocr", "name": "Describe screenshots", "enabled": false, "trigger": { "type": "screenshot", "cron": "", "pattern": "", "kinds": [] }, "prompt": "Describe this screenshot in one short paragraph.", "model": "", "output": "notify", "offer": true }
    ],
    "voice": {
        "enabled": true
    }
};
