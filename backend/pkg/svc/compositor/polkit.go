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
	// NixOS system profile (the module links /libexec); stable across
	// rebuilds, unlike the store paths behind it.
	"/run/current-system/sw/libexec/hyprpolkitagent",
	"/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1",
	"/run/current-system/sw/libexec/polkit-kde-authentication-agent-1",
}

// polkitUnits are where the user unit hyprpolkitagent ships can live (the
// package dir, NixOS systemd.packages); plain niri/Mango sessions never
// reach graphical-session.target on their own, so the startup line starts
// it explicitly when no binary was found.
var polkitUnits = []string{
	"/usr/lib/systemd/user/hyprpolkitagent.service",
	"/etc/systemd/user/hyprpolkitagent.service",
}

// PolkitCommand returns the command that starts a polkit agent, or "" when
// none is installed. A hyprpolkitagent user unit is the fallback.
func PolkitCommand() string { return polkitCommand("/") }

// nixosPolkitUnit is the module's hyprpolkitagent unit, wanted by
// graphical-session.target (which niri-session reaches too): starting it
// instead of the binary avoids a second agent that fails to register.
const nixosPolkitUnit = "/etc/systemd/user/hyprpolkitagent.service"

func polkitCommand(root string) string {
	if _, err := os.Stat(filepath.Join(root, nixosPolkitUnit)); err == nil {
		return "systemctl --user start hyprpolkitagent"
	}
	for _, bin := range polkitAgents {
		if st, err := os.Stat(filepath.Join(root, bin)); err == nil && !st.IsDir() {
			return bin
		}
	}
	for _, unit := range polkitUnits {
		if _, err := os.Stat(filepath.Join(root, unit)); err == nil {
			return "systemctl --user start hyprpolkitagent"
		}
	}
	return ""
}
