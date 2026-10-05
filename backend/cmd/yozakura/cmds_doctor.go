package main

import (
	"fmt"
	"io"
	"os"
	"os/user"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/deps"
	"yozakura/backend/pkg/paths"
)

// doctorItem is one line of the report.
type doctorItem struct {
	name, need, purpose, fix string
	ok                       bool
	pkgs                     []string
}

// runDoctor checks every dependency from pkg/deps plus the install itself
// (sources, daemon, session entry, Hyprland block) and prints what is
// missing with the command that installs it. Exit status 1 when something
// required is missing.
func runDoctor(args []string, out io.Writer) int {
	verbose := false
	features := map[string]bool{}
	for i := 0; i < len(args); i++ {
		switch a := args[i]; {
		case a == "-v" || a == "--verbose":
			verbose = true
		case a == "--with" && i+1 < len(args):
			i++
			for _, f := range strings.Split(args[i], ",") {
				features[strings.TrimSpace(f)] = true
			}
		case strings.HasPrefix(a, "--with="):
			for _, f := range strings.Split(strings.TrimPrefix(a, "--with="), ",") {
				features[strings.TrimSpace(f)] = true
			}
		default:
			fmt.Fprintf(os.Stderr, "Usage: %s doctor [-v] [--with voice,depth,sddm]\n", brand.AppID)
			return 2
		}
	}

	c := deps.NewChecker()
	items := doctorDeps(c, features)
	items = append(items, doctorInstall(c.Distro)...)
	return printDoctor(out, c.Distro, items, verbose)
}

func doctorDeps(c *deps.Checker, features map[string]bool) []doctorItem {
	var items []doctorItem
	for _, d := range deps.All() {
		if d.Optional() && !features[d.Need] {
			continue
		}
		it := doctorItem{name: d.ID, need: d.Need, purpose: d.Purpose, ok: c.Present(d), pkgs: d.Packages(c.Distro)}
		if d.ID == brand.Daemon && !it.ok {
			it.ok = daemonFound()
		}
		if len(it.pkgs) == 0 {
			// Built from this repository (yozd) or installed per user.
			it.fix = installerHint()
		}
		items = append(items, it)
	}
	return items
}

func doctorInstall(distro string) []doctorItem {
	src := paths.FindBaseShellSource()
	items := []doctorItem{{name: "shell sources", need: deps.Required, purpose: "the QML the UI runs", ok: src != "", fix: installerHint()}}
	if distro != "nixos" {
		sessions, _ := filepath.Glob("/usr/share/wayland-sessions/hyprland*.desktop")
		items = append(items, doctorItem{name: "Hyprland session", need: deps.Standard, purpose: "Hyprland in the login screen", ok: len(sessions) > 0, fix: "reinstall the hyprland package"})
	}
	home, _ := os.UserHomeDir()
	block := false
	for _, f := range []string{"hyprland.lua", "hyprland.conf"} {
		if data, err := os.ReadFile(filepath.Join(home, ".config/hypr", f)); err == nil && containsLine(string(data), blockMarker(map[string]string{"hyprland.lua": "--", "hyprland.conf": "#"}[f])) {
			block = true
		}
	}
	items = append(items, doctorItem{name: "Hyprland config", need: deps.Standard, purpose: brand.DisplayName + " block in ~/.config/hypr", ok: block, fix: brand.AppID + " install hyprland"})
	items = append(items, doctorItem{name: "input group", need: deps.Standard, purpose: "binds on a modifier alone (Super)", ok: inGroup("input"), fix: "sudo usermod -aG input $USER, then log in again"})
	return items
}

// daemonFound resolves yozd the way the CLI starts it (env, next to the
// binary, PATH): Nix keeps it beside the wrapped CLI, not on PATH.
func daemonFound() bool {
	p := paths.DaemonBinary()
	return filepath.IsAbs(p) && fileExists(p)
}

func installerHint() string {
	return "re-run the installer: curl -fsSL " + installerURL() + " | bash"
}

func inGroup(name string) bool {
	u, err := user.Current()
	if err != nil {
		return false
	}
	gids, _ := u.GroupIds()
	for _, gid := range gids {
		if g, err := user.LookupGroupId(gid); err == nil && g.Name == name {
			return true
		}
	}
	return false
}

func printDoctor(out io.Writer, distro string, items []doctorItem, verbose bool) int {
	color := isTerminal(out)
	paint := func(code, s string) string {
		if !color {
			return s
		}
		return "\033[" + code + "m" + s + "\033[0m"
	}
	fmt.Fprintf(out, "%s doctor (%s)\n\n", brand.DisplayName, distro)
	missingRequired, missing := 0, 0
	var pkgs, fixes []string
	for _, it := range items {
		mark := paint("32", "✔")
		switch {
		case it.ok:
			if !verbose {
				continue
			}
		case it.need == deps.Required:
			mark = paint("31", "✖")
			missingRequired++
		default:
			mark = paint("33", "!")
		}
		if !it.ok {
			missing++
			pkgs = append(pkgs, it.pkgs...)
			if it.fix != "" {
				fixes = append(fixes, it.fix)
			}
		}
		fmt.Fprintf(out, "  %s %-20s %-9s %s\n", mark, it.name, it.need, it.purpose)
	}
	if missing == 0 {
		fmt.Fprintln(out, paint("32", fmt.Sprintf("  Everything is in place (%d checks).", len(items))))
		return 0
	}
	fmt.Fprintf(out, "\n%d missing (%d required).\n", missing, missingRequired)
	if hint := deps.InstallHint(distro, pkgs); hint != "" {
		fmt.Fprintln(out, "\nInstall the packages:\n  "+strings.ReplaceAll(hint, "\n", "\n  "))
	} else if len(pkgs) > 0 {
		fmt.Fprintln(out, "\nInstall these with your package manager: "+strings.Join(pkgs, " "))
	}
	if distro == "nixos" && len(pkgs) > 0 {
		fmt.Fprintln(out, "On NixOS the flake package carries every dependency: use it instead of separate packages.")
	}
	for _, f := range uniq(fixes) {
		fmt.Fprintln(out, "  "+f)
	}
	if missingRequired > 0 {
		return 1
	}
	return 0
}

func uniq(in []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, s := range in {
		if !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	return out
}

func isTerminal(w io.Writer) bool {
	f, ok := w.(*os.File)
	if !ok {
		return false
	}
	info, err := f.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}
