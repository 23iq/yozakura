package mango

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"yozakura/backend/pkg/yozd/ipc"
)

// MangoWC has no IPC request for its xkb settings: CurrentKeyboard reads
// the xkb_rules_* and repeat_* lines of <config>/mango/config.conf (best
// effort, following `source=` lines in place; the last value wins).
// Without a configured layout the settings are unknown and it answers
// ErrNotSupported.
func (m *Mango) CurrentKeyboard() (ipc.KeyboardSettings, error) {
	return ReadKeyboard(filepath.Join(ipc.ConfigHome(), "mango", "config.conf"))
}

// ReadKeyboard reads the keyboard settings of a mango config and its sources.
func ReadKeyboard(path string) (ipc.KeyboardSettings, error) {
	vals := map[string]string{}
	readKeyboard(path, map[string]bool{}, vals)
	if vals["xkb_rules_layout"] == "" {
		return ipc.KeyboardSettings{}, ipc.ErrNotSupported
	}
	split := func(s string) []string {
		if s == "" {
			return nil
		}
		return strings.Split(s, ",")
	}
	rate, _ := strconv.Atoi(vals["repeat_rate"])
	delay, _ := strconv.Atoi(vals["repeat_delay"])
	return ipc.KeyboardSettings{
		Layouts: split(vals["xkb_rules_layout"]), Variants: split(vals["xkb_rules_variant"]),
		Options: split(vals["xkb_rules_options"]), Model: vals["xkb_rules_model"],
		RepeatRate: rate, RepeatDelay: delay,
	}.Normalize(), nil
}

var mangoKeyboardKeys = map[string]bool{
	"xkb_rules_layout": true, "xkb_rules_variant": true, "xkb_rules_options": true, "xkb_rules_model": true,
	"repeat_rate": true, "repeat_delay": true,
}

func readKeyboard(path string, seen map[string]bool, vals map[string]string) {
	if seen[path] || len(seen) > 16 {
		return
	}
	seen[path] = true
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	for _, raw := range strings.Split(string(data), "\n") {
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		k, v = strings.TrimSpace(k), strings.TrimSpace(v)
		if i := strings.Index(v, " #"); i >= 0 {
			v = strings.TrimSpace(v[:i])
		}
		switch {
		case k == "source":
			readKeyboard(ipc.ExpandPath(v, filepath.Dir(path)), seen, vals)
		case mangoKeyboardKeys[k]:
			vals[k] = v
		}
	}
}

var _ ipc.KeyboardReader = (*Mango)(nil)
