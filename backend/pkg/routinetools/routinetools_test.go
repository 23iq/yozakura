package routinetools

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// The editor translates titles, descriptions and summaries by tool id
// (routines.tool.<id>[.desc|.summary]): every tool needs all three in every
// language, and the English summary must be the template of this package.
func TestTranslationsCoverEveryTool(t *testing.T) {
	for _, lang := range []string{"en", "es", "ru"} {
		raw, err := os.ReadFile(filepath.Join("..", "..", "..", "translations", lang+".json"))
		if err != nil {
			t.Fatal(err)
		}
		var tr map[string]string
		if err := json.Unmarshal(raw, &tr); err != nil {
			t.Fatal(err)
		}
		for name, m := range Tools {
			for _, suffix := range []string{"", ".desc", ".summary"} {
				if tr["routines.tool."+name+suffix] == "" {
					t.Errorf("%s.json: routines.tool.%s%s missing", lang, name, suffix)
				}
			}
			if lang == "en" && tr["routines.tool."+name+".summary"] != m.Summary {
				t.Errorf("en.json summary of %s differs from routinetools: %q vs %q", name, tr["routines.tool."+name+".summary"], m.Summary)
			}
		}
		for _, c := range Categories {
			if tr["routines.category."+c] == "" {
				t.Errorf("%s.json: category %s missing", lang, c)
			}
		}
	}
}

func TestLabelReadsLikeASentence(t *testing.T) {
	cases := []struct {
		tool string
		args map[string]any
		want string
	}{
		{"dnd_set", map[string]any{"enabled": true}, "Turn on Do Not Disturb"},
		{"dnd_set", map[string]any{"enabled": false}, "Turn off Do Not Disturb"},
		{"dnd_set", nil, "Toggle Do Not Disturb"},
		{"volume_set", map[string]any{"percent": 40}, "Set volume to 40%"},
		{"volume_set", map[string]any{"percent": 40.0, "mute": false}, "Set volume to 40%, unmute"},
		{"volume_set", map[string]any{"mute": "toggle"}, "Toggle mute"},
		{"workspace_switch", map[string]any{"workspace": 3.0}, "Switch to workspace 3"},
		{"media_control", map[string]any{"action": "next"}, "Skip to the next track"},
		{"app_launch", map[string]any{"app": "firefox"}, "Open firefox"},
		{"app_launch", map[string]any{"app": "firefox", "workspace": "2"}, "Open firefox on workspace 2"},
		{"app_close", map[string]any{}, "Close the window"},
		{"app_close", map[string]any{"app": "kitty"}, "Close kitty"},
		{"window_move_to_workspace", map[string]any{"workspace": 2}, "Move the window to workspace 2"},
		{"timer_start", nil, "Start a timer"},
		{"timer_start", map[string]any{"duration": "10m", "name": "tea"}, `Start a timer 10m "tea"`},
		{"focus_start", map[string]any{"minutes": 50}, "Start focus mode for 50 min"},
		{"screenshot", nil, "Take a screenshot (whole screen)"},
		{"unknown_tool", nil, "Tool unknown_tool"},
	}
	for _, c := range cases {
		if got := Label(c.tool, c.args); got != c.want {
			t.Errorf("%s %v: %q, want %q", c.tool, c.args, got, c.want)
		}
	}
}

func TestEveryToolHasAKnownCategory(t *testing.T) {
	known := map[string]bool{}
	for _, c := range Categories {
		known[c] = true
	}
	for name, m := range Tools {
		if !known[m.Category] {
			t.Errorf("%s: unknown category %q", name, m.Category)
		}
		if m.Summary == "" {
			t.Errorf("%s: no summary", name)
		}
		if _, dup := Excluded[name]; dup {
			t.Errorf("%s is both usable and excluded", name)
		}
	}
}
