package displays

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"yozakura/backend/pkg/brand"
	"yozakura/backend/pkg/yozd/ipc"
)

// Conflict is a user monitor rule that overrides the generated ones.
type Conflict struct {
	File string `json:"file"`
	Line int    `json:"line"` // 1-based
	Text string `json:"text"`
	// Reason says why a rule was not moved (MoveResult.Skipped only).
	Reason string `json:"reason,omitempty"`
}

// MoveResult lists the rules commented out (Moved, parsed into Outputs for
// import) and the ones left untouched because they could not be parsed.
type MoveResult struct {
	Outputs []ipc.OutputConfig `json:"outputs"`
	Moved   []Conflict         `json:"moved"`
	Skipped []Conflict         `json:"skipped"`
}

var (
	confMonitorRe = regexp.MustCompile(`^\s*monitor\s*=`)
	luaMonitorRe  = regexp.MustCompile(`^\s*hl\.monitor\s*\(`)
	luaFieldRe    = regexp.MustCompile(`(\w+)\s*=\s*("[^"]*"|'[^']*'|[^,}\s]+)`)
	modeRe        = regexp.MustCompile(`^(\d+)x(\d+)(?:@(\d+(?:\.\d+)?)(?:Hz)?)?$`)
	positionRe    = regexp.MustCompile(`^(-?\d+)x(-?\d+)$`)
)

func comment(lua bool) string {
	if lua {
		return "--"
	}
	return "#"
}

// movedPrefix comments out a moved rule.
func movedPrefix(lua bool) string { return comment(lua) + " " + brand.AppID + ": moved " }

// ScanConflicts lists `monitor =` (.conf) and `hl.monitor(` (.lua) lines in
// hyprDir, recursively, skipping our installer block and any file that
// resolves into dataDir (the generated configs).
func ScanConflicts(hyprDir, dataDir string) ([]Conflict, error) {
	out := []Conflict{}
	err := WalkConfigs(hyprDir, dataDir, func(path string, lua bool, lines []string) error {
		for _, n := range conflictLines(lines, lua) {
			out = append(out, Conflict{File: path, Line: n + 1, Text: strings.TrimSpace(lines[n])})
		}
		return nil
	})
	return out, err
}

// WalkConfigs calls fn with the lines of every .conf/.lua file under root
// (sorted), following file symlinks except into dataDir.
func WalkConfigs(root, dataDir string, fn func(path string, lua bool, lines []string) error) error {
	realData, err := filepath.EvalSymlinks(dataDir)
	if err != nil {
		realData = dataDir
	}
	err = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			if path == root && os.IsNotExist(err) {
				return filepath.SkipDir
			}
			return nil // unreadable entry: skip it, keep scanning
		}
		if d.IsDir() {
			return nil
		}
		ext := filepath.Ext(path)
		if ext != ".conf" && ext != ".lua" {
			return nil
		}
		real, err := filepath.EvalSymlinks(path)
		if err != nil || within(real, realData) || within(real, dataDir) {
			return nil
		}
		data, err := os.ReadFile(real)
		if err != nil {
			return nil
		}
		return fn(path, ext == ".lua", strings.Split(string(data), "\n"))
	})
	if err != nil {
		return fmt.Errorf("scan %s: %w", root, err)
	}
	return nil
}

func within(path, dir string) bool {
	rel, err := filepath.Rel(dir, path)
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}

// conflictLines returns the 0-based indexes of monitor rules outside our
// installer block. The block runs from the marker line to the first blank
// line, OVERRIDES header or overrides note, whichever comes first: the
// installer writes "marker, load line, blank", so a block whose trailer was
// edited away never hides the user's rules below it.
func conflictLines(lines []string, lua bool) []int {
	c := comment(lua)
	re := confMonitorRe
	if lua {
		re = luaMonitorRe
	}
	var out []int
	inBlock := false
	for i, line := range lines {
		t := strings.TrimSpace(line)
		switch {
		case t == brand.ConfigBlockMarker(c):
			inBlock = true
		case inBlock && (t == "" || t == c+" OVERRIDES" || t == brand.ConfigOverridesNote(c, "source")):
			inBlock = false
		case !inBlock && re.MatchString(line):
			out = append(out, i)
		}
	}
	return out
}

// ParseMonitorLine parses `monitor = NAME,MODE,POS,SCALE[,transform,N][,vrr,N]`
// (or NAME,disable) and single-line `hl.monitor({ output = ..., ... })`.
// Rules that cannot be expressed as an OutputConfig (desc: names, mirror,
// highres) are errors.
func ParseMonitorLine(line string, lua bool) (ipc.OutputConfig, error) {
	if lua {
		return parseLuaMonitor(line)
	}
	return parseConfMonitor(line)
}

func parseConfMonitor(line string) (ipc.OutputConfig, error) {
	_, value, _ := strings.Cut(line, "=")
	value, _, _ = strings.Cut(value, "#")
	f := strings.Split(value, ",")
	for i := range f {
		f[i] = strings.TrimSpace(f[i])
	}
	cfg := ipc.OutputConfig{Name: f[0], Enabled: true}
	if len(f) >= 2 && (f[1] == "disable" || f[1] == "disabled") {
		cfg.Enabled = false
		return cfg, cfg.Validate()
	}
	if len(f) < 4 {
		return cfg, fmt.Errorf("incomplete monitor rule %q", strings.TrimSpace(line))
	}
	if err := setMode(&cfg, f[1]); err != nil {
		return cfg, err
	}
	if err := setPosition(&cfg, f[2]); err != nil {
		return cfg, err
	}
	if err := setScale(&cfg, f[3]); err != nil {
		return cfg, err
	}
	if (len(f)-4)%2 != 0 {
		return cfg, fmt.Errorf("unsupported: %s", f[len(f)-1])
	}
	for i := 4; i+1 < len(f); i += 2 {
		if err := setExtra(&cfg, f[i], f[i+1]); err != nil {
			return cfg, err
		}
	}
	return cfg, cfg.Validate()
}

func parseLuaMonitor(line string) (ipc.OutputConfig, error) {
	t := strings.TrimSpace(line)
	open, end := strings.Index(t, "{"), strings.Index(t, "})")
	if open < 0 || end < open {
		return ipc.OutputConfig{}, fmt.Errorf("not a single-line hl.monitor call")
	}
	// only `;` and a `-- comment` may follow the call
	if rest := strings.TrimPrefix(strings.TrimSpace(t[end+2:]), ";"); strings.TrimSpace(rest) != "" &&
		!strings.HasPrefix(strings.TrimSpace(rest), "--") {
		return ipc.OutputConfig{}, fmt.Errorf("not a single-line hl.monitor call")
	}
	fields := map[string]string{}
	for _, m := range luaFieldRe.FindAllStringSubmatch(t[open+1:end], -1) {
		fields[m[1]] = strings.Trim(m[2], `"'`)
		switch m[1] {
		case "output", "mode", "position", "scale", "transform", "vrr", "disabled":
		default:
			return ipc.OutputConfig{}, fmt.Errorf("unsupported: %s", m[1])
		}
	}
	cfg := ipc.OutputConfig{Name: fields["output"], Enabled: true}
	if cfg.Name == "" {
		return cfg, fmt.Errorf("hl.monitor without output")
	}
	if fields["disabled"] == "true" {
		cfg.Enabled = false
		return cfg, cfg.Validate()
	}
	steps := []struct {
		key, def string
		set      func(*ipc.OutputConfig, string) error
	}{{"mode", "preferred", setMode}, {"position", "auto", setPosition}, {"scale", "auto", setScale}}
	for _, s := range steps {
		v, ok := fields[s.key]
		if !ok {
			v = s.def
		}
		if err := s.set(&cfg, v); err != nil {
			return cfg, err
		}
	}
	for _, k := range []string{"transform", "vrr"} {
		if v, ok := fields[k]; ok {
			if err := setExtra(&cfg, k, v); err != nil {
				return cfg, err
			}
		}
	}
	return cfg, cfg.Validate()
}

func setMode(cfg *ipc.OutputConfig, v string) error {
	if v == "preferred" {
		return nil
	}
	m := modeRe.FindStringSubmatch(v)
	if m == nil {
		return fmt.Errorf("unsupported mode %q", v)
	}
	cfg.Width, _ = strconv.Atoi(m[1])
	cfg.Height, _ = strconv.Atoi(m[2])
	if m[3] != "" {
		cfg.Refresh, _ = strconv.ParseFloat(m[3], 64)
	}
	return nil
}

func setPosition(cfg *ipc.OutputConfig, v string) error {
	if strings.HasPrefix(v, "auto") {
		cfg.AutoPosition = true
		return nil
	}
	m := positionRe.FindStringSubmatch(v)
	if m == nil {
		return fmt.Errorf("unsupported position %q", v)
	}
	cfg.X, _ = strconv.Atoi(m[1])
	cfg.Y, _ = strconv.Atoi(m[2])
	return nil
}

func setScale(cfg *ipc.OutputConfig, v string) error {
	if v == "auto" {
		return nil
	}
	s, err := strconv.ParseFloat(v, 64)
	if err != nil {
		return fmt.Errorf("unsupported scale %q", v)
	}
	cfg.Scale = s
	return nil
}

// setExtra handles the optional key/value pairs. Only transform and vrr
// fit an OutputConfig; anything else (bitdepth, cm, sdrbrightness, mirror,
// ...) would be lost on import, so the rule is not movable.
func setExtra(cfg *ipc.OutputConfig, key, v string) error {
	switch key {
	case "transform", "vrr":
		n, err := strconv.Atoi(v)
		if v == "true" {
			n, err = 1, nil
		} else if v == "false" {
			n, err = 0, nil
		}
		if err != nil {
			return fmt.Errorf("unsupported %s %q", key, v)
		}
		if key == "transform" {
			cfg.Transform = n
		} else {
			cfg.VRR = n
		}
	default:
		return fmt.Errorf("unsupported: %s", key)
	}
	return nil
}
