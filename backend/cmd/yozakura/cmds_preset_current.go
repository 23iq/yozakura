package main

import (
	"fmt"
	"io"
	"strings"

	"yozakura/backend/pkg/presets"
)

// The active preset against the live config: `preset status`,
// `preset save --current [--as NAME]`, `preset save --undo ID` and
// `preset apply --json` (what the apply set, reset and kept).

// presetApplyReportCmd is `apply [--exact] [--json] <name>`: --exact also
// resets the settings changed since (Revert to preset).
func presetApplyReportCmd(m *presets.Manager, name string, exact, asJSON bool, out io.Writer) error {
	if strings.TrimSpace(name) == "" {
		return fmt.Errorf("usage: preset apply [--exact] [--json] <name>")
	}
	apply := m.ApplyReport
	if exact {
		apply = m.ApplyExact
	}
	p, sum, problems, err := apply(name)
	if err != nil {
		return err
	}
	if !asJSON {
		fmt.Fprintf(out, "Preset applied: %s (%d set, %d reset, %d kept)\n", p.Name, len(sum.Set), len(sum.Reset), len(sum.Kept))
		return nil
	}
	return writeJSON(out, map[string]any{
		"preset": p.Name, "domains": p.Domains, "set": nonNil(sum.Set), "reset": nonNil(sum.Reset),
		"keptUserValues": nonNil(sum.Kept), "warnings": problems,
	})
}

func presetStatusCmd(m *presets.Manager, args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, nil)
	st, err := m.Status()
	if err != nil {
		return err
	}
	if a.has("json") {
		return writeJSON(out, st)
	}
	if st.Active == "" {
		fmt.Fprintln(out, "No preset is active.")
		return nil
	}
	kind := "user"
	if st.Official {
		kind = "official"
	}
	fmt.Fprintf(out, "Preset: %s [%s] · %d change(s)\n", st.Active, kind, st.Changed)
	if st.Session != "" {
		fmt.Fprintf(out, "A preset %s is in progress.\n", st.Session)
	}
	for _, d := range st.Changes {
		fmt.Fprintf(out, "  %s: %v (preset: %v)\n", d.Key, d.A, d.B)
	}
	return nil
}

func presetSaveCurrentCmd(m *presets.Manager, a cliArgs, out io.Writer) error {
	if id, ok := a.value("undo"); ok {
		p, err := m.UndoSave(id)
		if err != nil {
			return err
		}
		fmt.Fprintf(out, "Restored preset %s\n", p.Name)
		return nil
	}
	var (
		p    presets.Preset
		undo string
		err  error
	)
	if name, ok := a.value("as"); ok {
		p, err = m.SaveCurrentAs(name)
	} else {
		p, undo, err = m.SaveCurrent()
	}
	if err != nil {
		return err
	}
	if a.has("json") {
		return writeJSON(out, map[string]any{"preset": p.Name, "undo": undo})
	}
	fmt.Fprintf(out, "Saved the current settings into %s\n", p.Name)
	return nil
}

func nonNil(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}
