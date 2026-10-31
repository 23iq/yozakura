package compositor

import (
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
