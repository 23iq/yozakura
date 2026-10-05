package voice

import (
	"encoding/json"
	"os"
	"strings"
)

// Modes accepted in Config.Mode.
const (
	ModePushToTalk = "push-to-talk"
	ModeToggle     = "toggle"
)

// Config mirrors config/defaults/voice.js (~/.config/yozakura/config/voice.json).
// The file is re-read at the start of every session so settings apply
// without restarting the daemon. Unknown or invalid values fall back to the
// defaults below; keep both in sync.
type Config struct {
	Enabled         bool    `json:"enabled"`
	Model           string  `json:"model"`
	Language        string  `json:"language"`
	Mode            string  `json:"activation"`
	UseGPU          bool    `json:"useGpu"`
	MaxSeconds      int     `json:"maxSeconds"`
	IdleTimeout     int     `json:"idleTimeout"`
	VadAutoStop     bool    `json:"vadAutoStop"`
	VadSilenceMs    int     `json:"vadSilenceMs"`
	VadSensitivity  float64 `json:"vadSensitivity"`
	NoSpeechTimeout int     `json:"noSpeechTimeout"`
	ServerVad       bool    `json:"serverVad"`
	TypingMethod    string  `json:"typingMethod"`
	Punctuation     bool    `json:"punctuation"`
	TrailingSpace   bool    `json:"trailingSpace"`
	AiAutoSend      bool    `json:"aiAutoSend"`
	PreviewMs       int     `json:"previewMs"`
}

// DefaultConfig returns the built-in defaults (see config/defaults/voice.js).
func DefaultConfig() Config {
	return Config{
		Enabled:         true,
		Model:           "large-v3-turbo-q5_0",
		Language:        "auto",
		Mode:            ModePushToTalk,
		UseGPU:          true,
		MaxSeconds:      60,
		IdleTimeout:     300,
		VadAutoStop:     true,
		VadSilenceMs:    1200,
		VadSensitivity:  0.5,
		NoSpeechTimeout: 8,
		ServerVad:       true,
		TypingMethod:    "auto",
		Punctuation:     true,
		TrailingSpace:   true,
		AiAutoSend:      false,
		PreviewMs:       500,
	}
}

// LoadConfig reads path over the defaults. A missing or malformed file
// yields the defaults.
func LoadConfig(path string) Config {
	cfg := DefaultConfig()
	data, err := os.ReadFile(path)
	if err == nil {
		_ = json.Unmarshal(data, &cfg)
	}
	return cfg.normalized()
}

func (c Config) normalized() Config {
	d := DefaultConfig()
	if strings.TrimSpace(c.Model) == "" {
		c.Model = d.Model
	}
	c.Language = strings.ToLower(strings.TrimSpace(c.Language))
	if c.Language == "" {
		c.Language = "auto"
	}
	if c.Mode != ModePushToTalk && c.Mode != ModeToggle {
		c.Mode = d.Mode
	}
	c.MaxSeconds = clampInt(c.MaxSeconds, 5, 600, d.MaxSeconds)
	c.IdleTimeout = clampInt(c.IdleTimeout, 0, 86400, d.IdleTimeout)
	c.VadSilenceMs = clampInt(c.VadSilenceMs, 300, 5000, d.VadSilenceMs)
	c.NoSpeechTimeout = clampInt(c.NoSpeechTimeout, 0, 60, d.NoSpeechTimeout)
	c.PreviewMs = clampInt(c.PreviewMs, 0, 5000, d.PreviewMs)
	if c.VadSensitivity < 0 || c.VadSensitivity > 1 {
		c.VadSensitivity = d.VadSensitivity
	}
	switch c.TypingMethod {
	case "auto", "wtype", "ydotool", "clipboard":
	default:
		c.TypingMethod = d.TypingMethod
	}
	return c
}

func clampInt(v, lo, hi, def int) int {
	if v < lo || v > hi {
		return def
	}
	return v
}
