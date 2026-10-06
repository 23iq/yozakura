.pragma library

// Unified reasoning effort: one level set for every model, mapped to each
// provider family's request parameters. Pure data + functions, no QML.
//
// `info` is a model capability record: an entry of assets/ai/models.json
// (or the result of the backend `providers.models.info`), or an Ollama
// probe result ({family, capabilities: [... "thinking" ...]}). Fields used:
//   reasoning   "openai_effort" | "anthropic_budget" | "gemini_budget" |
//               "gemini_level" | "ollama_think" | "none"
//   efforts     unified levels the model accepts
//   effortMap   provider value per level when it differs from the name
//   budget      {min, max} thinking tokens (budget styles)
//   maxOutput   output token limit
// Families: "openai" (also any OpenAI-compatible host), "anthropic",
// "gemini", "ollama", "openrouter".

var LEVELS = ["off", "low", "medium", "high", "max"];

// Thinking-token budgets per level.
var ANTHROPIC_BUDGETS = { low: 2048, medium: 8192, high: 16384, max: 32768 };
var GEMINI_BUDGETS = { low: 1024, medium: 8192, high: 16384, max: 32768 };
var ANTHROPIC_MIN_BUDGET = 1024;
// Room left for the answer on top of the thinking budget.
var ANSWER_TOKENS = 4096;

function normalize(level) {
    var l = String(level || "").toLowerCase();
    return LEVELS.indexOf(l) >= 0 ? l : "";
}

function _isGptOss(info) {
    var s = String((info && (info.id || info.model || info.prefix)) || "") + " " + String((info && info.family) || "");
    return /gpt-?oss/i.test(s);
}

// Reasoning style of a capability record.
function style(info) {
    if (!info)
        return "none";
    if (info.reasoning)
        return info.reasoning;
    var caps = info.capabilities || [];
    return caps.indexOf("thinking") >= 0 ? "ollama_think" : "none";
}

// Levels the model supports, in LEVELS order; [] hides the effort control.
// Boolean thinking (most Ollama models) is offered as off / high.
function levelsFor(info) {
    var st = style(info);
    if (st === "none")
        return [];
    if (st === "ollama_think")
        return _isGptOss(info) ? ["low", "medium", "high"] : ["off", "high"];
    var allowed = info.efforts;
    if (!allowed || allowed.length === 0) {
        switch (st) {
        case "openai_effort":
            allowed = ["low", "medium", "high"];
            break;
        case "anthropic_budget":
            allowed = LEVELS;
            break;
        case "gemini_budget":
            allowed = info.budget && info.budget.min === 0 ? LEVELS : ["low", "medium", "high", "max"];
            break;
        case "gemini_level":
            allowed = ["low", "high"];
            break;
        default:
            allowed = [];
        }
    }
    return LEVELS.filter(function (l) {
        return allowed.indexOf(l) >= 0;
    });
}

function defaultLevel(info) {
    var levels = levelsFor(info);
    if (levels.indexOf("medium") >= 0)
        return "medium";
    if (levels.indexOf("high") >= 0)
        return "high";
    return levels.length > 0 ? levels[0] : "";
}

// The supported level closest to `level` ("" when the model has no effort
// control). An unsupported "off" stays "" so the provider default applies.
function resolve(level, info) {
    var levels = levelsFor(info);
    var l = normalize(level);
    if (levels.length === 0 || !l)
        return "";
    if (levels.indexOf(l) >= 0)
        return l;
    if (l === "off")
        return "";
    var want = LEVELS.indexOf(l);
    var best = "";
    var dist = 99;
    for (var i = 0; i < levels.length; i++) {
        var d = Math.abs(LEVELS.indexOf(levels[i]) - want);
        // Ties go to the lower level (cheaper).
        if (levels[i] !== "off" && d < dist) {
            best = levels[i];
            dist = d;
        }
    }
    return best;
}

function _mapped(level, info) {
    var m = (info && info.effortMap) || {};
    if (m[level])
        return m[level];
    return level === "off" ? "" : level;
}

function _anthropicBudget(level, info) {
    var b = ANTHROPIC_BUDGETS[level] || 0;
    var maxOut = info && info.maxOutput;
    if (maxOut && b > maxOut - ANSWER_TOKENS)
        b = maxOut - ANSWER_TOKENS;
    var min = (info && info.budget && info.budget.min) || ANTHROPIC_MIN_BUDGET;
    return b >= min ? b : 0;
}

function _geminiBudget(level, info) {
    var range = (info && info.budget) || {};
    var b = level === "off" ? 0 : GEMINI_BUDGETS[level] || 0;
    if (level === "max" && range.max)
        b = range.max;
    if (range.max && b > range.max)
        b = range.max;
    if (level !== "off" && range.min && b < range.min)
        b = range.min;
    return b;
}

// Request fields for `level` on a model of `family`: an object to merge into
// the request body ({} when nothing should be sent).
function params(family, level, info) {
    var l = resolve(level, info);
    if (!l)
        return {};
    var st = style(info);
    switch (family) {
    case "anthropic":
        if (st !== "anthropic_budget" || l === "off")
            return {};
        var ab = _anthropicBudget(l, info);
        return ab > 0 ? { thinking: { type: "enabled", budget_tokens: ab } } : {};
    case "gemini":
        if (st === "gemini_level")
            return l === "off" ? {} : { generationConfig: { thinkingConfig: { thinkingLevel: _mapped(l, info), includeThoughts: true } } };
        if (st !== "gemini_budget")
            return {};
        var gb = _geminiBudget(l, info);
        return { generationConfig: { thinkingConfig: gb > 0 ? { thinkingBudget: gb, includeThoughts: true } : { thinkingBudget: 0 } } };
    case "ollama":
        if (_isGptOss(info))
            return l === "off" ? {} : { think: l === "max" ? "high" : l };
        return { think: l !== "off" };
    case "openrouter":
        if (l === "off")
            return {};
        if (st === "anthropic_budget")
            return { reasoning: { max_tokens: _anthropicBudget(l, info) || ANTHROPIC_MIN_BUDGET } };
        if (st === "gemini_budget")
            return { reasoning: { max_tokens: _geminiBudget(l, info) } };
        return { reasoning: { effort: _mapped(l, info) } };
    default:
        if (st !== "openai_effort")
            return {};
        var v = _mapped(l, info);
        return v ? { reasoning_effort: v } : {};
    }
}

function _merge(dst, src) {
    for (var k in src) {
        var v = src[k];
        if (v && typeof v === "object" && !Array.isArray(v) && dst[k] && typeof dst[k] === "object")
            dst[k] = _merge(Object.assign({}, dst[k]), v);
        else
            dst[k] = v;
    }
    return dst;
}

// A copy of request `body` with the effort fields merged in. For Anthropic
// thinking it also makes max_tokens exceed the budget (within maxOutput)
// and drops sampling fields that thinking does not allow.
function apply(body, family, level, info) {
    var out = _merge(Object.assign({}, body || {}), params(family, level, info));
    if (family === "anthropic" && out.thinking) {
        var budget = out.thinking.budget_tokens;
        var maxOut = info && info.maxOutput;
        if (!out.max_tokens || out.max_tokens <= budget)
            out.max_tokens = budget + ANSWER_TOKENS;
        if (maxOut && out.max_tokens > maxOut)
            out.max_tokens = maxOut;
        if (out.max_tokens <= budget)
            delete out.thinking;
        else {
            delete out.temperature;
            delete out.top_k;
        }
    }
    return out;
}
