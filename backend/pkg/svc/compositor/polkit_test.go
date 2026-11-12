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

func TestStartupPolkitLeavesTheAgentToTheShell(t *testing.T) {
	find := func() string { return "/usr/lib/hyprpolkitagent/hyprpolkitagent" }
	if got := startupPolkit(Input{ShellPolkit: true}, find); got != "" {
		t.Fatalf("shell agent on: %q", got)
	}
	if got := startupPolkit(Input{ShellPolkit: true, PolkitCmd: "/x/agent"}, find); got != "" {
		t.Fatalf("shell agent on drops a sent command: %q", got)
	}
	if got := startupPolkit(Input{}, find); got != find() {
		t.Fatalf("shell agent off: %q", got)
	}
	if got := startupPolkit(Input{PolkitCmd: "/x/agent"}, find); got != "/x/agent" {
		t.Fatalf("sent command kept: %q", got)
	}
}

// The input the shell sends: shellPolkit renders no external agent.
func TestShellPolkitInputRendersNoAgent(t *testing.T) {
	var in Input
	if err := json.Unmarshal([]byte(`{"shellPolkit": true}`), &in); err != nil || !in.ShellPolkit {
		t.Fatalf("shellPolkit not decoded: %v %+v", err, in)
	}
	in.PolkitCmd = startupPolkit(in, func() string { return "/usr/lib/hyprpolkitagent/hyprpolkitagent" })
	if out := Render(in, false); strings.Contains(out, "exec-once-non-hyprland") {
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

func TestPolkitModuleNeedsTheQmldir(t *testing.T) {
	a, b := t.TempDir(), t.TempDir()
	if polkitModule([]string{"", a, b}) {
		t.Fatal("no module reported")
	}
	if err := os.MkdirAll(filepath.Join(a, polkitModuleDir), 0o755); err != nil {
		t.Fatal(err)
	}
	if polkitModule([]string{a}) {
		t.Fatal("a directory without qmldir is not the module")
	}
	touch(t, b, filepath.Join(polkitModuleDir, "qmldir"))
	if !polkitModule([]string{a, b}) {
		t.Fatal("module in the second dir not found")
	}
}

func TestPrefixQMLDirsCoverPackagesAndSourceBuilds(t *testing.T) {
	got := strings.Join(prefixQMLDirs("/usr/local"), " ")
	for _, want := range []string{"/usr/local/lib/qt6/qml", "/usr/local/lib/qt-6/qml", "/usr/local/lib64/qt-6/qml"} {
		if !strings.Contains(got, want) {
			t.Errorf("%s missing from %s", want, got)
		}
	}
}
