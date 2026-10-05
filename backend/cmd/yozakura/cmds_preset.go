package main

import (
	"fmt"
	"io"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/paths"
	"yozakura/backend/pkg/presets"
)

const presetUsage = `Usage: {bin} preset <command> [args]

Presets are directories of config domain files (built in: assets/presets,
yours: ~/.config/{bin}/presets). "current" names the live config wherever a
preset name is accepted. The private domains (system, ai, prefix, weather,
notifications, apps, general, specials) and machine-local keys (secrets, commands,
endpoints, personal paths) are never part of a preset; applying one keeps them.

Commands:
    list [--json]                        Presets (official first); * marks the active one.
                                         --json adds tags, a content hash and the look
                                         (values the thumbnails are drawn from)
    apply <name>                         Copy the preset over the live config (hot-applies)
    save <name> [--domains a,b] [--force]
                                         Save the live config (+ matugen scheme) as a user preset
    update <name> [--domains a,b]        Overwrite a user preset with the live config
    diff <a> <b> [--json]                Keys that differ (names, "current", "defaults", bundles)
    show <name> [--against B] [--json]   What a preset changes, aspect by aspect (vs defaults
                                         or B), and which presets share each aspect
    aspects [--json]                     The mixable aspects and the files/keys they cover
    mix <name> --layout A --colors B --windows C --desktop D --lockscreen E [--force]
                                         New preset from per-aspect sources (any preset,
                                         "current" or "defaults"; omitted aspects are left out)
    duplicate <name> [<new name>]        Copy any preset (built-in too) to a user preset
    rename <name> <new name>             Rename a user preset
    delete <name> [--json]               Move a user preset to the trash (restorable 7 days)
    restore <id|name>                    Bring a deleted preset back
    trash [--json]                       Deleted presets
    set-info <name> [--description D] [--author A]
    export <name|current> <file>         Write a single-file bundle
    import <file> [--name N] [--force]   Create a user preset from a bundle
    try <name>                           Apply for a trial (backs up the live config);
    try --keep | --revert | --status     then keep it or go back
    edit <name>                          Apply a user preset so edits go into it;
    edit --save [--keep] | --cancel | --status
                                         save the live config into it and restore the look
                                         from before (--keep: stay on it), or discard
    active                               Name of the last applied preset

Built-in presets are read-only: duplicate them to edit.

Shortcuts: "{bin} preset" lists, "{bin} preset <name>" applies.
`

func presetManager() (*presets.Manager, error) {
	env, err := loadConfigEnv()
	if err != nil {
		return nil, err
	}
	official := ""
	if env.src != "" {
		official = filepath.Join(env.src, "assets", "presets")
	}
	p := paths.New()
	return &presets.Manager{
		Cat: env.cat, Store: env.store,
		UserDir:       filepath.Join(p.ConfigDir, "presets"),
		OfficialDir:   official,
		WallpaperFile: filepath.Join(p.CacheDir, "wallpapers.json"),
		StateDir:      p.StateDir,
	}, nil
}

// runPreset implements `yozakura preset ...`.
func runPreset(args []string, out, errOut io.Writer) int {
	if len(args) > 0 && (args[0] == "help" || args[0] == "-h" || args[0] == "--help") {
		fmt.Fprint(out, branded(presetUsage))
		return 0
	}
	m, err := presetManager()
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	cmd, rest := "list", []string{}
	if len(args) > 0 {
		cmd, rest = args[0], args[1:]
	}
	switch cmd {
	case "list", "ls", "-l", "--list":
		err = presetListCmd(m, rest, out)
	case "apply", "load":
		err = presetApplyCmd(m, strings.Join(rest, " "), out, errOut)
	case "save":
		err = presetSaveCmd(m, rest, out)
	case "diff":
		err = presetDiffCmd(m, rest, out)
	case "export":
		err = presetExportCmd(m, rest, out)
	case "import":
		err = presetImportCmd(m, rest, out, errOut)
	case "update":
		err = presetUpdateCmd(m, rest, out)
	case "show", "inspect":
		err = presetShowCmd(m, rest, out)
	case "aspects":
		err = presetAspectsCmd(rest, out)
	case "mix":
		err = presetMixCmd(m, rest, out)
	case "duplicate", "dup", "copy":
		err = presetDuplicateCmd(m, rest, out)
	case "rename", "mv":
		err = presetRenameCmd(m, rest, out)
	case "delete", "rm", "remove":
		err = presetDeleteCmd(m, rest, out)
	case "restore", "undelete":
		err = presetRestoreCmd(m, rest, out)
	case "trash":
		err = presetTrashCmd(m, rest, out)
	case "set-info":
		err = presetSetInfoCmd(m, rest, out)
	case "try":
		err = presetSessionCmd(m, presets.TrySession, rest, out, errOut)
	case "edit":
		err = presetSessionCmd(m, presets.EditSession, rest, out, errOut)
	case "active":
		fmt.Fprintln(out, m.Active())
	case "__names":
		for _, p := range m.List() {
			fmt.Fprintln(out, p.Name)
		}
	default:
		if strings.HasPrefix(cmd, "-") {
			err = fmt.Errorf("unknown flag %s (see `%s preset help`)", cmd, brand.AppID)
			break
		}
		// Legacy form: `yozakura preset "Name"` applies.
		err = presetApplyCmd(m, strings.Join(args, " "), out, errOut)
	}
	if err != nil {
		fmt.Fprintf(errOut, "Error: %v\n", err)
		return 1
	}
	return 0
}

func presetListCmd(m *presets.Manager, args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, nil)
	list := m.List()
	if a.has("json") {
		if list == nil {
			list = []presets.Preset{}
		}
		return writeJSON(out, m.WithLooks(list))
	}
	if len(list) == 0 {
		fmt.Fprintln(out, "No presets found.")
		return nil
	}
	width := 0
	for _, p := range list {
		width = max(width, len([]rune(p.Name)))
	}
	for _, p := range list {
		mark, tag := " ", "[user]"
		if p.Active {
			mark = "*"
		}
		if p.Official {
			tag = "[official]"
		}
		author := ""
		if p.Author != "" && p.Author != "Unknown" {
			author = "  by " + p.Author
		}
		pad := width - len([]rune(p.Name))
		fmt.Fprintf(out, "%s %s%s  %-10s%s\n", mark, p.Name, strings.Repeat(" ", pad), tag, author)
	}
	return nil
}

func reportProblems(errOut io.Writer, problems []catalog.Problem) {
	for _, p := range problems {
		fmt.Fprintf(errOut, "warning: %s: %s\n", p.Key, p.Message)
	}
}

func presetApplyCmd(m *presets.Manager, name string, out, errOut io.Writer) error {
	if strings.TrimSpace(name) == "" {
		return fmt.Errorf("usage: %s preset apply <name>", brand.AppID)
	}
	p, problems, err := m.Apply(name)
	if err != nil {
		return err
	}
	reportProblems(errOut, problems)
	fmt.Fprintf(out, "Preset applied: %s (%s)\n", p.Name, strings.Join(p.Domains, ", "))
	return nil
}

func presetSaveCmd(m *presets.Manager, args []string, out io.Writer) error {
	a := parseCLI(args, []string{"force"}, []string{"domains"})
	if len(a.pos) == 0 {
		return fmt.Errorf("usage: %s preset save <name> [--domains bar,theme] [--force]", brand.AppID)
	}
	var domains []string
	if v, ok := a.value("domains"); ok {
		for _, d := range strings.Split(v, ",") {
			if d = strings.TrimSpace(d); d != "" {
				domains = append(domains, d)
			}
		}
	}
	p, err := m.Save(strings.Join(a.pos, " "), domains, a.has("force"))
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "Saved preset %s (%s) to %s\n", p.Name, strings.Join(p.Domains, ", "), p.Path)
	return nil
}

func presetDiffCmd(m *presets.Manager, args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, nil)
	if len(a.pos) != 2 {
		return fmt.Errorf("usage: %s preset diff <a> <b>  (names, \"current\" or bundle files)", brand.AppID)
	}
	diffs, err := m.Compare(a.pos[0], a.pos[1])
	if err != nil {
		return err
	}
	if a.has("json") {
		if diffs == nil {
			diffs = []presets.Diff{}
		}
		return writeJSON(out, diffs)
	}
	if len(diffs) == 0 {
		fmt.Fprintln(out, "No differences.")
		return nil
	}
	fmt.Fprintf(out, "--- %s\n+++ %s\n", a.pos[0], a.pos[1])
	for _, d := range diffs {
		switch d.OnlyIn {
		case "a":
			fmt.Fprintf(out, "%s: only in %s\n", d.Key, a.pos[0])
		case "b":
			fmt.Fprintf(out, "%s: only in %s\n", d.Key, a.pos[1])
		default:
			fmt.Fprintf(out, "%s: %s -> %s\n", d.Key, catalog.Compact(d.A), catalog.Compact(d.B))
		}
	}
	fmt.Fprintf(out, "%d difference(s)\n", len(diffs))
	return nil
}

func presetExportCmd(m *presets.Manager, args []string, out io.Writer) error {
	if len(args) != 2 {
		return fmt.Errorf("usage: %s preset export <name|current> <file>", brand.AppID)
	}
	b, err := m.Export(args[0], expandTilde(args[1]))
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "Exported %s (%s) to %s\n", b.Name, strings.Join(b.DomainNames(), ", "), args[1])
	return nil
}

func presetImportCmd(m *presets.Manager, args []string, out, errOut io.Writer) error {
	a := parseCLI(args, []string{"force"}, []string{"name"})
	if len(a.pos) != 1 {
		return fmt.Errorf("usage: %s preset import <file> [--name N] [--force]", brand.AppID)
	}
	name, _ := a.value("name")
	p, problems, err := m.Import(expandTilde(a.pos[0]), name, a.has("force"))
	if err != nil {
		return err
	}
	reportProblems(errOut, problems)
	fmt.Fprintf(out, "Imported preset %s (%s); apply it with `%s preset apply \"%s\"`\n", p.Name, strings.Join(p.Domains, ", "), brand.AppID, p.Name)
	return nil
}
