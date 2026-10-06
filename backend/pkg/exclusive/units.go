package exclusive

import "strings"

// otherShellUnits are bars, notification daemons, wallpaper, idle and lock
// daemons and other shells that overlap with Yozakura.
var otherShellUnits = []string{
	"waybar", "mako", "dunst", "swaync", "fnott", "hyprpaper", "swww", "swww-daemon",
	"swaybg", "hypridle", "hyprlock", "ags", "eww", "nwg-panel",
}

// candidateUnits lists the known units plus quickshell*.service units that
// are not ours.
func candidateUnits(o Options) []string {
	out := []string{}
	seen := map[string]bool{}
	add := func(u string) {
		if !seen[u] {
			seen[u] = true
			out = append(out, u)
		}
	}
	for _, n := range otherShellUnits {
		add(n + ".service")
	}
	for _, u := range o.Systemd.ListUserUnits("quickshell*") {
		if strings.HasSuffix(u, ".service") && !strings.Contains(u, o.appID()) {
			add(u)
		}
	}
	return out
}

// disableUnits disables (with --now) every enabled candidate. Units that
// do not exist or are not enabled are skipped silently; failures are
// returned as messages and the unit is not recorded.
func disableUnits(o Options) (disabled, errs []string) {
	disabled = []string{}
	if o.Systemd == nil {
		return disabled, nil
	}
	for _, u := range candidateUnits(o) {
		if !o.Systemd.IsEnabled(u) {
			continue
		}
		if err := o.Systemd.Disable(u); err != nil {
			errs = append(errs, "could not disable "+u+": "+err.Error())
			continue
		}
		disabled = append(disabled, u)
	}
	return disabled, errs
}

// enableUnits re-enables exactly the recorded units.
func enableUnits(o Options, units []string) (errs []string) {
	if o.Systemd == nil {
		return nil
	}
	for _, u := range units {
		if err := o.Systemd.Enable(u); err != nil {
			errs = append(errs, "could not re-enable "+u+": "+err.Error())
		}
	}
	return errs
}
