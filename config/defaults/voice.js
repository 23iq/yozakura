.pragma library

// Local voice input (whisper.cpp). Read by the Go backend at the start of
// every session (backend/pkg/svc/voice/config.go keeps the same defaults).
var data = {
    "enabled": true,
    "model": "large-v3-turbo-q5_0",
    "language": "auto",
    "activation": "push-to-talk",
    "useGpu": true,
    "maxSeconds": 60,
    "idleTimeout": 300,
    "vadAutoStop": true,
    "vadSilenceMs": 1200,
    "vadSensitivity": 0.5,
    "noSpeechTimeout": 8,
    "serverVad": true,
    "typingMethod": "auto",
    "punctuation": true,
    "trailingSpace": true,
    "aiAutoSend": false,
    "previewMs": 500
}
