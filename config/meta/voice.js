.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/voice.js (format: config/meta/Meta.js).

var description = "Voice input (local whisper.cpp): model, language, push-to-talk/toggle activation, voice activity detection and how dictated text is typed.";

var keys = {
    "enabled": {
        "description": "Enable voice input."
    },
    "model": {
        "enum": Enums.VOICE_MODELS,
        "description": "Whisper model."
    },
    "language": {
        "enum": Enums.VOICE_LANGUAGES,
        "description": "Spoken language (auto = detect)."
    },
    "activation": {
        "enum": Enums.VOICE_ACTIVATIONS,
        "description": "Hold the key while speaking, or press to start/stop."
    },
    "useGpu": {
        "description": "Run whisper on the GPU when available."
    },
    "maxSeconds": {
        "min": 5,
        "max": 600,
        "unit": "s",
        "description": "Longest recording."
    },
    "idleTimeout": {
        "min": 0,
        "max": 3600,
        "unit": "s",
        "description": "Unload the whisper server after this idle time."
    },
    "vadAutoStop": {
        "description": "Stop listening after a silence."
    },
    "vadSilenceMs": {
        "min": 200,
        "max": 10000,
        "unit": "ms",
        "description": "Silence that ends the recording (vadAutoStop)."
    },
    "vadSensitivity": {
        "min": 0,
        "max": 1,
        "description": "Voice activity detection sensitivity."
    },
    "noSpeechTimeout": {
        "min": 0,
        "max": 60,
        "unit": "s",
        "description": "Give up when nothing is said for this long."
    },
    "serverVad": {
        "description": "Let the whisper server detect speech (VAD)."
    },
    "typingMethod": {
        "enum": Enums.VOICE_TYPING_METHODS,
        "description": "How dictated text is typed into the focused window."
    },
    "punctuation": {
        "description": "Keep punctuation in transcripts."
    },
    "trailingSpace": {
        "description": "Add a space after dictated text."
    },
    "aiAutoSend": {
        "description": "Send voice prompts to the AI without confirmation."
    },
    "previewMs": {
        "min": 0,
        "max": 5000,
        "unit": "ms",
        "description": "Interval of the live transcript preview."
    }
};
