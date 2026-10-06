package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
	"yozakura/backend/pkg/yozd/ipc/hyprland"
	"yozakura/backend/pkg/yozd/ipc/mango"
	"yozakura/backend/pkg/yozd/ipc/niri"
)

// [env] reaches every compositor's syntax; values no syntax can carry
// verbatim are dropped.
func TestEnvRenderedPerCompositor(t *testing.T) {
	dir := t.TempDir()
	toml := filepath.Join(dir, "yozd.toml")
	body := "[env]\nQT_QPA_PLATFORMTHEME = \"qt6ct\"\nBAD = \"a b\"\n"
	if err := os.WriteFile(toml, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	cfg, err := LoadConfig(toml)
	if err != nil {
		t.Fatal(err)
	}
	u := cfg.ToIPCConfig()
	want := map[string]string{
		"hyprland.conf": "env = QT_QPA_PLATFORMTHEME,qt6ct\n",
		"niri.kdl":      "environment {\n    QT_QPA_PLATFORMTHEME \"qt6ct\"\n}\n",
		"mango.conf":    "env=QT_QPA_PLATFORMTHEME,qt6ct\n",
	}
	for name, gen := range map[string]ipc.ConfigGenerator{
		"niri.kdl": niri.NewGenerator(), "mango.conf": mango.NewGenerator(), "hyprland.conf": hyprland.NewGenerator(),
	} {
		if err := writeConfig(gen, filepath.Join(dir, name), u, name != "hyprland.conf"); err != nil {
			t.Fatal(err)
		}
		b, _ := os.ReadFile(filepath.Join(dir, name))
		if !strings.Contains(string(b), want[name]) || strings.Contains(string(b), "BAD") {
			t.Errorf("%s:\n%s", name, b)
		}
	}
	if got := hyprland.NewLuaGenerator().GenerateEnvLua(u.Env); got != `hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")`+"\n" {
		t.Errorf("lua: %q", got)
	}
}
