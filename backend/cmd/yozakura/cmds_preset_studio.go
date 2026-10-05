package main

import (
	"fmt"
	"io"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/presets"
)

// Preset studio commands (`yozakura preset show|mix|duplicate|...`): the
// settings window's preset studio runs exactly these.

func splitDomains(a cliArgs) []string {
	var out []string
	if v, ok := a.value("domains"); ok {
		for _, d := range strings.Split(v, ",") {
			if d = strings.TrimSpace(d); d != "" {
				out = append(out, d)
			}
		}
	}
	return out
}

func presetUpdateCmd(m *presets.Manager, args []string, out io.Writer) error {
	a := parseCLI(args, nil, []string{"domains"})
	if len(a.pos) == 0 {
		return fmt.Errorf("usage: %s preset update <name> [--domains bar,theme]", brand.AppID)
	}
	p, err := m.Update(strings.Join(a.pos, " "), splitDomains(a))
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "Updated preset %s from the live config\n", p.Name)
	return nil
}

func presetShowCmd(m *presets.Manager, args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, []string{"against"})
	if len(a.pos) == 0 {
		return fmt.Errorf("usage: %s preset show <name> [--against <preset|defaults>] [--json]", brand.AppID)
	}
	against, _ := a.value("against")
	ins, err := m.Inspect(strings.Join(a.pos, " "), against)
	if err != nil {
		return err
	}
	if a.has("json") {
		return writeJSON(out, ins)
	}
	p := ins.Preset
	kind := "user"
	if p.Official {
		kind = "built-in, read-only"
	}
	fmt.Fprintf(out, "%s (%s)", p.Name, kind)
	if p.Author != "" && p.Author != "Unknown" {
		fmt.Fprintf(out, " by %s", p.Author)
	}
	fmt.Fprintln(out)
	if p.Description != "" {
		fmt.Fprintln(out, "  "+p.Description)
	}
	if len(p.Tags) > 0 {
		fmt.Fprintln(out, "  tags: "+strings.Join(p.Tags, ", "))
	}
	fmt.Fprintf(out, "\nAgainst %s:\n", ins.Against)
	for _, r := range ins.Aspects {
		state := fmt.Sprintf("%d change(s)", len(r.Changes))
		if !r.Carried {
			state = "not set (keeps your values)"
		}
		fmt.Fprintf(out, "  %-11s %s", r.ID, state)
		if len(r.SameAs) > 0 {
			fmt.Fprintf(out, "  [same as %s]", strings.Join(r.SameAs, ", "))
		}
		fmt.Fprintln(out)
		for _, c := range r.Changes {
			fmt.Fprintf(out, "      %s: %s -> %s\n", c.Key, catalog.Compact(c.From), catalog.Compact(c.To))
		}
	}
	return nil
}

func presetAspectsCmd(args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, nil)
	if a.has("json") {
		return writeJSON(out, presets.Aspects)
	}
	for _, as := range presets.Aspects {
		cover := strings.Join(as.Domains, ", ")
		if len(as.Keys) > 0 {
			cover += ", " + strings.Join(as.Keys, ", ")
		}
		fmt.Fprintf(out, "%-11s %s  (settings: %s)\n", as.ID, cover, as.Category)
	}
	return nil
}

func presetMixCmd(m *presets.Manager, args []string, out io.Writer) error {
	valued := []string{"description"}
	for _, as := range presets.Aspects {
		valued = append(valued, as.ID)
	}
	a := parseCLI(args, []string{"force", "json"}, valued)
	if len(a.pos) == 0 {
		return fmt.Errorf("usage: %s preset mix <name> --layout A --colors B --windows C --desktop D --lockscreen E", brand.AppID)
	}
	sources := map[string]string{}
	for _, as := range presets.Aspects {
		if v, ok := a.value(as.ID); ok && v != "" {
			sources[as.ID] = v
		}
	}
	if len(sources) == 0 {
		return fmt.Errorf("pick at least one aspect source (--layout, --colors, --windows, --desktop, --lockscreen)")
	}
	desc, _ := a.value("description")
	p, err := m.Mix(strings.Join(a.pos, " "), sources, desc, a.has("force"))
	if err != nil {
		return err
	}
	if a.has("json") {
		return writeJSON(out, p)
	}
	fmt.Fprintf(out, "Created preset %s (%s)\n", p.Name, p.Description)
	return nil
}

func presetDuplicateCmd(m *presets.Manager, args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, nil)
	if len(a.pos) < 1 || len(a.pos) > 2 {
		return fmt.Errorf("usage: %s preset duplicate <name> [<new name>]  (quote names with spaces)", brand.AppID)
	}
	name := ""
	if len(a.pos) == 2 {
		name = a.pos[1]
	}
	p, err := m.Duplicate(a.pos[0], name)
	if err != nil {
		return err
	}
	if a.has("json") {
		return writeJSON(out, p)
	}
	fmt.Fprintf(out, "Created preset %s\n", p.Name)
	return nil
}

func presetRenameCmd(m *presets.Manager, args []string, out io.Writer) error {
	if len(args) != 2 {
		return fmt.Errorf("usage: %s preset rename <name> <new name>  (quote names with spaces)", brand.AppID)
	}
	p, err := m.Rename(args[0], args[1])
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "Renamed to %s\n", p.Name)
	return nil
}

func presetDeleteCmd(m *presets.Manager, args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, nil)
	if len(a.pos) == 0 {
		return fmt.Errorf("usage: %s preset delete <name>", brand.AppID)
	}
	t, err := m.Delete(strings.Join(a.pos, " "))
	if err != nil {
		return err
	}
	if a.has("json") {
		return writeJSON(out, t)
	}
	fmt.Fprintf(out, "Deleted %s (undo: `%s preset restore %s`)\n", t.Name, brand.AppID, t.ID)
	return nil
}

func presetRestoreCmd(m *presets.Manager, args []string, out io.Writer) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: %s preset restore <id|name>", brand.AppID)
	}
	p, err := m.Restore(strings.Join(args, " "))
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "Restored preset %s\n", p.Name)
	return nil
}

func presetTrashCmd(m *presets.Manager, args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, nil)
	list := m.Trash()
	if a.has("json") {
		return writeJSON(out, list)
	}
	if len(list) == 0 {
		fmt.Fprintln(out, "The preset trash is empty.")
	}
	for _, t := range list {
		fmt.Fprintf(out, "%s  %s  (deleted %s)\n", t.ID, t.Name, t.Deleted.Format("2006-01-02 15:04"))
	}
	return nil
}

func presetSetInfoCmd(m *presets.Manager, args []string, out io.Writer) error {
	a := parseCLI(args, nil, []string{"description", "author"})
	if len(a.pos) == 0 {
		return fmt.Errorf("usage: %s preset set-info <name> [--description D] [--author A]", brand.AppID)
	}
	var desc, author *string
	if v, ok := a.value("description"); ok {
		desc = &v
	}
	if v, ok := a.value("author"); ok {
		author = &v
	}
	p, err := m.SetInfo(strings.Join(a.pos, " "), desc, author)
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "Updated %s\n", p.Name)
	return nil
}

// presetSessionCmd implements `preset try ...` and `preset edit ...`.
func presetSessionCmd(m *presets.Manager, kind string, args []string, out, errOut io.Writer) error {
	a := parseCLI(args, []string{"keep", "revert", "save", "cancel", "status", "json"}, nil)
	switch {
	case a.has("status"):
		s, err := m.Session(kind)
		if err != nil {
			return err
		}
		if a.has("json") {
			return writeJSON(out, s)
		}
		if s == nil {
			fmt.Fprintf(out, "No preset %s in progress.\n", kind)
			return nil
		}
		fmt.Fprintf(out, "%s of %s since %s\n", kind, s.Preset, s.Started.Format("15:04:05"))
		return nil
	case a.has("keep") && kind == presets.TrySession, a.has("revert"), a.has("cancel"), a.has("save"):
		keep := a.has("keep")
		save := a.has("save") && kind == presets.EditSession
		s, err := m.End(kind, keep, save)
		if err != nil {
			return err
		}
		switch {
		case save && keep:
			fmt.Fprintf(out, "Saved into %s; it stays applied\n", s.Preset)
		case save:
			fmt.Fprintf(out, "Saved into %s; your previous look is back\n", s.Preset)
		case keep:
			fmt.Fprintf(out, "Kept %s\n", s.Preset)
		default:
			fmt.Fprintf(out, "Reverted %s; your previous look is back\n", s.Preset)
		}
		return nil
	}
	if len(a.pos) == 0 {
		if kind == presets.TrySession {
			return fmt.Errorf("usage: %s preset try <name> | --keep | --revert | --status", brand.AppID)
		}
		return fmt.Errorf("usage: %s preset edit <name> | --save [--keep] | --cancel | --status", brand.AppID)
	}
	s, problems, err := m.Begin(kind, strings.Join(a.pos, " "))
	if err != nil {
		return err
	}
	reportProblems(errOut, problems)
	if kind == presets.TrySession {
		fmt.Fprintf(out, "Trying %s: `%s preset try --keep` keeps it, `--revert` goes back\n", s.Preset, brand.AppID)
	} else {
		fmt.Fprintf(out, "Editing %s: change settings as usual, then `%s preset edit --save` (or --cancel)\n", s.Preset, brand.AppID)
	}
	return nil
}
