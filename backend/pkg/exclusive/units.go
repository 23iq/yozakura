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

// unitRecord is one unit exclusive mode disables. Every enabled
// candidate is recorded before any Disable call, so a crash never loses the
// record; re-enabling a unit whose Disable never ran is harmless (it was
// enabled). WasActive says whether to start it again.
type unitRecord struct {
	Name      string `json:"name"`
	WasActive bool   `json:"wasActive"`
	Disabled  bool   `json:"disabled"`
}

// disableUnits disables (with --now) every enabled candidate, persisting
// the manifest before the first Disable and after each success. Units that
// do not exist or are not enabled are skipped silently; a failed Disable is
// returned as a message (the unit stays enabled). The error is a manifest
// write failure, which aborts Enable.
func disableUnits(o Options, dir string, m *manifest) (msgs []string, err error) {
	if o.Systemd == nil {
		return nil, nil
	}
	for _, u := range candidateUnits(o) {
		if o.Systemd.IsEnabled(u) {
			m.Units = append(m.Units, unitRecord{Name: u, WasActive: o.Systemd.IsActive(u)})
		}
	}
	if err := writeManifest(dir, *m); err != nil {
		return nil, err
	}
	for i := range m.Units {
		u := &m.Units[i]
		if err := o.Systemd.Disable(u.Name); err != nil {
			msgs = append(msgs, "could not disable "+u.Name+": "+err.Error())
			continue
		}
		u.Disabled = true
		m.DisabledUnits = append(m.DisabledUnits, u.Name)
		if err := writeManifest(dir, *m); err != nil {
			return msgs, err
		}
	}
	return msgs, nil
}

// enableUnits re-enables every recorded unit, starting the ones that were
// running.
func enableUnits(o Options, units []unitRecord) (errs []string) {
	if o.Systemd == nil {
		return nil
	}
	for _, u := range units {
		if err := o.Systemd.Enable(u.Name, u.WasActive); err != nil {
			errs = append(errs, "could not re-enable "+u.Name+": "+err.Error())
		}
	}
	return errs
}
