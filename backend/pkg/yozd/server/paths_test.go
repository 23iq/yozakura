package server

import (
	"path/filepath"
	"strings"
	"testing"
	"yozakura/backend/pkg/brand"

	"yozakura/backend/pkg/yozd/ipc/hyprland"
	"yozakura/backend/pkg/yozd/ipc/mango"
	"yozakura/backend/pkg/yozd/ipc/niri"
)

func TestResolveTargetPath(t *testing.T) {
	t.Setenv("HOME", "/home/tester")

	cases := []struct {
		name      string
		target    string
		configDir string
		want      string
	}{
		{"empty", "", "/etc/daemon", ""},
		{"tilde alone", "~", "/etc/daemon", "/home/tester"},
		{"tilde slash", "~/share/daemon", "/etc/daemon", "/home/tester/share/daemon"},
		{"absolute", "/var/lib/daemon/out", "/etc/daemon", "/var/lib/daemon/out"},
		{"relative", "hyprland.lua", "/etc/daemon", "/etc/daemon/hyprland.lua"},
		{"relative nested", "sub/dir/file.conf", "/etc/daemon", "/etc/daemon/sub/dir/file.conf"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := ResolveTargetPath(c.target, c.configDir)
			if got != c.want {
				t.Fatalf("got %q, want %q", got, c.want)
			}
		})
	}
}

func TestPathsForCompositorWithTargetDefaults(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", "/cfg")
	dir := xdgConfigDir()

	hypr := &hyprland.Hyprland{}
	n := &niri.Niri{}
	m := &mango.Mango{}

	if got := PathsForCompositorWithTarget(hypr, "", "", "", "/anywhere"); !strings.HasSuffix(got.Primary(), "hypr/"+brand.Daemon+".generated.conf") {
		t.Fatalf("hypr default primary = %q", got.Primary())
	} else if got.Primary() != filepath.Join(dir, "hypr", brand.Daemon+".generated.conf") {
		t.Fatalf("hypr default primary full = %q", got.Primary())
	}
	if got := PathsForCompositorWithTarget(n, "", "", "", "/anywhere"); !strings.HasSuffix(got.Primary(), "niri/"+brand.Daemon+".generated.kdl") {
		t.Fatalf("niri default primary = %q", got.Primary())
	}
	if got := PathsForCompositorWithTarget(m, "", "", "", "/anywhere"); !strings.HasSuffix(got.Primary(), "mango/"+brand.Daemon+".generated.conf") {
		t.Fatalf("mango default primary = %q", got.Primary())
	}
}

func TestPathsForCompositorWithTargetHyprlandLua(t *testing.T) {
	t.Setenv("HOME", "/home/tester")
	hypr := &hyprland.Hyprland{}

	got := PathsForCompositorWithTarget(hypr, "~/.local/share/yozakura/hyprland.lua", "", "", "/anywhere")
	if got.Alt() != "/home/tester/.local/share/yozakura/hyprland.lua" {
		t.Fatalf("lua alt = %q", got.Alt())
	}
	if got.Primary() != "/home/tester/.local/share/yozakura/hyprland.conf" {
		t.Fatalf("conf primary = %q", got.Primary())
	}
}

func TestPathsForCompositorWithTargetHyprlandConf(t *testing.T) {
	t.Setenv("HOME", "/home/tester")
	hypr := &hyprland.Hyprland{}

	got := PathsForCompositorWithTarget(hypr, "~/.local/share/yozakura/hyprland.conf", "", "", "/anywhere")
	if got.Primary() != "/home/tester/.local/share/yozakura/hyprland.conf" {
		t.Fatalf("conf primary = %q", got.Primary())
	}
	if got.Alt() != "/home/tester/.local/share/yozakura/hyprland.lua" {
		t.Fatalf("lua alt = %q", got.Alt())
	}
}

func TestPathsForCompositorWithTargetHyprlandNoExt(t *testing.T) {
	t.Setenv("HOME", "/home/tester")
	hypr := &hyprland.Hyprland{}

	got := PathsForCompositorWithTarget(hypr, "~/.local/share/yozakura/hyprland", "", "", "/anywhere")
	if got.Primary() != "/home/tester/.local/share/yozakura/hyprland.conf" {
		t.Fatalf("conf primary = %q", got.Primary())
	}
	if got.Alt() != "/home/tester/.local/share/yozakura/hyprland.lua" {
		t.Fatalf("lua alt = %q", got.Alt())
	}
}

func TestPathsForCompositorWithTargetRelative(t *testing.T) {
	t.Setenv("HOME", "/home/tester")
	hypr := &hyprland.Hyprland{}

	got := PathsForCompositorWithTarget(hypr, "./hyprland.lua", "", "", "/etc/daemon")
	if got.Alt() != "/etc/daemon/hyprland.lua" {
		t.Fatalf("relative lua = %q", got.Alt())
	}
	if got.Primary() != "/etc/daemon/hyprland.conf" {
		t.Fatalf("relative conf = %q", got.Primary())
	}
}

func TestPathsForCompositorWithTargetNiri(t *testing.T) {
	t.Setenv("HOME", "/home/tester")
	n := &niri.Niri{}

	got := PathsForCompositorWithTarget(n, "", "~/.local/share/yozakura/niri.kdl", "", "/anywhere")
	if got.Primary() != "/home/tester/.local/share/yozakura/niri.kdl" {
		t.Fatalf("niri primary = %q", got.Primary())
	}
	if got.Alt() != "" {
		t.Fatalf("niri alt = %q, want empty", got.Alt())
	}
}

func TestPathsForCompositorWithTargetMango(t *testing.T) {
	t.Setenv("HOME", "/home/tester")
	m := &mango.Mango{}

	got := PathsForCompositorWithTarget(m, "", "", "~/.local/share/yozakura/mango.conf", "/anywhere")
	if got.Primary() != "/home/tester/.local/share/yozakura/mango.conf" {
		t.Fatalf("mango primary = %q", got.Primary())
	}
}

func TestPathsForCompositorWithTargetWrongFieldIgnored(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", "/cfg")
	t.Setenv("HOME", "/home/tester")
	hypr := &hyprland.Hyprland{}

	got := PathsForCompositorWithTarget(hypr, "", "~/.local/share/yozakura/niri.kdl", "", "/anywhere")
	if !strings.HasSuffix(got.Primary(), "hypr/"+brand.Daemon+".generated.conf") {
		t.Fatalf("niri target on hypr should be ignored, got %q", got.Primary())
	}
}
