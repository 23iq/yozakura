.pragma library

// Chat provider presets for the "Connect provider" sheet: what the user
// picks from, with where to get a key. Pure data + lookups, no QML.
//
// Fields:
//   id          provider id (chat model `provider`, backend providers.test)
//   label       display name (a brand name, not translated)
//   icon        file in assets/aiproviders/ ("" = use a generic glyph)
//   baseUrl     default API base; editable for local/custom providers
//   keyRequired whether an API key is needed
//   keyUrl      page where the user creates a key ("" = none)
//   keyId       keystore id of the key ("" = no key)
//   family      request format: "openai" | "anthropic" | "gemini" | "ollama"
//   effortFamily family for Effort.params() (OpenRouter has its own)
//   local       runs on this machine (no key, probed instead of tested)
//   editableUrl the base URL field is shown

var PRESETS = [
    { id: "openai", label: "OpenAI", icon: "openai.svg", baseUrl: "https://api.openai.com/v1", keyRequired: true, keyUrl: "https://platform.openai.com/api-keys", keyId: "OPENAI_API_KEY", family: "openai" },
    { id: "anthropic", label: "Anthropic", icon: "anthropic.svg", baseUrl: "https://api.anthropic.com/v1", keyRequired: true, keyUrl: "https://console.anthropic.com/settings/keys", keyId: "ANTHROPIC_API_KEY", family: "anthropic" },
    { id: "gemini", label: "Google Gemini", icon: "gemini.svg", baseUrl: "https://generativelanguage.googleapis.com/v1beta", keyRequired: true, keyUrl: "https://aistudio.google.com/apikey", keyId: "GEMINI_API_KEY", family: "gemini" },
    { id: "mistral", label: "Mistral", icon: "mistral.svg", baseUrl: "https://api.mistral.ai/v1", keyRequired: true, keyUrl: "https://console.mistral.ai/api-keys", keyId: "MISTRAL_API_KEY", family: "openai" },
    { id: "groq", label: "Groq", icon: "groq.svg", baseUrl: "https://api.groq.com/openai/v1", keyRequired: true, keyUrl: "https://console.groq.com/keys", keyId: "GROQ_API_KEY", family: "openai" },
    { id: "minimax", label: "MiniMax", icon: "minimax.svg", baseUrl: "https://api.minimax.io/anthropic/v1", keyRequired: true, keyUrl: "https://platform.minimax.io/user-center/basic-information/interface-key", keyId: "MINIMAX_API_KEY", family: "anthropic" },
    { id: "openrouter", label: "OpenRouter", icon: "openrouter.svg", baseUrl: "https://openrouter.ai/api/v1", keyRequired: true, keyUrl: "https://openrouter.ai/settings/keys", keyId: "OPENROUTER_API_KEY", family: "openai", effortFamily: "openrouter" },
    { id: "deepseek", label: "DeepSeek", icon: "deepseek.svg", baseUrl: "https://api.deepseek.com/v1", keyRequired: true, keyUrl: "https://platform.deepseek.com/api_keys", keyId: "DEEPSEEK_API_KEY", family: "openai" },
    { id: "lmstudio", label: "LM Studio", icon: "lmstudio.svg", baseUrl: "http://127.0.0.1:1234/v1", keyRequired: false, keyUrl: "", keyId: "", family: "openai", local: true, editableUrl: true },
    { id: "ollama", label: "Ollama", icon: "ollama.svg", baseUrl: "http://127.0.0.1:11434", keyRequired: false, keyUrl: "", keyId: "", family: "ollama", local: true, editableUrl: true },
    { id: "custom", label: "Custom (OpenAI compatible)", icon: "", baseUrl: "", keyRequired: false, keyUrl: "", keyId: "CUSTOM_API_KEY", family: "openai", editableUrl: true }
];

function ids() {
    return PRESETS.map(function (p) {
        return p.id;
    });
}

// The preset for id, or null.
function preset(id) {
    for (var i = 0; i < PRESETS.length; i++)
        if (PRESETS[i].id === id)
            return PRESETS[i];
    return null;
}

// Request family (unknown ids are treated as OpenAI compatible).
function family(id) {
    var p = preset(id);
    return p ? p.family : "openai";
}

// Family for Effort.params().
function effortFamily(id) {
    var p = preset(id);
    return p ? p.effortFamily || p.family : "openai";
}

function needsKey(id) {
    var p = preset(id);
    return !!(p && p.keyRequired);
}

// Remote providers first (alphabetical by label), then local, then custom.
function sorted() {
    var rank = function (p) {
        return p.id === "custom" ? 2 : p.local ? 1 : 0;
    };
    return PRESETS.slice().sort(function (a, b) {
        return rank(a) - rank(b) || a.label.localeCompare(b.label);
    });
}

// Whether a provider is usable with the given key/base URL (connection
// state shown in the model picker: "OpenAI — not connected").
function isConnected(id, key, baseUrl) {
    var p = preset(id);
    if (!p)
        return !!baseUrl;
    if (p.keyRequired)
        return !!key;
    if (p.id === "custom")
        return !!baseUrl;
    return true;
}
