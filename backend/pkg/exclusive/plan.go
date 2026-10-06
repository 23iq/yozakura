package exclusive

import (
	"fmt"

	"yozakura/backend/pkg/yozd/ipc"
)

// Plan is what Enable would do, for a confirmation prompt. Nothing is
// changed to produce it.
type Plan struct {
	Entry       string   `json:"entry"`
	HyprDir     string   `json:"hyprDir"`
	BackupDir   string   `json:"backupDir"` // the new backup's parent, the dir name is the time
	Units       []string `json:"units"`
	Monitors    []string `json:"monitors"` // "DP-1 2560x1440@144"
	Keyboard    string   `json:"keyboard"` // "us,ru" or ""
	UserFile    string   `json:"userFile"`
	AlreadyDone bool     `json:"alreadyDone"`
}

// Preview lists the entry file, backup location, units that would be
// disabled and the monitors/keyboard that would be imported.
func Preview(o Options) (Plan, error) {
	if err := supported(o); err != nil {
		return Plan{}, err
	}
	if err := checkManaged(o.hyprDir()); err != nil {
		return Plan{}, err
	}
	hypr := o.hyprDir()
	p := Plan{HyprDir: hypr, BackupDir: o.backupRoot(), Units: []string{}, Monitors: []string{},
		AlreadyDone: activeEntry(hypr) != ""}
	p.Entry = entryName(hypr)
	p.UserFile = "user.conf"
	if p.Entry == "hyprland.lua" {
		p.UserFile = "user.lua"
	}
	if o.Systemd != nil {
		for _, u := range candidateUnits(o) {
			if o.Systemd.IsEnabled(u) {
				p.Units = append(p.Units, u)
			}
		}
	}
	mons, kb := ScanImports(hypr, o.dataDir())
	for _, m := range mons {
		p.Monitors = append(p.Monitors, monitorLabel(m))
	}
	if kb != nil {
		p.Keyboard = joinNonEmpty(kb.Layouts)
	}
	return p, nil
}

func monitorLabel(m ipc.OutputConfig) string {
	if !m.Enabled {
		return m.Name + " (off)"
	}
	if m.Width == 0 {
		return m.Name
	}
	return fmt.Sprintf("%s %dx%d@%g", m.Name, m.Width, m.Height, m.Refresh)
}

func joinNonEmpty(l []string) string {
	out := ""
	for _, s := range l {
		if s == "" {
			continue
		}
		if out != "" {
			out += ","
		}
		out += s
	}
	return out
}
