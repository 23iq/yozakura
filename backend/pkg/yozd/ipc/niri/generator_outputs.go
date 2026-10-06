package niri

import (
	"fmt"
	"strconv"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// niriKdlTransforms maps wl_output transform numbers to niri KDL config names.
var niriKdlTransforms = [8]string{"normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"}

func niriNum(f float64) string { return strconv.FormatFloat(f, 'f', -1, 64) }

// GenerateOutputs renders one `output` block per valid monitor.
func (g *Generator) GenerateOutputs(monitors []ipc.OutputConfig) string {
	var b strings.Builder
	for _, m := range ipc.ValidOutputs(monitors) {
		b.WriteString("output " + kdlQuote(m.Name) + " {\n")
		if !m.Enabled {
			b.WriteString("    off\n}\n")
			continue
		}
		if m.Width > 0 && m.Height > 0 {
			mode := fmt.Sprintf("%dx%d", m.Width, m.Height)
			if m.Refresh > 0 {
				mode += fmt.Sprintf("@%.3f", m.Refresh)
			}
			b.WriteString("    mode " + kdlQuote(mode) + "\n")
		}
		if m.Scale > 0 {
			b.WriteString("    scale " + niriNum(m.Scale) + "\n")
		}
		if !m.AutoPosition {
			b.WriteString(fmt.Sprintf("    position x=%d y=%d\n", m.X, m.Y))
		}
		b.WriteString("    transform " + kdlQuote(niriKdlTransforms[m.Transform]) + "\n")
		switch m.VRR {
		case 1:
			b.WriteString("    variable-refresh-rate\n")
		case 2:
			b.WriteString("    variable-refresh-rate on-demand=true\n")
		}
		b.WriteString("}\n")
	}
	return b.String()
}

// GenerateKeyboard renders the `input { keyboard { ... } }` block.
func (g *Generator) GenerateKeyboard(keyboard *ipc.KeyboardSettings) string {
	k := ipc.ValidKeyboard(keyboard)
	if k == nil {
		return ""
	}
	layouts, variants, options := k.Joined()
	var b strings.Builder
	b.WriteString("input {\n    keyboard {\n        xkb {\n")
	b.WriteString("            layout " + kdlQuote(layouts) + "\n")
	b.WriteString("            variant " + kdlQuote(variants) + "\n")
	if options != "" {
		b.WriteString("            options " + kdlQuote(options) + "\n")
	}
	if k.Model != "" {
		b.WriteString("            model " + kdlQuote(k.Model) + "\n")
	}
	b.WriteString("        }\n")
	if k.RepeatRate > 0 {
		b.WriteString(fmt.Sprintf("        repeat-rate %d\n", k.RepeatRate))
	}
	if k.RepeatDelay > 0 {
		b.WriteString(fmt.Sprintf("        repeat-delay %d\n", k.RepeatDelay))
	}
	b.WriteString("    }\n}\n")
	return b.String()
}
