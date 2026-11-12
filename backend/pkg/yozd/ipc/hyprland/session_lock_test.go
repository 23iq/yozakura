package hyprland

import (
	"strings"
	"testing"

	"yozakura/backend/pkg/yozd/ipc"
)

// A shell restarted while the session is locked must be able to take the
// lock over (ext-session-lock): the generated config turns on
// misc:allow_session_lock_restore in both config languages, whatever the
// appearance payload holds, and exactly once.
func TestAppearanceAllowsSessionLockRestore(t *testing.T) {
	rounding := 8
	enabled := true
	payloads := []ipc.ConfigAppearance{
		{},
		{Border: &ipc.Border{Rounding: &rounding}},
		{Animations: &ipc.Animations{Enabled: &enabled}},
	}
	for i, p := range payloads {
		conf := (&Generator{}).GenerateAppearance(p)
		if n := strings.Count(conf, "allow_session_lock_restore"); n != 1 {
			t.Errorf("payload %d: hyprlang has %d allow_session_lock_restore entries:\n%s", i, n, conf)
		}
		if !strings.Contains(conf, "misc {\n    allow_session_lock_restore = true\n}\n") {
			t.Errorf("payload %d: hyprlang misc block missing:\n%s", i, conf)
		}
		lua := NewLuaGenerator().GenerateAppearanceLua(p)
		if n := strings.Count(lua, "allow_session_lock_restore"); n != 1 {
			t.Errorf("payload %d: Lua has %d allow_session_lock_restore entries:\n%s", i, n, lua)
		}
		if !strings.Contains(lua, "hl.config({\n    misc = {\n        allow_session_lock_restore = true,\n    },\n})\n") {
			t.Errorf("payload %d: Lua misc block missing:\n%s", i, lua)
		}
	}
}
