package compositor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func touch(t *testing.T, root, rel string) {
	t.Helper()
	p := filepath.Join(root, rel)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, nil, 0o755); err != nil {
		t.Fatal(err)
	}
}

func TestPolkitCommandPrefersBinaryThenUnit(t *testing.T) {
	root := t.TempDir()
	if got := polkitCommand(root); got != "" {
		t.Fatalf("empty root: %q", got)
	}
	touch(t, root, polkitUnits[0])
	if got := polkitCommand(root); got != "systemctl --user start hyprpolkitagent" {
		t.Fatalf("unit fallback: %q", got)
	}
	touch(t, root, "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
	if got := polkitCommand(root); !strings.HasSuffix(got, "polkit-gnome-authentication-agent-1") {
		t.Fatalf("gnome agent: %q", got)
	}
	touch(t, root, "/usr/lib/hyprpolkitagent/hyprpolkitagent")
	if got := polkitCommand(root); got != "/usr/lib/hyprpolkitagent/hyprpolkitagent" {
		t.Fatalf("hyprpolkitagent first: %q", got)
	}
}

func TestPolkitCommandFindsNixOSProfile(t *testing.T) {
	root := t.TempDir()
	touch(t, root, "/etc/systemd/user/hyprpolkitagent.service")
	if got := polkitCommand(root); got != "systemctl --user start hyprpolkitagent" {
		t.Fatalf("NixOS unit: %q", got)
	}
	// The module's unit wins over the binary: graphical-session.target
	// starts it anyway, a second agent would fail to register.
	touch(t, root, "/run/current-system/sw/libexec/hyprpolkitagent")
	if got := polkitCommand(root); got != "systemctl --user start hyprpolkitagent" {
		t.Fatalf("NixOS unit and agent: %q", got)
	}
	bare := t.TempDir()
	touch(t, bare, "/run/current-system/sw/libexec/hyprpolkitagent")
	if got := polkitCommand(bare); got != "/run/current-system/sw/libexec/hyprpolkitagent" {
		t.Fatalf("NixOS agent without unit: %q", got)
	}
}

func TestRenderStartupPolkitOnlyWhenSet(t *testing.T) {
	if strings.Contains(Render(Input{}, false), "exec-once-non-hyprland") {
		t.Fatal("polkit line without a command")
	}
	out := Render(Input{PolkitCmd: "/usr/lib/hyprpolkitagent/hyprpolkitagent"}, false)
	want := "[startup]\nexec-once = \"yozakura\"\nexec-once-non-hyprland = \"/usr/lib/hyprpolkitagent/hyprpolkitagent\"\n"
	if !strings.Contains(out, want) {
		t.Fatalf("missing %q in\n%s", want, out)
	}
}

func stubShellBinary(t *testing.T, bin string) {
	t.Helper()
	old := shellBinary
	shellBinary = func() string { return bin }
	t.Cleanup(func() { shellBinary = old })
}

func TestStartupPolkitLeavesTheAgentToTheShell(t *testing.T) {
	stubShellBinary(t, "/opt/my apps/yozakura")
	find := func() string { return "/usr/lib/hyprpolkitagent/hyprpolkitagent" }
	fallback := "'/opt/my apps/yozakura' polkit-fallback"
	if got := startupPolkit(Input{ShellPolkit: true}, find); got != fallback {
		t.Fatalf("shell agent on: %q, want the fallback %q", got, fallback)
	}
	if got := startupPolkit(Input{ShellPolkit: true, PolkitCmd: "/x/agent"}, find); got != fallback {
		t.Fatalf("shell agent on drops a sent command: %q", got)
	}
	if got := startupPolkit(Input{ShellPolkit: true}, func() string { return "" }); got != "" {
		t.Fatalf("no external agent installed: %q", got)
	}
	if got := startupPolkit(Input{}, find); got != find() {
		t.Fatalf("shell agent off: %q", got)
	}
	if got := startupPolkit(Input{PolkitCmd: "/x/agent"}, find); got != "/x/agent" {
		t.Fatalf("sent command kept: %q", got)
	}
}

// The input the shell sends: shellPolkit renders the fallback line, not
// the external agent itself (it would register first and keep the shell's
// agent out), so niri and Mango still get an agent when the shell's never
// registers.
func TestShellPolkitInputRendersTheFallback(t *testing.T) {
	stubShellBinary(t, "/opt/bin/yozakura")
	var in Input
	if err := json.Unmarshal([]byte(`{"shellPolkit": true}`), &in); err != nil || !in.ShellPolkit {
		t.Fatalf("shellPolkit not decoded: %v %+v", err, in)
	}
	in.PolkitCmd = startupPolkit(in, func() string { return "/usr/lib/hyprpolkitagent/hyprpolkitagent" })
	out := Render(in, false)
	if want := "exec-once-non-hyprland = \"/opt/bin/yozakura polkit-fallback\"\n"; !strings.Contains(out, want) {
		t.Fatalf("missing %q in\n%s", want, out)
	}
	if strings.Contains(out, "hyprpolkitagent") {
		t.Fatalf("external agent started next to the shell's:\n%s", out)
	}
}

func TestShellAgentEnabledReadsSystemConfig(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "system.json")
	if !ShellAgentEnabled(file) {
		t.Fatal("missing file: default is on")
	}
	for body, want := range map[string]bool{
		`{"language": "en"}`:                     true,
		`{"polkitAgent": true}`:                  true,
		`{"polkitAgent": false, "disks": ["/"]}`: false,
		`not json`:                               true,
	} {
		if err := os.WriteFile(file, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
		if got := ShellAgentEnabled(file); got != want {
			t.Errorf("%s: %v, want %v", body, got, want)
		}
	}
}

func TestPolkitStateKeepsTheShellsLastReport(t *testing.T) {
	s := NewService(nil)
	get := func() PolkitReport {
		t.Helper()
		v, err := s.polkit.get(nil)
		if err != nil {
			t.Fatal(err)
		}
		return v.(PolkitReport)
	}
	if got := get(); got != (PolkitReport{}) {
		t.Fatalf("before any report: %+v", got)
	}
	if _, err := s.polkit.set(json.RawMessage(`{"state":"registered","pid":42}`)); err != nil {
		t.Fatal(err)
	}
	if got := get(); got != (PolkitReport{State: PolkitRegistered, PID: 42}) {
		t.Fatalf("after a report: %+v", got)
	}
	if got := s.PolkitReport(); got != (PolkitReport{State: PolkitRegistered, PID: 42}) {
		t.Fatalf("PolkitReport (the daemon's read): %+v", got)
	}
	for _, bad := range []string{`{"state":"maybe","pid":1}`, `not json`} {
		if _, err := s.polkit.set(json.RawMessage(bad)); err == nil {
			t.Errorf("%s accepted", bad)
		}
	}
	if got := get(); got.State != PolkitRegistered {
		t.Fatalf("a rejected report replaced the state: %+v", got)
	}
}

func TestShellWordQuotesOnlyWhatShSplits(t *testing.T) {
	for in, want := range map[string]string{
		"/opt/bin/yozakura":         "/opt/bin/yozakura",
		"/home/a b/.local/bin/yoz":  "'/home/a b/.local/bin/yoz'",
		"/home/o'neil/bin/yozakura": `'/home/o'\''neil/bin/yozakura'`,
		`/x/"q"\$HOME/yozakura`:     `'/x/"q"\$HOME/yozakura'`,
		"":                          "''",
	} {
		if got := ShellWord(in); got != want {
			t.Errorf("ShellWord(%q) = %s, want %s", in, got, want)
		}
	}
	if got := FallbackShellCommand("/a b/yozakura"); got != "'/a b/yozakura' polkit-fallback" {
		t.Errorf("fallback: %s", got)
	}
	if got := HyprlangValue("'/x#1/yozakura' polkit-fallback"); got != "'/x##1/yozakura' polkit-fallback" {
		t.Errorf("hyprlang: %s", got)
	}
}
