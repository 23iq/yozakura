package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"yozakura/backend/pkg/exclusive"
)

type cliSD struct{ enabled map[string]bool }

func (f *cliSD) IsEnabled(u string) bool       { return f.enabled[u] }
func (f *cliSD) IsActive(string) bool          { return false }
func (f *cliSD) Disable(u string) error        { f.enabled[u] = false; return nil }
func (f *cliSD) Enable(u string, _ bool) error { f.enabled[u] = true; return nil }
func (f *cliSD) ListUserUnits(string) []string { return nil }

func exclusiveTestEnv(t *testing.T, input string) (exclusiveEnv, string, *cliSD) {
	home := t.TempDir()
	hypr := filepath.Join(home, ".config/hypr")
	if err := os.MkdirAll(hypr, 0o755); err != nil {
		t.Fatal(err)
	}
	entry := filepath.Join(hypr, "hyprland.conf")
	if err := os.WriteFile(entry, []byte("monitor = DP-1,preferred,auto,1\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	sd := &cliSD{enabled: map[string]bool{"waybar.service": true}}
	return exclusiveEnv{in: strings.NewReader(input), opts: func() exclusive.Options {
		return exclusive.Options{Home: home, AppID: "yozakura", Compositor: "hyprland", Systemd: sd,
			Now: func() time.Time { return time.Date(2026, 10, 6, 1, 2, 3, 0, time.Local) }}
	}}, entry, sd
}

func TestInstallFlagsUsed(t *testing.T) {
	for args, want := range map[string]bool{"hyprland": false, "hyprland --exclusive": true, "--restore --from x": true, "niri": false} {
		if got := installFlagsUsed(strings.Fields(args)); got != want {
			t.Errorf("%q: %v", args, got)
		}
	}
}

func TestExclusiveConfirmListsAndAbortsOnNo(t *testing.T) {
	env, entry, sd := exclusiveTestEnv(t, "n\n")
	var out, errOut bytes.Buffer
	if code := runExclusiveInstall([]string{"hyprland", "--exclusive"}, env, &out, &errOut); code != 0 {
		t.Fatalf("%d %s", code, errOut.String())
	}
	for _, want := range []string{"back up", "backups/<time>", "waybar.service", "DP-1", "[y/N]", "Aborted"} {
		if !strings.Contains(out.String(), want) {
			t.Errorf("missing %q in:\n%s", want, out.String())
		}
	}
	if data, _ := os.ReadFile(entry); !strings.HasPrefix(string(data), "monitor") || !sd.enabled["waybar.service"] {
		t.Fatal("declined prompt changed something")
	}
}

func TestExclusiveYesThenRestore(t *testing.T) {
	env, entry, sd := exclusiveTestEnv(t, "")
	var out, errOut bytes.Buffer
	if code := runExclusiveInstall([]string{"hyprland", "--exclusive", "-y"}, env, &out, &errOut); code != 0 {
		t.Fatalf("%d %s", code, errOut.String())
	}
	if data, _ := os.ReadFile(entry); strings.HasPrefix(string(data), "monitor") || sd.enabled["waybar.service"] {
		t.Fatal("enable did nothing")
	}
	out.Reset()
	if code := runExclusiveInstall([]string{"--restore", "-y"}, env, &out, &errOut); code != 0 {
		t.Fatalf("%d %s", code, errOut.String())
	}
	if data, _ := os.ReadFile(entry); !strings.HasPrefix(string(data), "monitor") || !sd.enabled["waybar.service"] {
		t.Fatalf("restore: %s", out.String())
	}
	if !strings.Contains(out.String(), "replaced-") {
		t.Fatalf("restore must name the replaced files:\n%s", out.String())
	}
}

func TestExclusiveFlagErrors(t *testing.T) {
	env, _, _ := exclusiveTestEnv(t, "")
	for _, args := range [][]string{{"niri", "--exclusive"}, {"--exclusive"}, {"hyprland", "--exclusive", "--restore"}, {"hyprland", "--exclusive", "--from=x"}} {
		var out, errOut bytes.Buffer
		if code := runExclusiveInstall(args, env, &out, &errOut); code != 2 || errOut.Len() == 0 {
			t.Errorf("%v: code %d %q", args, code, errOut.String())
		}
	}
	var out, errOut bytes.Buffer
	if code := runExclusiveInstall([]string{"--restore", "-y"}, env, &out, &errOut); code != 1 || !strings.Contains(errOut.String(), "not active") {
		t.Errorf("restore while inactive: %d %q", code, errOut.String())
	}
}
