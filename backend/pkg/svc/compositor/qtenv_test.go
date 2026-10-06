package compositor

import (
	"errors"
	"strings"
	"testing"
)

func TestQtEnv(t *testing.T) {
	saved := qtLookPath
	t.Cleanup(func() { qtLookPath = saved })
	qtLookPath = func(b string) (string, error) {
		if b == "qt6ct" {
			return "/usr/bin/qt6ct", nil
		}
		return "", errors.New("missing")
	}
	t.Setenv("QT_QPA_PLATFORMTHEME", "")
	t.Setenv(SessionQtThemeEnv, "")
	if env := QtEnv(true); env["QT_QPA_PLATFORMTHEME"] != "qt6ct" {
		t.Fatalf("on: %v", env)
	}
	if env := QtEnv(false); env != nil {
		t.Fatalf("off: %v", env)
	}
	t.Setenv(SessionQtThemeEnv, "kde")
	t.Setenv("QT_QPA_PLATFORMTHEME", "qt6ct") // what the shell start sets for itself
	if env := QtEnv(true); env != nil {
		t.Fatalf("the user's own platform theme wins: %v", env)
	}
	t.Setenv(SessionQtThemeEnv, "")
	qtLookPath = func(string) (string, error) { return "", errors.New("missing") }
	t.Setenv("QT_QPA_PLATFORMTHEME", "")
	if env := QtEnv(true); env != nil {
		t.Fatalf("no qtct: %v", env)
	}
	out := Render(Input{Env: map[string]string{"QT_QPA_PLATFORMTHEME": "qt6ct"}}, false)
	if !strings.Contains(out, "\n[env]\nQT_QPA_PLATFORMTHEME = \"qt6ct\"\n") {
		t.Fatalf("render:\n%s", out)
	}
}
