package compositor

import (
	"strings"
	"testing"
)

// The cheatsheet bind (system.keybinds) and any core bind the shell adds
// later are rendered: known names in order, unknown ones sorted after.
func TestRenderSystemBindsKnownThenUnknownSorted(t *testing.T) {
	in := sampleInput()
	in.Keybinds.System = map[string]Keybind{
		"zeta":     {Modifiers: []string{"SUPER"}, Key: "F12", Action: Action{ID: "yozakura.tools"}},
		"keybinds": {Modifiers: []string{"SUPER"}, Key: "SLASH", Action: Action{ID: "yozakura.keybinds"}},
		"alpha":    {Modifiers: []string{"SUPER"}, Key: "F11", Action: Action{ID: "yozakura.tools"}},
		"overview": {Modifiers: []string{"SUPER"}, Key: "TAB", Action: Action{ID: "yozakura.overview"}},
	}
	out := Render(in, false)
	want := "modifiers = [\"SUPER\"]\nkey = \"SLASH\"\ndispatcher = \"exec\"\nargument = \"yozakura run keybinds\""
	if !strings.Contains(out, want) {
		t.Fatalf("cheatsheet bind missing in:\n%s", out)
	}
	order := []string{`key = "TAB"`, `key = "SLASH"`, `key = "F11"`, `key = "F12"`}
	last := -1
	for _, k := range order {
		i := strings.Index(out, k)
		if i <= last {
			t.Fatalf("%s out of order (at %d, previous %d)", k, i, last)
		}
		last = i
	}
}

// Every app action of the shell's catalog resolves (a missing entry drops
// the bind from the TOML silently).
func TestAppActionsResolve(t *testing.T) {
	for _, name := range []string{"ai-quickask", "ai-selection", "ai-region", "ai-agent", "ai-shell", "ai-code", "dnd-toggle", "keybinds", "desktop-edit", "terminal"} {
		r := ResolveAction(Action{ID: "yozakura." + name})
		if r == nil || r.Argument != "yozakura run "+name {
			t.Errorf("%s: got %+v", name, r)
		}
	}
}
