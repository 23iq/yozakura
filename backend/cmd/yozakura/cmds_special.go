package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/specials"
)

const specialUsage = `Usage: {bin} special <command>

Special workspaces (Hyprland scratchpads): a name, icon, accent, a toggle
bind, a "send window here" bind and the apps each one opens. They are global
like the keybinds (specials.json): presets never carry or change them.

Commands:
    list [--json]                    The specials with binds and apps
    open <name>                      Open/close one (launches its apps when
                                     the shell runs; else a plain toggle)
    add <name> [--icon I] [--accent ROLE] [--toggle SUPER+S]
               [--send SUPER+ALT+S] [--preload] [--template chat|music|dev|notes]
    set <name> [--name NEW] [--icon I] [--accent ROLE] [--toggle COMBO]
               [--send COMBO] [--preload on|off]
                                     Change one (a rename keeps its windows)
    remove <name>                    Delete one
    app add <name> <desktop-id> [--match CLASS] [--command CMD]
                   [--if-running nothing|move] [--rule]
    app add <name> --match CLASS --command CMD [...]
    app remove <name> <app id or class>
    import-binds [--dry-run] [--json] [--file F]...
                                     Move hand-written special binds from the
                                     Hyprland config (<hypr>/custom/*.lua|conf)
                                     into specials.json; the source lines are
                                     commented out (a .bak is kept). Run again:
                                     nothing changes.

<name> is the id, the display name or the Hyprland name. Combos are written
"SUPER+ALT+S" (empty "" clears a bind). Accents are palette roles: %s.
`

type specialEnv struct {
	store specials.Store
	dirs  []string
	binds string
	hypr  string
	open  func(name, hyprName string) error
}

func defaultSpecialEnv() (*specialEnv, error) {
	env, err := loadConfigEnv()
	if err != nil {
		return nil, err
	}
	hypr := os.Getenv("XDG_CONFIG_HOME")
	if hypr == "" {
		home, _ := os.UserHomeDir()
		hypr = filepath.Join(home, ".config")
	}
	return &specialEnv{
		store: specials.Store{Config: env.store},
		dirs:  specials.ApplicationDirs(),
		binds: paths.New().KeybindsFile(),
		hypr:  filepath.Join(hypr, "hypr"),
		open:  openSpecial,
	}, nil
}

// openSpecial asks the running shell (which launches the apps) or, without
// it, toggles the workspace through the compositor daemon.
func openSpecial(id, hyprName string) error {
	if isAlive() {
		_, err := newClient().Call("ui.toggle", map[string]any{"command": "special:" + id})
		return err
	}
	bin, err := exec.LookPath(brand.Daemon)
	if err != nil {
		return fmt.Errorf("%s is not running and %s is not installed", brand.DisplayName, brand.Daemon)
	}
	return exec.Command(bin, "workspace", "toggle-special", hyprName).Run()
}

// runSpecial implements `yozakura special ...`.
func runSpecial(args []string, out, errOut io.Writer) int {
	if len(args) == 0 || args[0] == "help" || args[0] == "-h" || args[0] == "--help" {
		fmt.Fprintf(out, branded(specialUsage), strings.Join(specials.Accents, ", "))
		return 0
	}
	env, err := defaultSpecialEnv()
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	return env.run(args, out, errOut)
}

func (e *specialEnv) run(args []string, out, errOut io.Writer) int {
	var err error
	switch args[0] {
	case "list", "ls":
		err = e.list(args[1:], out)
	case "open", "toggle":
		err = e.openCmd(args[1:], out)
	case "add":
		err = e.add(args[1:], out)
	case "set":
		err = e.set(args[1:], out)
	case "remove", "rm", "delete":
		err = e.remove(args[1:], out)
	case "app", "apps":
		err = e.app(args[1:], out)
	case "import-binds":
		err = e.importBinds(args[1:], out)
	case "__names":
		list, _ := e.store.Load()
		for _, it := range list {
			fmt.Fprintln(out, it.Name)
		}
	default:
		err = fmt.Errorf("unknown special command %q (see `%s special help`)", args[0], brand.AppID)
	}
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	return 0
}

// specialView is one special as `list --json` and MCP show it.
type specialView struct {
	specials.Special
	Workspace string `json:"workspace"`
}

func views(list []specials.Special) []specialView {
	names := specials.HyprNames(list)
	out := make([]specialView, len(list))
	for i, it := range list {
		out[i] = specialView{Special: it, Workspace: "special:" + names[it.ID]}
	}
	return out
}

func (e *specialEnv) list(args []string, out io.Writer) error {
	list, err := e.store.Load()
	if err != nil {
		return err
	}
	if parseCLI(args, []string{"json"}, nil).has("json") {
		return writeJSON(out, views(list))
	}
	if len(list) == 0 {
		fmt.Fprintf(out, "No special workspaces (add one: %s special add <name>)\n", brand.AppID)
		return nil
	}
	for _, v := range views(list) {
		binds := []string{}
		if b := specials.FormatCombo(v.Toggle); b != "" {
			binds = append(binds, "toggle "+b)
		}
		if b := specials.FormatCombo(v.Send); b != "" {
			binds = append(binds, "send "+b)
		}
		apps := []string{}
		for _, a := range v.Apps {
			apps = append(apps, a.Name)
		}
		fmt.Fprintf(out, "%s  (%s, id %s)  %s\n", v.Name, v.Workspace, v.ID, strings.Join(binds, ", "))
		if len(apps) > 0 {
			fmt.Fprintf(out, "    apps: %s\n", strings.Join(apps, ", "))
		}
	}
	return nil
}

func (e *specialEnv) find(list []specials.Special, ref string) (int, error) {
	i, ok := specials.Find(list, ref)
	if !ok {
		names := []string{}
		for _, it := range list {
			names = append(names, it.Name)
		}
		return -1, fmt.Errorf("no special workspace %q (specials: %s)", ref, strings.Join(names, ", "))
	}
	return i, nil
}

func (e *specialEnv) openCmd(args []string, out io.Writer) error {
	if len(args) != 1 {
		return fmt.Errorf("usage: special open <name>")
	}
	list, err := e.store.Load()
	if err != nil {
		return err
	}
	i, err := e.find(list, args[0])
	if err != nil {
		return err
	}
	return e.open(list[i].ID, specials.HyprNames(list)[list[i].ID])
}

var specialFlags = []string{"name", "icon", "accent", "toggle", "send", "preload", "template"}

// applyFlags sets the item fields named by flags.
func applyFlags(it *specials.Special, a cliArgs) error {
	if v, ok := a.value("name"); ok {
		it.Name = strings.TrimSpace(v)
	}
	if v, ok := a.value("icon"); ok {
		it.Icon = v
	}
	if v, ok := a.value("accent"); ok {
		it.Accent = v
	}
	for _, f := range []struct {
		flag string
		dst  *specials.Combo
	}{{"toggle", &it.Toggle}, {"send", &it.Send}} {
		if v, ok := a.value(f.flag); ok {
			c, err := specials.ParseCombo(v)
			if err != nil {
				return err
			}
			*f.dst = c
		}
	}
	if v, ok := a.value("preload"); ok {
		switch strings.ToLower(v) {
		case "on", "true", "yes", "1":
			it.Preload = true
		case "off", "false", "no", "0":
			it.Preload = false
		default:
			return fmt.Errorf("--preload takes on or off, got %q", v)
		}
	}
	return nil
}

// templates mirrors Specials.TEMPLATES (names, icons, accents).
var templates = map[string]struct{ icon, accent, apps string }{
	"chat":  {"chatDots", "primary", "telegram"},
	"music": {"musicNotes", "tertiary", "music"},
	"dev":   {"code", "secondary", ""},
	"notes": {"notePencil", "yellow", "notes"},
}

func (e *specialEnv) add(args []string, out io.Writer) error {
	a := parseCLI(args, []string{"preload"}, specialFlags)
	if len(a.pos) != 1 {
		return fmt.Errorf("usage: special add <name> [flags]")
	}
	list, err := e.store.Load()
	if err != nil {
		return err
	}
	icon, accent := specials.IconFor(a.pos[0]), "primary"
	var apps []specials.App
	if t, ok := a.value("template"); ok {
		tpl, known := templates[t]
		if !known {
			return fmt.Errorf("unknown template %q (chat, music, dev, notes)", t)
		}
		icon, accent = tpl.icon, tpl.accent
		if tpl.apps != "" {
			apps = specials.SuggestApps(e.dirs, tpl.apps)
		}
	}
	list, it, err := specials.Add(list, a.pos[0], icon, accent)
	if err != nil {
		return err
	}
	idx := len(list) - 1
	if apps == nil {
		apps = specials.SuggestApps(e.dirs, a.pos[0])
	}
	list[idx].Apps = apps
	if err := applyFlags(&list[idx], a); err != nil {
		return err
	}
	if a.has("preload") {
		list[idx].Preload = true
	}
	if err := e.store.Save(list); err != nil {
		return err
	}
	fmt.Fprintf(out, "Added %s (special:%s)\n", it.Name, specials.HyprNames(list)[it.ID])
	return e.warnConflicts(list[idx:idx+1], out)
}

func (e *specialEnv) set(args []string, out io.Writer) error {
	a := parseCLI(args, nil, specialFlags)
	if len(a.pos) != 1 {
		return fmt.Errorf("usage: special set <name> [flags]")
	}
	list, err := e.store.Load()
	if err != nil {
		return err
	}
	i, err := e.find(list, a.pos[0])
	if err != nil {
		return err
	}
	if err := applyFlags(&list[i], a); err != nil {
		return err
	}
	if err := e.store.Save(list); err != nil {
		return err
	}
	fmt.Fprintf(out, "Updated %s (special:%s)\n", list[i].Name, specials.HyprNames(list)[list[i].ID])
	return e.warnConflicts(list[i:i+1], out)
}

func (e *specialEnv) remove(args []string, out io.Writer) error {
	if len(args) != 1 {
		return fmt.Errorf("usage: special remove <name>")
	}
	list, err := e.store.Load()
	if err != nil {
		return err
	}
	i, err := e.find(list, args[0])
	if err != nil {
		return err
	}
	name := list[i].Name
	list = append(list[:i], list[i+1:]...)
	if err := e.store.Save(list); err != nil {
		return err
	}
	fmt.Fprintf(out, "Removed %s\n", name)
	return nil
}

func (e *specialEnv) app(args []string, out io.Writer) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: special app add|remove <name> <app>")
	}
	a := parseCLI(args[1:], []string{"rule"}, []string{"match", "command", "if-running"})
	list, err := e.store.Load()
	if err != nil {
		return err
	}
	if len(a.pos) < 1 {
		return fmt.Errorf("usage: special app %s <name> <app>", args[0])
	}
	i, err := e.find(list, a.pos[0])
	if err != nil {
		return err
	}
	switch args[0] {
	case "add":
		var app specials.App
		if len(a.pos) > 1 {
			entry, ok := specials.Lookup(e.dirs, a.pos[1])
			if !ok {
				return fmt.Errorf("no installed app %q (a desktop id, e.g. org.telegram.desktop); or give --match and --command", a.pos[1])
			}
			app = entry.App()
		}
		if v, ok := a.value("match"); ok {
			app.Match = v
		}
		if v, ok := a.value("command"); ok {
			app.Command = v
		}
		if v, ok := a.value("if-running"); ok {
			app.IfRunning = v
		}
		app.Rule = a.has("rule")
		if app.Match == "" {
			return fmt.Errorf("an app needs a desktop id or --match CLASS")
		}
		for _, x := range list[i].Apps {
			if x.Match == app.Match && x.ID == app.ID {
				return fmt.Errorf("%s already has %s", list[i].Name, app.Match)
			}
		}
		list[i].Apps = append(list[i].Apps, app)
		list[i] = specials.Normalize(list[i])
		app = list[i].Apps[len(list[i].Apps)-1]
		if err := e.store.Save(list); err != nil {
			return err
		}
		fmt.Fprintf(out, "%s: added %s (class %s)\n", list[i].Name, app.Name, app.Match)
	case "remove", "rm":
		if len(a.pos) != 2 {
			return fmt.Errorf("usage: special app remove <name> <app id or class>")
		}
		kept := list[i].Apps[:0]
		removed := false
		for _, x := range list[i].Apps {
			if !removed && (x.ID == a.pos[1] || strings.EqualFold(x.Match, a.pos[1])) {
				removed = true
				continue
			}
			kept = append(kept, x)
		}
		if !removed {
			return fmt.Errorf("%s has no app %q", list[i].Name, a.pos[1])
		}
		list[i].Apps = kept
		if err := e.store.Save(list); err != nil {
			return err
		}
		fmt.Fprintf(out, "%s: removed %s\n", list[i].Name, a.pos[1])
	default:
		return fmt.Errorf("unknown app command %q (add, remove)", args[0])
	}
	return nil
}

// importReport is `import-binds --json`.
type importReport struct {
	Files []string `json:"files"`
	Found []string `json:"found"`
	specials.MergeReport
	Backups   []string `json:"backups"`
	Conflicts []string `json:"conflicts"`
	Warnings  []string `json:"warnings"`
	DryRun    bool     `json:"dryRun"`
}

func (e *specialEnv) importBinds(args []string, out io.Writer) error {
	a := parseCLI(args, []string{"dry-run", "json"}, []string{"file"})
	files := specials.DefaultFiles(e.hypr)
	if f, ok := a.value("file"); ok {
		files = append([]string{f}, a.pos...)
	} else if len(a.pos) > 0 {
		files = a.pos
	}
	found, warnings, err := specials.ScanBinds(files)
	if err != nil {
		return err
	}
	list, err := e.store.Load()
	if err != nil {
		return err
	}
	merged, report := specials.Merge(list, found, e.dirs)
	rep := importReport{Files: files, MergeReport: report, DryRun: a.has("dry-run"), Warnings: append(warnings, report.Warnings...)}
	for _, f := range found {
		rep.Found = append(rep.Found, f.Name)
	}
	if rep.Conflicts, err = specials.Conflicts(e.binds, merged); err != nil {
		rep.Warnings = append(rep.Warnings, err.Error())
	}
	if !rep.DryRun && len(found) > 0 {
		// Config first: if it cannot be written, the binds keep working.
		if err := e.store.Save(merged); err != nil {
			return err
		}
		if rep.Backups, err = specials.CommentOut(found); err != nil {
			return err
		}
	}
	if a.has("json") {
		return writeJSON(out, rep)
	}
	verb := "Imported"
	if rep.DryRun {
		verb = "Would import"
	}
	if len(found) == 0 {
		fmt.Fprintln(out, "No special workspace binds found in:", strings.Join(files, ", "))
	}
	for _, n := range rep.Added {
		fmt.Fprintf(out, "%s %s\n", verb, n)
	}
	for _, n := range rep.Updated {
		fmt.Fprintf(out, "Filled the binds of %s\n", n)
	}
	for _, n := range rep.Kept {
		fmt.Fprintf(out, "%s already exists (kept)\n", n)
	}
	for _, b := range rep.Backups {
		fmt.Fprintf(out, "Backup: %s\n", b)
	}
	for _, c := range rep.Conflicts {
		fmt.Fprintf(out, "Conflict: %s\n", c)
	}
	for _, w := range rep.Warnings {
		fmt.Fprintf(out, "Warning: %s\n", w)
	}
	return nil
}

func (e *specialEnv) warnConflicts(list []specials.Special, out io.Writer) error {
	conflicts, err := specials.Conflicts(e.binds, list)
	if err != nil {
		return nil
	}
	for _, c := range conflicts {
		fmt.Fprintf(out, "Conflict: %s\n", c)
	}
	return nil
}
