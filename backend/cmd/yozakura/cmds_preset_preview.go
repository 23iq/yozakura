package main

import (
	"fmt"
	"io"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/presets"
)

// presetApplyArgs implements `preset apply [--part <kind>] [--preview]
// <name>`. A preview is undone by `preset revert`; a plain apply during
// one keeps it.
func presetApplyArgs(m *presets.Manager, args []string, out, errOut io.Writer) error {
	preview, part := false, ""
	var names []string
	for i := 0; i < len(args); i++ {
		switch a := args[i]; {
		case a == "--preview":
			preview = true
		case a == "--part" && i+1 < len(args):
			part = args[i+1]
			i++
		case strings.HasPrefix(a, "--part="):
			part = strings.TrimPrefix(a, "--part=")
		case a == "--part":
			return fmt.Errorf("--part needs a kind (%s)", strings.Join(presets.PartKinds, ", "))
		default:
			names = append(names, a)
		}
	}
	name := strings.Join(names, " ")
	if part != "" {
		return presetApplyPartCmd(m, part, name, preview, out, errOut)
	}
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
