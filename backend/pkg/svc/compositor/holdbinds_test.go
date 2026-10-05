package compositor

import (
	"strings"
	"testing"
)

func TestRenderVoiceHoldBindsEmitPressAndRelease(t *testing.T) {
	in := sampleInput()
	in.Keybinds.Yozakura["voiceAi"] = Keybind{Modifiers: []string{"SUPER"}, Key: "M", Action: Action{ID: "yozakura.voice-ai"}}
	in.Keybinds.Yozakura["dictation"] = Keybind{Modifiers: []string{"SUPER", "SHIFT"}, Key: "M", Action: Action{ID: "yozakura.dictation"}}
	in.Keybinds.Custom = append(in.Keybinds.Custom, CustomBind{
		Keys:    []KeySpec{{Modifiers: []string{"ALT"}, Key: "F9"}},
		Actions: []Action{{ID: "yozakura.dictation"}},
		Enabled: true,
	})
	out := Render(in, false)
	for _, want := range []string{
		"modifiers = [\"SUPER\"]\nkey = \"M\"\ndispatcher = \"exec\"\nargument = \"yozakura voice press ai\"\nflags = \"\"",
		"modifiers = [\"SUPER\"]\nkey = \"M\"\ndispatcher = \"exec\"\nargument = \"yozakura voice release\"\nflags = \"r\"",
		"modifiers = [\"SUPER\", \"SHIFT\"]\nkey = \"M\"\ndispatcher = \"exec\"\nargument = \"yozakura voice press dictation\"",
		"modifiers = [\"SUPER\", \"SHIFT\"]\nkey = \"M\"\ndispatcher = \"exec\"\nargument = \"yozakura voice release\"\nflags = \"r\"",
		"modifiers = [\"ALT\"]\nkey = \"F9\"\ndispatcher = \"exec\"\nargument = \"yozakura voice release\"\nflags = \"r\"",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in:\n%s", want, out)
		}
	}
	// Ordinary binds get no release twin.
	if strings.Count(out, "yozakura voice release") != 3 {
		t.Errorf("want exactly 3 release binds, got %d", strings.Count(out, "yozakura voice release"))
	}
}
