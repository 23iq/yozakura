package exclusive

import (
	"strings"
	"testing"

	"yozakura/backend/pkg/brand"
)

// The minimal entry is all Hyprland loads in exclusive mode: it must start
// the polkit agent (the generated config only starts one off Hyprland),
// name a restore command that exists and load user.* from the real dir.
func TestMinimalEntry(t *testing.T) {
	for _, lua := range []bool{true, false} {
		got := minimalEntry(lua, "/b/1", "/x/hypr", "/usr/lib/polkit-kde-authentication-agent-1")
		if !strings.Contains(got, brand.Command("install", "--restore")) {
			t.Errorf("lua=%v: no working restore command:\n%s", lua, got)
		}
		if strings.Contains(got, "exclusive restore") {
			t.Errorf("lua=%v: names a command that does not exist", lua)
		}
		if !strings.Contains(got, "/x/hypr/user.") || strings.Contains(got, "~/.config/hypr") {
			t.Errorf("lua=%v: user file not from the hypr dir:\n%s", lua, got)
		}
		want := "exec-once = /usr/lib/polkit-kde-authentication-agent-1"
		if lua {
			want = `hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")`
		}
		if !strings.Contains(got, want) {
			t.Errorf("lua=%v: no polkit agent start (%s):\n%s", lua, want, got)
		}
	}
	if got := minimalEntry(false, "/b", "/x/hypr", ""); strings.Contains(got, "exec-once") {
		t.Errorf("no agent found: nothing started:\n%s", got)
	}
}
