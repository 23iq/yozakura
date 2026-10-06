package compositor

import (
	"os"
	"path/filepath"
)

// polkitAgents are the agent binaries niri and Mango sessions can start
// directly, in preference order (hyprpolkitagent first: it matches the
// portal and theming the installer sets up).
var polkitAgents = []string{
	"/usr/lib/hyprpolkitagent/hyprpolkitagent",
	"/usr/libexec/hyprpolkitagent",
	"/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
	"/usr/libexec/polkit-gnome-authentication-agent-1",
	"/usr/lib/polkit-kde-authentication-agent-1",
	"/usr/libexec/kf6/polkit-kde-authentication-agent-1",
}

// polkitUnit is the user unit hyprpolkitagent ships; plain niri/Mango
// sessions never reach graphical-session.target on their own, so the
// startup line starts it explicitly when no binary was found.
const polkitUnit = "/usr/lib/systemd/user/hyprpolkitagent.service"

// PolkitCommand returns the command that starts a polkit agent, or "" when
// none is installed. A hyprpolkitagent user unit is the fallback.
func PolkitCommand() string { return polkitCommand("/") }

func polkitCommand(root string) string {
	for _, bin := range polkitAgents {
		if st, err := os.Stat(filepath.Join(root, bin)); err == nil && !st.IsDir() {
			return bin
		}
	}
	if _, err := os.Stat(filepath.Join(root, polkitUnit)); err == nil {
		return "systemctl --user start hyprpolkitagent"
	}
	return ""
}
