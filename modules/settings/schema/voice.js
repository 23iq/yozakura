.pragma library
.import "../../services/voice/VoiceModel.js" as VoiceModel

// Voice input: local whisper.cpp speech-to-text (config/defaults/voice.js,
// read by the backend at the start of every session). Entry format: see
// modules/settings/AGENTS.md.

// Option labels (literal keys keep the translation audit able to see them)
var MODEL_LABELS = {
    "large-v3-turbo-q5_0": "prefs.voice.model.large-v3-turbo-q5_0",
    "large-v3-turbo-q8_0": "prefs.voice.model.large-v3-turbo-q8_0"
};
var LANGUAGE_LABELS = {
    "auto": "prefs.voice.lang.auto",
    "en": "prefs.voice.lang.en",
    "ru": "prefs.voice.lang.ru",
    "ja": "prefs.voice.lang.ja",
    "es": "prefs.voice.lang.es",
    "de": "prefs.voice.lang.de",
    "fr": "prefs.voice.lang.fr",
    "uk": "prefs.voice.lang.uk",
    "zh": "prefs.voice.lang.zh",
    "ko": "prefs.voice.lang.ko"
};
var TYPING_LABELS = {
    "auto": "prefs.voice.typing.auto",
    "wtype": "prefs.voice.typing.wtype",
    "ydotool": "prefs.voice.typing.ydotool",
    "clipboard": "prefs.voice.typing.clipboard"
};

var ON = {
    "key": "voice.enabled",
    "equals": true
};

function toggle(key, label, keywords, description) {
    return {
        "key": key,
        "type": "toggle",
        "enabledWhen": ON,
        "label": label,
        "description": description,
        "keywords": keywords
    };
}

function seconds(key, label, min, max, step, keywords, description, special) {
    return {
        "key": key,
        "type": "number",
        "min": min,
        "max": max,
        "step": step,
        "unit": "s",
        "specialValues": special || [],
        "enabledWhen": ON,
        "label": label,
        "description": description,
        "keywords": keywords
    };
}

var category = {
    "id": "voice",
    "icon": "mic",
    "title": "prefs.cat.voice",
    "description": "prefs.cat.voice.desc",
    "keywords": "voice input speech whisper microphone dictation talk stt push to talk",
    "sections": [
        {
            "id": "voice",
            "entries": [
                {
                    "id": "voice.status",
                    "type": "custom",
                    "component": "VoiceStatus",
                    "resettable": false,
                    "label": "prefs.voice.status",
                    "description": "voice.settings.description",
                    "keywords": "voice status whisper installed model gpu setup"
                },
                {
                    "key": "voice.enabled",
                    "type": "toggle",
                    "label": "voice.settings.enabled",
                    "description": "prefs.voice.enabled.desc",
                    "keywords": "voice enable disable microphone"
                },
                {
                    "key": "voice.activation",
                    "type": "selector",
                    "options": [
                        {
                            "value": "push-to-talk",
                            "label": "voice.settings.push_to_talk",
                            "icon": "hand"
                        },
                        {
                            "value": "toggle",
                            "label": "voice.settings.toggle",
                            "icon": "mic"
                        }
                    ],
                    "enabledWhen": ON,
                    "label": "voice.settings.activation",
                    "description": "prefs.voice.activation.desc",
                    "keywords": "push to talk hold toggle hands free activation"
                }
            ]
        },
        {
            "id": "recognition",
            "title": "prefs.voice.section.recognition",
            "entries": [
                {
                    "key": "voice.model",
                    "type": "selector",
                    "options": VoiceModel.MODELS.map(function (m) {
                        return {
                            "value": m,
                            "label": MODEL_LABELS[m] || m
                        };
                    }),
                    "enabledWhen": ON,
                    "label": "voice.settings.model",
                    "description": "prefs.voice.model.desc",
                    "keywords": "whisper model large turbo quantization q5 q8 accuracy"
                },
                {
                    "key": "voice.language",
                    "type": "selector",
                    "options": VoiceModel.LANGUAGES.map(function (l) {
                        return {
                            "value": l,
                            "label": LANGUAGE_LABELS[l] || l
                        };
                    }),
                    "enabledWhen": ON,
                    "label": "voice.settings.language",
                    "description": "prefs.voice.language.desc",
                    "keywords": "speech recognition language auto detect english russian japanese"
                },
                toggle("voice.useGpu", "voice.settings.use_gpu", "gpu cuda vulkan rocm acceleration", "prefs.voice.use_gpu.desc"),
                toggle("voice.vadAutoStop", "voice.settings.vad_auto_stop", "vad silence pause auto stop", "prefs.voice.vad_auto_stop.desc"),
                {
                    "key": "voice.vadSilenceMs",
                    "type": "slider",
                    "min": 300,
                    "max": 5000,
                    "step": 100,
                    "unit": "ms",
                    "enabledWhen": {
                        "all": [ON,
                            {
                                "key": "voice.vadAutoStop",
                                "equals": true
                            }
                        ]
                    },
                    "label": "voice.settings.vad_silence",
                    "description": "prefs.voice.vad_silence.desc",
                    "keywords": "vad silence pause stop delay"
                },
                {
                    "key": "voice.vadSensitivity",
                    "type": "selector",
                    "options": [
                        {
                            "value": 0.2,
                            "label": "voice.settings.low"
                        },
                        {
                            "value": 0.5,
                            "label": "voice.settings.medium"
                        },
                        {
                            "value": 0.8,
                            "label": "voice.settings.high"
                        }
                    ],
                    "enabledWhen": ON,
                    "label": "voice.settings.vad_sensitivity",
                    "description": "prefs.voice.vad_sensitivity.desc",
                    "keywords": "vad sensitivity speech detection noise"
                },
                toggle("voice.serverVad", "voice.settings.server_vad", "vad trim silence server", "prefs.voice.server_vad.desc")
            ]
        },
        {
            "id": "limits",
            "title": "prefs.voice.section.limits",
            "collapsible": true,
            "entries": [
                seconds("voice.maxSeconds", "voice.settings.max_seconds", 5, 600, 5, "maximum recording length duration", "prefs.voice.max_seconds.desc"),
                seconds("voice.noSpeechTimeout", "voice.settings.no_speech_timeout", 0, 60, 1, "no speech silence give up timeout", "prefs.voice.no_speech.desc", [
                    {
                        "value": 0,
                        "label": "prefs.common.never"
                    }
                ]),
                seconds("voice.idleTimeout", "voice.settings.idle_timeout", 0, 86400, 60, "unload model gpu memory vram idle", "prefs.voice.idle_timeout.desc", [
                    {
                        "value": 0,
                        "label": "prefs.common.never"
                    }
                ])
            ]
        },
        {
            "id": "dictation",
            "title": "prefs.voice.section.dictation",
            "entries": [
                {
                    "key": "voice.typingMethod",
                    "type": "selector",
                    "options": VoiceModel.TYPING_METHODS.map(function (m) {
                        return {
                            "value": m,
                            "label": TYPING_LABELS[m] || m
                        };
                    }),
                    "enabledWhen": ON,
                    "label": "voice.settings.typing_method",
                    "description": "prefs.voice.typing_method.desc",
                    "keywords": "dictation wtype ydotool clipboard type paste"
                },
                toggle("voice.punctuation", "voice.settings.punctuation", "dictation punctuation capital letters", "prefs.voice.punctuation.desc"),
                toggle("voice.trailingSpace", "voice.settings.trailing_space", "dictation trailing space", "prefs.voice.trailing_space.desc"),
                toggle("voice.aiAutoSend", "voice.settings.ai_auto_send", "assistant ai voice send immediately", "prefs.voice.ai_auto_send.desc"),
                {
                    "key": "voice.previewMs",
                    "type": "slider",
                    "min": 0,
                    "max": 5000,
                    "step": 100,
                    "unit": "ms",
                    "specialValues": [
                        {
                            "value": 0,
                            "label": "prefs.common.off"
                        }
                    ],
                    "enabledWhen": ON,
                    "label": "voice.settings.preview",
                    "description": "prefs.voice.preview.desc",
                    "keywords": "transcript preview show duration"
                }
            ]
        }
    ]
};
