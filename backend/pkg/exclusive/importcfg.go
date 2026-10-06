package exclusive

import (
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"yozakura/backend/pkg/svc/displays"
	"yozakura/backend/pkg/yozd/ipc"
)

// ScanImports collects the user's monitor rules (parsed with the displays
// conflict parser; rules it cannot express are left out) and keyboard
// settings from every .conf/.lua under hypr, skipping our installer block
// and anything resolving into dataDir. Monitors are deduplicated by name,
// the last rule winning; kb is nil when no keyboard key is set. Files are
// read in sorted path order (not Hyprland's source order), so a keyboard
// key set in two files takes the value of the later path: deterministic,
// and the plan shows the import before anything is written.
func ScanImports(hypr, dataDir string) ([]ipc.OutputConfig, *ipc.KeyboardSettings) {
	monitors := []ipc.OutputConfig{}
	index := map[string]int{}
	conflicts, _ := displays.ScanConflicts(hypr, dataDir)
	for _, c := range conflicts {
		cfg, err := displays.ParseMonitorLine(c.Text, filepath.Ext(c.File) == ".lua")
		if err != nil {
			continue
		}
		if i, ok := index[cfg.Name]; ok {
			monitors[i] = cfg
			continue
		}
		index[cfg.Name] = len(monitors)
		monitors = append(monitors, cfg)
	}
	values := map[string]string{}
	_ = displays.WalkConfigs(hypr, dataDir, func(_ string, lua bool, lines []string) error {
		for k, v := range parseKeyboard(lines, lua) {
			values[k] = v
		}
		return nil
	})
	return monitors, keyboardFrom(values)
}

var (
	kbKeys      = `kb_layout|kb_variant|kb_options|kb_model|repeat_rate|repeat_delay`
	confKbRe    = regexp.MustCompile(`^\s*(input:)?(` + kbKeys + `)\s*=\s*(.*?)\s*$`)
	luaKbRe     = regexp.MustCompile(`(?:^|[\s,;])(` + kbKeys + `)\s*=\s*("[^"]*"|'[^']*'|-?\d+)`)
	blockNameRe = regexp.MustCompile(`([\w:-]+)\s*=?\s*$`)
)

// parseKeyboard returns the keyboard keys set in the `input` section of one
// file: a conf `input { ... }` block (nested touchpad/device blocks
// excluded) or `input:key = v`, and a Lua `input = { ... }` table such as
// hl.config({ input = { kb_layout = "us" } }). Lua values must be literals
// (strings, or numbers for repeat_*); variables are ignored.
func parseKeyboard(lines []string, lua bool) map[string]string {
	out := map[string]string{}
	var stack []string
	top := func() string {
		if len(stack) == 0 {
			return ""
		}
		return stack[len(stack)-1]
	}
	for _, line := range lines {
		for _, seg := range splitBraces(stripComment(line, lua)) {
			if lua {
				if top() == "input" {
					for _, m := range luaKbRe.FindAllStringSubmatch(seg.text, -1) {
						v := m[2]
						quoted := strings.HasPrefix(v, `"`) || strings.HasPrefix(v, `'`)
						if strings.HasPrefix(m[1], "repeat_") == quoted {
							continue
						}
						out[m[1]] = strings.Trim(v, `"'`)
					}
				}
			} else if m := confKbRe.FindStringSubmatch(seg.text); m != nil &&
				((m[1] == "" && top() == "input") || (m[1] != "" && len(stack) == 0)) {
				out[m[2]] = m[3]
			}
			switch seg.delim {
			case '{':
				name := ""
				if m := blockNameRe.FindStringSubmatch(seg.text); m != nil {
					name = m[1]
				}
				stack = append(stack, name)
			case '}':
				if len(stack) > 0 {
					stack = stack[:len(stack)-1]
				}
			}
		}
	}
	return out
}

type segment struct {
	text  string
	delim byte // '{', '}' or 0 at end of line
}

// splitBraces cuts a line at braces outside quotes.
func splitBraces(line string) []segment {
	var out []segment
	var quote byte
	start := 0
	for i := 0; i < len(line); i++ {
		c := line[i]
		switch {
		case quote != 0:
			if c == quote {
				quote = 0
			}
		case c == '"' || c == '\'':
			quote = c
		case c == '{' || c == '}':
			out = append(out, segment{line[start:i], c})
			start = i + 1
		}
	}
	return append(out, segment{line[start:], 0})
}

// stripComment drops a trailing comment (`#` in conf, `--` outside quotes
// in Lua; `##` is an escaped # in conf).
func stripComment(line string, lua bool) string {
	if !lua {
		for i := 0; i < len(line); i++ {
			if line[i] == '#' {
				if i+1 < len(line) && line[i+1] == '#' {
					i++
					continue
				}
				return line[:i]
			}
		}
		return line
	}
	var quote byte
	for i := 0; i < len(line); i++ {
		c := line[i]
		switch {
		case quote != 0:
			if c == quote {
				quote = 0
			}
		case c == '"' || c == '\'':
			quote = c
		case c == '-' && i+1 < len(line) && line[i+1] == '-':
			return line[:i]
		}
	}
	return line
}

// keyboardFrom builds normalized settings from the collected keys.
func keyboardFrom(v map[string]string) *ipc.KeyboardSettings {
	if len(v) == 0 {
		return nil
	}
	split := func(s string) []string {
		parts := strings.Split(s, ",")
		for i := range parts {
			parts[i] = strings.TrimSpace(parts[i])
		}
		return parts
	}
	kb := ipc.KeyboardSettings{Model: v["kb_model"]}
	if s, ok := v["kb_layout"]; ok {
		kb.Layouts = split(s)
	}
	if s, ok := v["kb_variant"]; ok {
		kb.Variants = split(s)
	}
	if s, ok := v["kb_options"]; ok {
		kb.Options = split(s)
	}
	kb.RepeatRate, _ = strconv.Atoi(v["repeat_rate"])
	kb.RepeatDelay, _ = strconv.Atoi(v["repeat_delay"])
	kb = kb.Normalize()
	return &kb
}
