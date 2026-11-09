package compositor

import (
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
)

func terminalBindInput(actions ...Action) Input {
	in := sampleInput()
	in.Keybinds.Custom = []CustomBind{{
		Name: "Terminal", Enabled: true,
		Keys:    []KeySpec{{Modifiers: []string{"SUPER"}, Key: "T"}},
		Actions: actions,
	}}
	return in
}

// The stock terminal bind (catalog action or the legacy plain exec line)
// runs the configured terminal itself, so it works with the shell down.
func TestStockTerminalBindExecsTheTerminal(t *testing.T) {
	for _, a := range []Action{
		{ID: brand.Action("terminal")},
		{Dispatcher: "exec", Argument: brand.Command("run", "terminal")},
	} {
		in := terminalBindInput(a)
		in.Terminal = "foot"
		out := Render(in, false)
		if !strings.Contains(out, `argument = "foot"`) || strings.Contains(out, brand.Command("run", "terminal")) {
			t.Errorf("%+v: terminal bind not direct:\n%s", a, out)
		}
	}
}

func TestTerminalBindKeepsUserCommandsAndOldShells(t *testing.T) {
	// a user's own command stays as written
	in := terminalBindInput(Action{Dispatcher: "exec", Argument: "kitty --single-instance"})
	in.Terminal = "foot"
	if out := Render(in, false); !strings.Contains(out, `argument = "kitty --single-instance"`) {
		t.Errorf("user command rewritten:\n%s", out)
	}
	// no terminal sent (older shell): unchanged
	in = terminalBindInput(Action{ID: brand.Action("terminal")})
	if out := Render(in, false); !strings.Contains(out, brand.Command("run", "terminal")) {
		t.Errorf("bind changed without a terminal:\n%s", out)
	}
}

func TestDirectTerminalQuotes(t *testing.T) {
	r := &Resolved{Dispatcher: "exec", Argument: brand.Command("run", "terminal"), Flags: "x"}
	got := directTerminal(r, "/opt/my term/bin/wezterm")
	if got.Argument != `'/opt/my term/bin/wezterm'` || got.Flags != "x" {
		t.Fatalf("%+v", got)
	}
	if r.Argument != brand.Command("run", "terminal") {
		t.Fatal("the catalog entry was modified")
	}
	if directTerminal(nil, "foot") != nil {
		t.Fatal("nil must stay nil")
	}
}
