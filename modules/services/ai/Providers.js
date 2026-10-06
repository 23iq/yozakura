.pragma library
.import "Effort.js" as Effort
.import "ProviderPresets.js" as Presets

// Chat providers as data + pure functions (no QML objects), so request
// building and stream parsing are unit-testable with recorded streams.
//
// Canonical conversation messages (what chats store):
//   {role: "user", content, attachments: [{type: "image", mimeType, base64, name}]}
//   {role: "assistant", content, thinking, toolCalls: [{id, name, args}], model}
//   {role: "tool", toolCallId, name, content, isError}
//   {role: "notice", content}                       (UI only, never sent)
// Tools: [{name, description, parameters (JSON schema)}]
//
// Each family implements:
//   endpoint(model, key) / headers(key) / body(messages, model, tools, opts) / parse(line, acc)
// parse() returns {text, thinking, done, error, usage} and accumulates tool
// calls in `acc`; finishTools(acc) yields [{id, name, args}].

var PROVIDERS = {
    openai: { family: "openai", label: "OpenAI", icon: "openai.svg", keyId: "OPENAI_API_KEY", base: "https://api.openai.com/v1", models: "/models", tools: true, images: true, usage: true },
    gemini: { family: "gemini", label: "Google Gemini", icon: "google.svg", keyId: "GEMINI_API_KEY", base: "https://generativelanguage.googleapis.com/v1beta", tools: true, images: true },
    anthropic: { family: "anthropic", label: "Anthropic", icon: "anthropic.svg", keyId: "ANTHROPIC_API_KEY", base: "https://api.anthropic.com/v1", models: "/models", tools: true, images: true },
    mistral: { family: "openai", label: "Mistral", icon: "mistral.svg", keyId: "MISTRAL_API_KEY", base: "https://api.mistral.ai/v1", models: "/models", tools: true, images: false },
    groq: { family: "openai", label: "Groq", icon: "groq.svg", keyId: "GROQ_API_KEY", base: "https://api.groq.com/openai/v1", models: "/models", tools: true, images: false },
    openrouter: { family: "openai", label: "OpenRouter", icon: "openrouter.svg", keyId: "OPENROUTER_API_KEY", base: "https://openrouter.ai/api/v1", models: "/models", tools: true, images: true, usage: true },
    deepseek: { family: "openai", label: "DeepSeek", icon: "deepseek.svg", keyId: "DEEPSEEK_API_KEY", base: "https://api.deepseek.com/v1", models: "/models", tools: true, images: false, usage: true },
    minimax: { family: "anthropic", label: "MiniMax", icon: "minimax.svg", keyId: "MINIMAX_API_KEY", base: "https://api.minimax.io/anthropic/v1", bearer: true, tools: true, images: false },
    ollama: { family: "ollama", label: "Ollama", icon: "ollama.svg", keyId: "", base: "http://127.0.0.1:11434", local: true, tools: true, images: true },
    custom: { family: "openai", label: "Custom (OpenAI compatible)", icon: "openrouter.svg", keyId: "", base: "", models: "/models", tools: true, images: true }
};

var MINIMAX_MODELS = ["MiniMax-M2.7", "MiniMax-M2.7-highspeed", "MiniMax-M2.5", "MiniMax-M2.5-highspeed", "MiniMax-M2.1", "MiniMax-M2"];

function provider(id) {
    return PROVIDERS[id] || PROVIDERS.custom;
}

function family(id) {
    return provider(id).family;
}

// A model's tool support: the provider must speak tools and the model's
// capability record (models.json / Ollama probe) must not say otherwise.
function supportsTools(model) {
    if (!model)
        return false;
    var p = provider(model.provider);
    var info = model.info || {};
    return !!p.tools && model.tools !== false && info.tools !== false;
}

// ── message normalization ──────────────────────────────────────────────

// Converts legacy chat files (role "function", assistant.functionCall) to the
// canonical form and drops UI-only notices.
function normalize(messages) {
    var out = [];
    var legacy = 0;
    for (var i = 0; i < (messages || []).length; i++) {
        var m = messages[i];
        if (!m || m.role === "notice" || m.role === "system")
            continue;
        if (m.role === "function") {
            out.push({ role: "tool", toolCallId: "legacy_" + Math.max(0, legacy - 1), name: m.name || "tool", content: String(m.content || "") });
            continue;
        }
        if (m.role === "assistant") {
            var a = { role: "assistant", content: m.content || "" };
            if (m.signature) {
                a.thinking = m.thinking || "";
                a.signature = m.signature;
            }
            if (m.toolCalls && m.toolCalls.length > 0) {
                a.toolCalls = m.toolCalls;
            } else if (m.functionCall) {
                legacy++;
                a.toolCalls = [{ id: "legacy_" + (legacy - 1), name: m.functionCall.name, args: m.functionCall.args || {} }];
            }
            if (!a.content && !a.toolCalls)
                continue; // empty placeholder from an aborted stream
            out.push(a);
            continue;
        }
        if (m.role === "tool" || m.role === "user")
            out.push(m);
    }
    return out;
}

function _images(m) {
    var list = [];
    var atts = m.attachments || [];
    for (var i = 0; i < atts.length; i++)
        if (atts[i].type === "image" && atts[i].base64)
            list.push(atts[i]);
    return list;
}

// Text attachments (files, selection, window info) are inlined into the prompt.
function userText(m) {
    var text = m.content || "";
    var atts = m.attachments || [];
    var extra = [];
    for (var i = 0; i < atts.length; i++) {
        var a = atts[i];
        if (a.type === "text" && a.text)
            extra.push("<context name=\"" + (a.name || a.kind || "context") + "\">\n" + a.text + "\n</context>");
    }
    return extra.length > 0 ? extra.join("\n\n") + "\n\n" + text : text;
}

// ── JSON schema cleanup (Gemini accepts an OpenAPI subset only) ─────────

var GEMINI_KEYS = { type: 1, description: 1, properties: 1, required: 1, items: 1, "enum": 1, nullable: 1, format: 1, minimum: 1, maximum: 1, anyOf: 1 };

function geminiSchema(schema) {
    if (!schema || typeof schema !== "object")
        return schema;
    if (Array.isArray(schema))
        return schema.map(geminiSchema);
    var out = {};
    for (var k in schema) {
        if (!GEMINI_KEYS[k])
            continue;
        if (k === "properties") {
            out.properties = {};
            for (var p in schema.properties)
                out.properties[p] = geminiSchema(schema.properties[p]);
        } else if (k === "type" && Array.isArray(schema.type)) {
            var t = schema.type.filter(function (x) {
                return x !== "null";
            });
            out.type = t.length > 0 ? t[0] : "string";
            if (t.length !== schema.type.length)
                out.nullable = true;
        } else if (k === "format" && ["enum", "date-time"].indexOf(schema.format) < 0) {
            continue;
        } else {
            out[k] = geminiSchema(schema[k]);
        }
    }
    if (out.type === "object" && !out.properties)
        out.properties = {};
    return out;
}

// ── request building ───────────────────────────────────────────────────

function endpoint(model, key) {
    var p = provider(model.provider);
    var base = (model.endpoint || p.base || "").replace(/\/+$/, "");
    switch (p.family) {
    case "gemini":
        // The key goes in the x-goog-api-key header (see headers()), never
        // in the URL, which would expose it in curl's argv.
        return base + "/models/" + model.model + ":streamGenerateContent?alt=sse";
    case "anthropic":
        return /\/messages$/.test(base) ? base : base + "/messages";
    case "ollama":
        return base + "/api/chat";
    default:
        if (/\/chat\/completions$/.test(base))
            return base;
        return (/\/v1$/.test(base) ? base : base + (model.provider === "custom" ? "" : "/v1")) + "/chat/completions";
    }
}

function headers(model, key) {
    var p = provider(model.provider);
    var h = ["Content-Type: application/json"];
    if (p.family === "anthropic") {
        if (p.bearer)
            h.push("Authorization: Bearer " + key);
        else
            h.push("x-api-key: " + key);
        h.push("anthropic-version: 2023-06-01");
    } else if (p.family === "gemini") {
        h.push("x-goog-api-key: " + (key || ""));
    } else if (p.family === "openai" && key) {
        h.push("Authorization: Bearer " + key);
    }
    return h;
}

// Model-list request for a keyed provider: {url, headers}; the key is only
// in the headers (written to a 0600 header file by HttpGet).
function modelsRequest(id, key) {
    var p = provider(id);
    if (p.family === "gemini")
        return { url: p.base + "/models?pageSize=200", headers: ["x-goog-api-key: " + key] };
    if (p.family === "anthropic")
        return { url: p.base + (p.models || "/models") + "?limit=100", headers: ["x-api-key: " + key, "anthropic-version: 2023-06-01"] };
    return { url: p.base + (p.models || "/models"), headers: ["Authorization: Bearer " + key] };
}

// Custom curl template -> {script, env}. Placeholders become environment
// variable references, so the key never appears in the script (argv) and
// no value is ever parsed by the shell or by String.replace patterns.
function customCurl(template, vals) {
    var v = vals || {};
    var script = String(template || "").split("{{ENDPOINT}}").join("${AI_ENDPOINT}").split("{{API_KEY}}").join("${AI_API_KEY}").split("{{BODY_PATH}}").join("${AI_BODY_PATH}");
    return { script: script, env: { AI_ENDPOINT: v.endpoint || "", AI_API_KEY: v.apiKey || "", AI_BODY_PATH: v.bodyPath || "" } };
}

function _openaiMessages(system, messages) {
    var out = [];
    if (system)
        out.push({ role: "system", content: system });
    for (var i = 0; i < messages.length; i++) {
        var m = messages[i];
        if (m.role === "user") {
            var imgs = _images(m);
            if (imgs.length > 0) {
                var parts = [{ type: "text", text: userText(m) }];
                for (var j = 0; j < imgs.length; j++)
                    parts.push({ type: "image_url", image_url: { url: "data:" + imgs[j].mimeType + ";base64," + imgs[j].base64 } });
                out.push({ role: "user", content: parts });
            } else {
                out.push({ role: "user", content: userText(m) });
            }
        } else if (m.role === "assistant") {
            var a = { role: "assistant", content: m.content || "" };
            if (m.toolCalls && m.toolCalls.length > 0) {
                a.tool_calls = m.toolCalls.map(function (c) {
                    return { id: c.id, type: "function", "function": { name: c.name, arguments: JSON.stringify(c.args || {}) } };
                });
                if (!a.content)
                    a.content = null;
            }
            out.push(a);
        } else if (m.role === "tool") {
            out.push({ role: "tool", tool_call_id: m.toolCallId, name: m.name, content: String(m.content || "") });
        }
    }
    return out;
}

function _anthropicMessages(messages) {
    var out = [];
    function push(role, block) {
        var last = out.length > 0 ? out[out.length - 1] : null;
        if (last && last.role === role)
            last.content.push(block);
        else
            out.push({ role: role, content: [block] });
    }
    for (var i = 0; i < messages.length; i++) {
        var m = messages[i];
        if (m.role === "user") {
            var imgs = _images(m);
            for (var j = 0; j < imgs.length; j++)
                push("user", { type: "image", source: { type: "base64", media_type: imgs[j].mimeType, data: imgs[j].base64 } });
            push("user", { type: "text", text: userText(m) || " " });
        } else if (m.role === "assistant") {
            // With extended thinking, a tool loop must hand the signed
            // thinking block back before the tool_use it led to.
            if (m.thinking && m.signature)
                push("assistant", { type: "thinking", thinking: m.thinking, signature: m.signature });
            if (m.content)
                push("assistant", { type: "text", text: m.content });
            var calls = m.toolCalls || [];
            for (var c = 0; c < calls.length; c++)
                push("assistant", { type: "tool_use", id: calls[c].id, name: calls[c].name, input: calls[c].args || {} });
        } else if (m.role === "tool") {
            push("user", { type: "tool_result", tool_use_id: m.toolCallId, content: String(m.content || ""), is_error: !!m.isError });
        }
    }
    return out;
}

function _geminiContents(messages) {
    var out = [];
    var names = {};
    function push(role, part) {
        var last = out.length > 0 ? out[out.length - 1] : null;
        if (last && last.role === role)
            last.parts.push(part);
        else
            out.push({ role: role, parts: [part] });
    }
    for (var i = 0; i < messages.length; i++) {
        var m = messages[i];
        if (m.role === "user") {
            push("user", { text: userText(m) || " " });
            var imgs = _images(m);
            for (var j = 0; j < imgs.length; j++)
                push("user", { inline_data: { mime_type: imgs[j].mimeType, data: imgs[j].base64 } });
        } else if (m.role === "assistant") {
            if (m.content)
                push("model", { text: m.content });
            var calls = m.toolCalls || [];
            for (var c = 0; c < calls.length; c++) {
                names[calls[c].id] = calls[c].name;
                push("model", { functionCall: { name: calls[c].name, args: calls[c].args || {} } });
            }
        } else if (m.role === "tool") {
            push("user", { functionResponse: { name: m.name || names[m.toolCallId] || "tool", response: { content: String(m.content || "") } } });
        }
    }
    return out;
}

function _ollamaMessages(system, messages) {
    var out = [];
    if (system)
        out.push({ role: "system", content: system });
    for (var i = 0; i < messages.length; i++) {
        var m = messages[i];
        if (m.role === "user") {
            var u = { role: "user", content: userText(m) };
            var imgs = _images(m);
            if (imgs.length > 0)
                u.images = imgs.map(function (x) {
                    return x.base64;
                });
            out.push(u);
        } else if (m.role === "assistant") {
            var a = { role: "assistant", content: m.content || "" };
            if (m.toolCalls && m.toolCalls.length > 0)
                a.tool_calls = m.toolCalls.map(function (c) {
                    return { "function": { name: c.name, arguments: c.args || {} } };
                });
            out.push(a);
        } else if (m.role === "tool") {
            out.push({ role: "tool", content: String(m.content || ""), tool_name: m.name });
        }
    }
    return out;
}

// opts: {system, maxTokens, temperature, effort (off|low|medium|high|max,
// mapped by Effort.js from the model's capability record `model.info`),
// numCtx (Ollama context length to allocate)}
function body(messages, model, tools, opts) {
    var o = opts || {};
    var msgs = normalize(messages);
    var t = tools && tools.length > 0 && supportsTools(model) ? tools : [];
    var fam = family(model.provider);
    var b;
    if (fam === "anthropic") {
        b = { model: model.model, messages: _anthropicMessages(msgs), max_tokens: o.maxTokens || 8192, stream: true };
        if (o.system)
            b.system = o.system;
        if (t.length > 0)
            b.tools = t.map(function (x) {
                return { name: x.name, description: x.description || "", input_schema: x.parameters || { type: "object", properties: {} } };
            });
    } else if (fam === "gemini") {
        b = { contents: _geminiContents(msgs) };
        if (o.system)
            b.systemInstruction = { parts: [{ text: o.system }] };
        if (t.length > 0)
            b.tools = [{ functionDeclarations: t.map(function (x) {
                        return { name: x.name, description: x.description || "", parameters: geminiSchema(x.parameters || { type: "object", properties: {} }) };
                    }) }];
    } else if (fam === "ollama") {
        b = { model: model.model, messages: _ollamaMessages(o.system, msgs), stream: true };
        // Ollama's default context is a few thousand tokens: without
        // num_ctx it silently drops the start of longer chats.
        if (o.numCtx > 0)
            b.options = { num_ctx: o.numCtx };
        if (t.length > 0)
            b.tools = t.map(function (x) {
                return { type: "function", "function": { name: x.name, description: x.description || "", parameters: x.parameters || { type: "object", properties: {} } } };
            });
    } else {
        b = { model: model.model, messages: _openaiMessages(o.system, msgs), stream: true };
        if (provider(model.provider).usage)
            b.stream_options = { include_usage: true };
        if (t.length > 0)
            b.tools = t.map(function (x) {
                return { type: "function", "function": { name: x.name, description: x.description || "", parameters: x.parameters || { type: "object", properties: {} } } };
            });
    }
    if (o.temperature !== undefined && fam !== "gemini")
        b.temperature = o.temperature;
    if (o.effort && model.info)
        b = Effort.apply(b, Presets.effortFamily(model.provider), o.effort, model.info);
    return b;
}

// ── stream parsing ─────────────────────────────────────────────────────

function newAccumulator() {
    return { calls: [], byIndex: {}, byId: {}, text: "", thinking: "", signature: "", usage: null, sawDone: false };
}

function _call(acc, key) {
    if (acc.byIndex[key] === undefined) {
        acc.byIndex[key] = acc.calls.length;
        acc.calls.push({ id: "", name: "", argsText: "", args: null });
    }
    return acc.calls[acc.byIndex[key]];
}

function _result() {
    return { text: "", thinking: "", done: false, error: "", usage: null };
}

function _data(line) {
    var t = line.trim();
    if (t.indexOf("data:") !== 0)
        return null;
    var payload = t.substring(5).trim();
    if (payload === "[DONE]")
        return "[DONE]";
    try {
        return JSON.parse(payload);
    } catch (e) {
        return null;
    }
}

function _errorText(json) {
    if (!json)
        return "";
    if (typeof json.error === "string")
        return json.error;
    if (json.error && json.error.message)
        return json.error.message;
    if (json.type === "error" && json.message)
        return json.message;
    return "";
}

function _parseOpenAI(line, acc) {
    var r = _result();
    var t = line.trim();
    if (t.charAt(0) === "{") {
        // Non-SSE error body (HTTP 4xx without stream)
        try {
            r.error = _errorText(JSON.parse(t));
        } catch (e) {}
        return r;
    }
    var json = _data(line);
    if (json === "[DONE]") {
        r.done = true;
        acc.sawDone = true;
        return r;
    }
    if (!json)
        return r;
    r.error = _errorText(json);
    if (json.usage)
        r.usage = acc.usage = { inputTokens: json.usage.prompt_tokens || 0, outputTokens: json.usage.completion_tokens || 0 };
    var choice = json.choices && json.choices.length > 0 ? json.choices[0] : null;
    if (!choice)
        return r;
    var d = choice.delta || choice.message || {};
    if (d.content)
        r.text = d.content;
    if (d.reasoning_content)
        r.thinking = d.reasoning_content;
    else if (typeof d.reasoning === "string")
        r.thinking = d.reasoning;
    var tcs = d.tool_calls || [];
    for (var i = 0; i < tcs.length; i++) {
        var tc = tcs[i];
        var c = _call(acc, tc.index !== undefined ? tc.index : i);
        if (tc.id)
            c.id = tc.id;
        if (tc["function"]) {
            if (tc["function"].name)
                c.name += tc["function"].name;
            if (tc["function"].arguments)
                c.argsText += tc["function"].arguments;
        }
    }
    return r;
}

function _parseAnthropic(line, acc) {
    var r = _result();
    var t = line.trim();
    if (t.charAt(0) === "{") {
        try {
            r.error = _errorText(JSON.parse(t));
        } catch (e) {}
        return r;
    }
    var json = _data(line);
    if (!json || json === "[DONE]")
        return r;
    switch (json.type) {
    case "content_block_start":
        if (json.content_block && json.content_block.type === "tool_use") {
            var c = _call(acc, json.index);
            c.id = json.content_block.id;
            c.name = json.content_block.name;
        }
        break;
    case "content_block_delta":
        if (!json.delta)
            break;
        if (json.delta.type === "text_delta")
            r.text = json.delta.text || "";
        else if (json.delta.type === "thinking_delta")
            r.thinking = json.delta.thinking || "";
        else if (json.delta.type === "signature_delta")
            acc.signature += json.delta.signature || "";
        else if (json.delta.type === "input_json_delta")
            _call(acc, json.index).argsText += json.delta.partial_json || "";
        break;
    case "message_start":
        // input_tokens excludes cache reads/writes; the prompt is all three.
        if (json.message && json.message.usage) {
            var mu = json.message.usage;
            acc.usage = { inputTokens: (mu.input_tokens || 0) + (mu.cache_read_input_tokens || 0) + (mu.cache_creation_input_tokens || 0), outputTokens: 0, cachedTokens: mu.cache_read_input_tokens || 0 };
        }
        break;
    case "message_delta":
        if (json.usage) {
            acc.usage = acc.usage || { inputTokens: 0, outputTokens: 0 };
            acc.usage.outputTokens = json.usage.output_tokens || 0;
            r.usage = acc.usage;
        }
        break;
    case "message_stop":
        r.done = true;
        acc.sawDone = true;
        break;
    case "error":
        r.error = _errorText(json) || "Stream error";
        break;
    }
    return r;
}

function _parseGemini(line, acc) {
    var r = _result();
    var t = line.trim();
    var json = t.charAt(0) === "{" || t.charAt(0) === "[" ? null : _data(line);
    if (!json && (t.charAt(0) === "{" || t.charAt(0) === "[")) {
        try {
            var parsed = JSON.parse(t.charAt(0) === "[" ? t.replace(/,\s*$/, "") + (t.endsWith("]") ? "" : "]") : t);
            json = Array.isArray(parsed) ? parsed[0] : parsed;
        } catch (e) {
            return r;
        }
    }
    if (!json || json === "[DONE]")
        return r;
    r.error = _errorText(json);
    if (json.usageMetadata)
        r.usage = acc.usage = { inputTokens: json.usageMetadata.promptTokenCount || 0, outputTokens: json.usageMetadata.candidatesTokenCount || 0 };
    var cand = json.candidates && json.candidates.length > 0 ? json.candidates[0] : null;
    if (!cand)
        return r;
    var parts = cand.content && cand.content.parts ? cand.content.parts : [];
    for (var i = 0; i < parts.length; i++) {
        var p = parts[i];
        if (p.functionCall) {
            var c = _call(acc, "g" + acc.calls.length);
            c.id = "call_" + acc.calls.length + "_" + p.functionCall.name;
            c.name = p.functionCall.name;
            c.args = p.functionCall.args || {};
        } else if (p.text) {
            if (p.thought)
                r.thinking += p.text;
            else
                r.text += p.text;
        }
    }
    if (cand.finishReason) {
        r.done = true;
        acc.sawDone = true;
    }
    return r;
}

function _parseOllama(line, acc) {
    var r = _result();
    var t = line.trim();
    if (!t)
        return r;
    var json;
    try {
        json = JSON.parse(t);
    } catch (e) {
        return r;
    }
    r.error = _errorText(json);
    var msg = json.message || {};
    if (msg.content)
        r.text = msg.content;
    if (msg.thinking)
        r.thinking = msg.thinking;
    var tcs = msg.tool_calls || [];
    for (var i = 0; i < tcs.length; i++) {
        var c = _call(acc, "o" + acc.calls.length);
        c.id = "call_" + acc.calls.length;
        c.name = tcs[i]["function"] ? tcs[i]["function"].name : "";
        var args = tcs[i]["function"] ? tcs[i]["function"].arguments : {};
        if (typeof args === "string")
            c.argsText = args;
        else
            c.args = args || {};
    }
    if (json.done) {
        r.done = true;
        acc.sawDone = true;
        r.usage = acc.usage = { inputTokens: json.prompt_eval_count || 0, outputTokens: json.eval_count || 0 };
    }
    return r;
}

function parse(providerId, line, acc) {
    var r;
    switch (family(providerId)) {
    case "anthropic":
        r = _parseAnthropic(line, acc);
        break;
    case "gemini":
        r = _parseGemini(line, acc);
        break;
    case "ollama":
        r = _parseOllama(line, acc);
        break;
    default:
        r = _parseOpenAI(line, acc);
    }
    acc.text += r.text;
    acc.thinking += r.thinking;
    return r;
}

// Completed tool calls with parsed arguments; malformed JSON yields
// {_raw: "..."} so the caller can report it to the model instead of crashing.
function finishTools(acc) {
    var out = [];
    for (var i = 0; i < acc.calls.length; i++) {
        var c = acc.calls[i];
        if (!c.name)
            continue;
        var args = c.args;
        if (!args) {
            try {
                args = c.argsText ? JSON.parse(c.argsText) : {};
            } catch (e) {
                args = { _raw: c.argsText };
            }
        }
        out.push({ id: c.id || ("call_" + i), name: c.name, args: args });
    }
    return out;
}

// ── model lists ────────────────────────────────────────────────────────

var OPENAI_ALLOWED = /^(gpt-|o\d|chatgpt-)/;
var OPENAI_EXCLUDED = /(audio|realtime|transcribe|tts|image|embedding|moderation|search|instruct|davinci|babbage|dall-e|whisper)/;

// Parses a provider's model listing into [{id, name, description}].
function parseModelList(providerId, text) {
    var json;
    try {
        json = JSON.parse(text);
    } catch (e) {
        return [];
    }
    var out = [];
    if (providerId === "gemini") {
        var gm = json.models || [];
        for (var i = 0; i < gm.length; i++) {
            var methods = gm[i].supportedGenerationMethods || ["generateContent"];
            if (methods.indexOf("generateContent") < 0)
                continue;
            var id = String(gm[i].name || "").replace(/^models\//, "");
            if (!/gemini|gemma/.test(id) || /embedding|aqa|imagen|tts|image/.test(id))
                continue;
            out.push({ id: id, name: gm[i].displayName || id, description: gm[i].description || "" });
        }
        return out;
    }
    if (providerId === "ollama") {
        var om = json.models || [];
        for (var j = 0; j < om.length; j++)
            out.push({ id: om[j].name, name: om[j].name, description: om[j].details ? [om[j].details.parameter_size, om[j].details.quantization_level].filter(Boolean).join(" · ") : "" });
        return out;
    }
    var data = json.data || [];
    for (var k = 0; k < data.length; k++) {
        var mid = data[k].id;
        if (!mid)
            continue;
        if (providerId === "openai" && (!OPENAI_ALLOWED.test(mid) || OPENAI_EXCLUDED.test(mid)))
            continue;
        if ((providerId === "groq" || providerId === "mistral") && /whisper|embed|tts|guard|moderation|ocr/.test(mid))
            continue;
        out.push({ id: mid, name: data[k].display_name || mid, description: "" });
    }
    return out;
}

// Error message from a whole (possibly pretty-printed) HTTP error body.
function errorFromBody(text) {
    var t = String(text || "").trim();
    if (!t)
        return "";
    try {
        var json = JSON.parse(t);
        if (Array.isArray(json))
            json = json[0];
        var msg = _errorText(json);
        if (msg)
            return msg;
    } catch (e) {}
    var lines = t.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var d = _data(lines[i]);
        if (d && d !== "[DONE]" && _errorText(d))
            return _errorText(d);
    }
    return t.length > 300 ? t.substring(0, 300) + "…" : t;
}
