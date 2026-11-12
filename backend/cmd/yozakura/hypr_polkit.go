package main

import (
	"fmt"
	"os"
	"strings"

	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/svc/compositor"
)

// oldPolkitCommand is what install.sh's Hyprland polkit line ran before the
// shell had its own agent: it starts the external agent first on every
// login, so the shell's agent could never register.
const oldPolkitCommand = "systemctl --user start hyprpolkitagent"

// polkitEntryLine is the installer's polkit line running cmd (an sh command
// line), in the form of the entry's language, with our marker (see
// polkitSuffixes). install.sh writes the same text.
func polkitEntryLine(lua bool, cmd string) string {
	if lua {
		return fmt.Sprintf("hl.on(\"hyprland.start\", function() hl.exec_cmd(%q) end) %s", cmd, polkitSuffixes()[1])
	}
	return "exec-once = " + compositor.HyprlangValue(cmd) + " " + polkitSuffixes()[0]
}

// migratePolkitLine rewrites, in place, the installer's old polkit line in
// the Hyprland entry at path to `<bin> polkit-fallback`, which starts the
// external agent only when the shell's own agent is not in use. Only a
// line that is exactly the old one (marker included) changes; a polkit
// line the user wrote, or edited, stays. Reports whether it wrote.
func migratePolkitLine(path, bin string) (bool, error) {
	data, err := os.ReadFile(path)
	if err != nil || bin == "" {
		return false, nil
	}
	lua := strings.HasSuffix(path, ".lua")
	old := polkitEntryLine(lua, oldPolkitCommand)
	lines := strings.Split(string(data), "\n")
	n := 0
	for i, l := range lines {
		if strings.TrimRight(l, " \t\r") == old {
			eol := ""
			if strings.HasSuffix(l, "\r") {
				eol = "\r"
			}
			lines[i] = polkitEntryLine(lua, compositor.FallbackShellCommand(bin)) + eol
			n++
		}
	}
	if n == 0 {
		return false, nil
	}
	return true, fsutil.WriteFile(path, []byte(strings.Join(lines, "\n")), 0o644)
}
