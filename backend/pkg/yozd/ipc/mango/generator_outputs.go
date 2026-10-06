package mango

import (
	"fmt"
	"strconv"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

func mangoNum(f float64) string { return strconv.FormatFloat(f, 'f', -1, 64) }

// mangoRegexName anchors a connector name as a regex. Connector names are
// [A-Za-z0-9._-], so only '.' needs escaping.
func mangoRegexName(name string) string {
	return "^" + strings.ReplaceAll(name, ".", `\.`) + "$"
}

// GenerateOutputs renders one `monitor_rule=` line per valid monitor.
// width/height/refresh are omitted for the preferred mode, x/y for automatic
// placement (mango rejects negative x/y, so those entries omit them too).
func (g *Generator) GenerateOutputs(monitors []ipc.OutputConfig) string {
	var b strings.Builder
	for _, m := range ipc.ValidOutputs(monitors) {
		parts := []string{"name:" + mangoRegexName(m.Name)}
		if !m.Enabled {
			parts = append(parts, "disable:1")
			b.WriteString("monitor_rule=" + strings.Join(parts, ",") + "\n")
			continue
		}
		if m.Width > 0 && m.Height > 0 {
			parts = append(parts, fmt.Sprintf("width:%d", m.Width), fmt.Sprintf("height:%d", m.Height))
			if m.Refresh > 0 {
				parts = append(parts, "refresh:"+mangoNum(m.Refresh))
			}
		}
		if !m.AutoPosition && m.X >= 0 && m.Y >= 0 {
			parts = append(parts, fmt.Sprintf("x:%d", m.X), fmt.Sprintf("y:%d", m.Y))
		}
		if m.Scale > 0 {
			parts = append(parts, "scale:"+mangoNum(m.Scale))
		}
		vrr := 0
		if m.VRR > 0 {
			vrr = 1
		}
		parts = append(parts, fmt.Sprintf("vrr:%d", vrr), fmt.Sprintf("rr:%d", m.Transform))
		b.WriteString("monitor_rule=" + strings.Join(parts, ",") + "\n")
	}
	return b.String()
}

// GenerateKeyboard renders the xkb_rules_* and key repeat keywords.
func (g *Generator) GenerateKeyboard(keyboard *ipc.KeyboardSettings) string {
	k := ipc.ValidKeyboard(keyboard)
	if k == nil {
		return ""
	}
	layouts, variants, options := k.Joined()
	var b strings.Builder
	b.WriteString("xkb_rules_layout=" + layouts + "\n")
	b.WriteString("xkb_rules_variant=" + variants + "\n")
	if options != "" {
		b.WriteString("xkb_rules_options=" + options + "\n")
	}
	if k.Model != "" {
		b.WriteString("xkb_rules_model=" + k.Model + "\n")
	}
	if k.RepeatRate > 0 {
		b.WriteString(fmt.Sprintf("repeat_rate=%d\n", k.RepeatRate))
	}
	if k.RepeatDelay > 0 {
		b.WriteString(fmt.Sprintf("repeat_delay=%d\n", k.RepeatDelay))
	}
	return b.String()
}
