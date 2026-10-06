package main

import (
	"fmt"
	"io"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/presets"
)

// presetApplyArgs implements `preset apply [--preview] <name>`. A preview
// is undone by `preset revert`; a plain apply during one keeps it.
func presetApplyArgs(m *presets.Manager, args []string, out, errOut io.Writer) error {
	preview := false
	var names []string
	for _, a := range args {
		if a == "--preview" {
			preview = true
		} else {
			names = append(names, a)
		}
	}
	name := strings.Join(names, " ")
	if !preview {
		return presetApplyCmd(m, name, out, errOut)
	}
	if strings.TrimSpace(name) == "" {
		return fmt.Errorf("usage: %s preset apply --preview <name>", brand.AppID)
	}
	s, err := m.Preview(name)
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "Previewing %s: `%s preset revert` goes back\n", s.Preset, brand.AppID)
	return nil
}

func presetRevertCmd(m *presets.Manager, out io.Writer) error {
	reverted, err := m.Revert()
	if err != nil {
		return err
	}
	if reverted {
		fmt.Fprintln(out, "Reverted the preview; your previous look is back")
	} else {
		fmt.Fprintln(out, "No preview to revert")
	}
	return nil
}
