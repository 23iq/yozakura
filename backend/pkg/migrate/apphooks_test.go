package migrate

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"yozakura/backend/pkg/apphooks"
	"yozakura/backend/pkg/paths"
)

func hookEnv(t *testing.T) (paths.Paths, apphooks.Env) {
	home := t.TempDir()
	cfg := filepath.Join(home, ".config")
	p := paths.Paths{ConfigDir: filepath.Join(cfg, "yozakura"), DataDir: filepath.Join(home, ".local/share/yozakura")}
	env := apphooks.Env{Home: home, ConfigHome: cfg, CacheDir: filepath.Join(home, ".cache/yozakura"), DataDir: p.DataDir, AppID: "yozakura"}
	return p, env
}

func put(t *testing.T, path, text string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
}

// An existing install upgraded to hooks: apps whose config exists are
// switched off (never edited behind the user's back), once.
func TestAppHooksConsentLegacyInstall(t *testing.T) {
	p, env := hookEnv(t)
	put(t, p.Config("general"), `{"onboardingDone": true}`)
	put(t, p.Config("apps"), `{"kitty": {"fontSize": 12}, "theming": {"gtk": false}}`)
	kitty := filepath.Join(env.ConfigHome, "kitty", "kitty.conf")
	put(t, kitty, "font_size 11\n")
	qt := filepath.Join(env.ConfigHome, "environment.d", "90-yozakura-qt.conf")
	put(t, qt, "# Written by yozakura (Settings > Terminal & Apps). Removed when theming is switched off.\nQT_QPA_PLATFORMTHEME=qt6ct\n")

	off, err := EnsureAppHooksConsent(p, env)
	if err != nil {
		t.Fatal(err)
	}
	if len(off) != 1 || off[0] != "kitty" {
		t.Fatalf("off = %v", off)
	}
	data, _ := os.ReadFile(p.Config("apps"))
	var apps map[string]map[string]any
	if err := json.Unmarshal(data, &apps); err != nil {
		t.Fatal(err)
	}
	if apps["theming"]["kitty"] != false || apps["theming"]["gtk"] != false || apps["kitty"]["fontSize"] != float64(12) {
		t.Fatalf("apps.json = %s", data)
	}
	if b, _ := os.ReadFile(kitty); string(b) != "font_size 11\n" {
		t.Fatal("kitty.conf was edited")
	}
	if _, err := os.Stat(qt); !os.IsNotExist(err) {
		t.Fatal("the legacy Qt environment.d file stays")
	}
	// once: the user switching kitty back on is never undone
	put(t, p.Config("apps"), `{"theming": {"kitty": true}}`)
	if off, err := EnsureAppHooksConsent(p, env); err != nil || off != nil {
		t.Fatalf("second run: %v %v", off, err)
	}
}

// A fresh install (no general.json yet, or onboarding not done) keeps the
// automatic connection.
func TestAppHooksConsentFreshInstall(t *testing.T) {
	p, env := hookEnv(t)
	put(t, filepath.Join(env.ConfigHome, "kitty", "kitty.conf"), "font_size 11\n")
	if off, err := EnsureAppHooksConsent(p, env); err != nil || off != nil {
		t.Fatalf("fresh: %v %v", off, err)
	}
	if _, err := os.Stat(p.Config("apps")); !os.IsNotExist(err) {
		t.Fatal("apps.json written on a fresh install")
	}
	// later starts (onboarding done by then) do not switch anything off
	put(t, p.Config("general"), `{"onboardingDone": true}`)
	if off, _ := EnsureAppHooksConsent(p, env); off != nil {
		t.Fatalf("after the marker: %v", off)
	}
}

// A legacy Qt file that cannot be removed is reported, but the consent
// step still runs (toggles off, marker written).
func TestAppHooksConsentQtErrorNotFatal(t *testing.T) {
	p, env := hookEnv(t)
	put(t, p.Config("general"), `{"onboardingDone": true}`)
	put(t, filepath.Join(env.ConfigHome, "kitty", "kitty.conf"), "font_size 11\n")
	qtDir := filepath.Join(env.ConfigHome, "environment.d")
	put(t, filepath.Join(qtDir, "90-yozakura-qt.conf"), "# Written by yozakura (x)\nQT_QPA_PLATFORMTHEME=qt6ct\n")
	if err := os.Chmod(qtDir, 0o555); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(qtDir, 0o755) })
	if os.Getuid() == 0 {
		t.Skip("root removes anyway")
	}
	off, err := EnsureAppHooksConsent(p, env)
	if err == nil || len(off) != 1 || off[0] != "kitty" || !AppHooksConsented(p.DataDir) {
		t.Fatalf("off %v err %v consented %v", off, err, AppHooksConsented(p.DataDir))
	}
}

// A malformed apps.json: nothing written, no marker (retried next start).
func TestAppHooksConsentMalformedApps(t *testing.T) {
	p, env := hookEnv(t)
	put(t, p.Config("general"), `{"onboardingDone": true}`)
	put(t, p.Config("apps"), `{"theming": `)
	put(t, filepath.Join(env.ConfigHome, "kitty", "kitty.conf"), "font_size 11\n")
	if _, err := EnsureAppHooksConsent(p, env); err == nil {
		t.Fatal("malformed apps.json must be reported")
	}
	if AppHooksConsented(p.DataDir) {
		t.Fatal("marker written: the toggles were never switched off")
	}
	if b, _ := os.ReadFile(p.Config("apps")); string(b) != `{"theming": ` {
		t.Fatalf("apps.json changed: %s", b)
	}
}
