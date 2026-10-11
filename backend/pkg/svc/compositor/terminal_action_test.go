package compositor

import (
	"os/exec"
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
)

func TestTerminalRunCommandQuoting(t *testing.T) {
	p := brand.Command("terminal", "run")
	cases := []struct {
		name, cmd, cwd, keep, want string
	}{
		{"plain", "htop", "", "", p + " -- 'htop'"},
		{"spaces and &&", "cd ~/x && claude", "", "true", p + " -- 'cd ~/x && claude'"},
		{"cwd", "claude", "~/src/my app", "", p + " --cwd '~/src/my app' -- 'claude'"},
		{"keepOpen off", "ls", "", "false", p + " --keep-open=false -- 'ls'"},
		{"keepOpen 0", "ls", "", "0", p + " --keep-open=false -- 'ls'"},
		{"single quote", "echo 'a'", "", "", p + ` -- 'echo '\''a'\'''`},
		{"empty", "  ", "/x", "", ""},
	}
	for _, c := range cases {
		if got := TerminalRunCommand(c.cmd, c.cwd, c.keep); got != c.want {
			t.Errorf("%s: %q, want %q", c.name, got, c.want)
		}
	}
}

// The rendered line, run by a real sh, hands the command over as one
// argument: nothing is expanded or split on the way.
func TestTerminalRunLineSurvivesSh(t *testing.T) {
	hostile := `a; touch /nonexistent/x $(id) ` + "`id` 'q' \"d\" \\ *"
	cwd := "/tmp/it's here"
	line := TerminalRunCommand(hostile, cwd, "false")
	rest := strings.TrimPrefix(line, brand.AppID+" ")
	out, err := exec.Command("sh", "-c", `for a in `+rest+`; do printf '<%s>' "$a"; done`).Output()
	if err != nil {
		t.Fatal(err)
	}
	want := "<terminal><run><--cwd><" + cwd + "><--keep-open=false><--><" + hostile + ">"
	if string(out) != want {
		t.Fatalf("got %q, want %q", out, want)
	}
}

func TestTerminalRunActionResolves(t *testing.T) {
	got := ResolveAction(Action{ID: "apps.terminal-run", Args: map[string]any{"command": "claude", "keepOpen": false}})
	if got == nil || got.Dispatcher != "exec" || !strings.Contains(got.Argument, "--keep-open=false -- 'claude'") {
		t.Fatalf("%+v", got)
	}
	if got := ResolveAction(Action{ID: "apps.terminal-run", Args: map[string]any{"command": "x", "keepOpen": "true"}}); got == nil || strings.Contains(got.Argument, "keep-open") {
		t.Fatalf("keepOpen true is the default: %+v", got)
	}
}
