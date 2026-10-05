.pragma library

// Pure helpers for voice input (VoiceService / VoicePanel / settings).
// Session states and reasons come from backend/pkg/svc/voice/session.go.

var ACTIVATIONS = ["push-to-talk", "toggle"];
var TYPING_METHODS = ["auto", "wtype", "ydotool", "clipboard"];
var MODELS = ["large-v3-turbo-q5_0", "large-v3-turbo-q8_0"];
// Languages offered in settings; any whisper code also works in voice.json.
var LANGUAGES = ["auto", "en", "ru", "ja", "es", "de", "fr", "uk", "zh", "ko"];

var ACTIVE_STATES = ["listening", "transcribing"];
var TERMINAL_STATES = ["done", "empty", "cancelled", "error"];

function isActive(state) {
    return ACTIVE_STATES.indexOf(state) !== -1;
}

function isTerminal(state) {
    return TERMINAL_STATES.indexOf(state) !== -1;
}

// "m:ss" for the elapsed timer.
function formatElapsed(ms) {
    var total = Math.max(0, Math.floor((ms || 0) / 1000));
    var m = Math.floor(total / 60);
    var s = total % 60;
    return m + ":" + (s < 10 ? "0" : "") + s;
}

// Badge text: detected or configured code, "AUTO" while detecting.
function languageBadge(lang) {
    if (!lang || lang === "auto")
        return "AUTO";
    return String(lang).toUpperCase();
}

// Translation key for the status line of a snapshot.
function statusKey(snap) {
    if (!snap)
        return "";
    switch (snap.state) {
    case "listening":
        return snap.target === "dictation" ? "voice.status.dictating" : "voice.status.listening";
    case "transcribing":
        return "voice.status.transcribing";
    case "done":
        return "voice.status.done";
    case "empty":
        return "voice.status.no_speech";
    case "cancelled":
        return "voice.status.cancelled";
    case "error":
        return errorKey(snap.error);
    }
    return "";
}

function errorKey(error) {
    switch (error) {
    case "disabled":
        return "voice.error.disabled";
    case "not_installed":
        return "voice.error.not_installed";
    case "model_missing":
        return "voice.error.model_missing";
    }
    return "voice.error.generic";
}

// Where a "voice to AI" transcript goes: the sidebar input when the
// assistant sidebar is open, otherwise the notch quick-ask.
function aiTarget(sidebarOpen) {
    return sidebarOpen ? "sidebar" : "notch";
}

// Hands a transcript to the AI center's voice entry point when it exists
// (feat/ai-center: Ai.handleVoice(text, target)). Returns false when the
// AI service has no such API so the caller can fall back.
function tryHandleVoice(ai, text, target) {
    if (ai && typeof ai.handleVoice === "function") {
        ai.handleVoice(text, target);
        return true;
    }
    return false;
}

// Bars for the visualizer: resample backend bands (any length) to count,
// with a floor so the idle waveform still breathes.
function resampleBands(bands, count, floor) {
    var out = [];
    var n = bands ? bands.length : 0;
    for (var i = 0; i < count; i++) {
        var v = 0;
        if (n > 0) {
            var pos = (i + 0.5) * n / count - 0.5;
            var a = Math.max(0, Math.min(n - 1, Math.floor(pos)));
            var b = Math.min(n - 1, a + 1);
            var t = Math.max(0, pos - a);
            v = bands[a] * (1 - t) + bands[b] * t;
        }
        out.push(Math.max(floor || 0, Math.min(1, v)));
    }
    return out;
}

// Exponential smoothing toward new bars: fast attack, slow decay (cava).
function smoothBands(prev, next, attack, decay) {
    var out = [];
    for (var i = 0; i < next.length; i++) {
        var p = prev && i < prev.length ? prev[i] : 0;
        var k = next[i] > p ? attack : decay;
        out.push(p + (next[i] - p) * k);
    }
    return out;
}
