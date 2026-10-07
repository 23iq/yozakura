package main

import (
	"fmt"
	"io"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/presets"
)

// presetPartsCmd implements `preset parts [--json]`: the layouts, styles
// and palettes sets are built from, and the current one of each kind.
func presetPartsCmd(m *presets.Manager, args []string, out io.Writer) error {
	a := parseCLI(args, []string{"json"}, nil)
	if a.has("json") {
		r, err := m.AllParts()
		if err != nil {
			return err
		}
		return writeJSON(out, r)
	}
	for _, kind := range presets.PartKinds {
		parts, err := m.Parts(kind)
		if err != nil {
			return err
		}
		fmt.Fprintf(out, "%ss:\n", kind)
		if len(parts) == 0 {
			fmt.Fprintln(out, "  (none)")
		}
		for _, p := range parts {
			mark := " "
			if p.Active {
				mark = "*"
			}
			desc := ""
			if p.Description != "" {
				desc = "  " + p.Description
			}
			fmt.Fprintf(out, "%s %s%s\n", mark, p.Name, desc)
		}
	}
	return nil
}

// presetApplyPartCmd implements `preset apply --part <kind> [--preview] <name>`.
func presetApplyPartCmd(m *presets.Manager, kind, name string, preview bool, out, errOut io.Writer) error {
	if strings.TrimSpace(name) == "" {
		return fmt.Errorf("usage: %s preset apply --part <%s> [--preview] <name>", brand.AppID, strings.Join(presets.PartKinds, "|"))
	}
	if preview {
		s, err := m.PreviewPart(kind, name)
		if err != nil {
			return err
		}
		fmt.Fprintf(out, "Previewing %s %s: `%s preset revert` goes back\n", kind, s.Preset, brand.AppID)
		return nil
	}
	p, problems, err := m.ApplyPart(kind, name)
	if err != nil {
		return err
	}
	reportProblems(errOut, problems)
	fmt.Fprintf(out, "Applied %s %s (%s)\n", kind, p.Name, strings.Join(p.Domains, ", "))
	return nil
}
