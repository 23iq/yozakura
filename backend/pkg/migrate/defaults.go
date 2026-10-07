package migrate

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"

	"yozakura/backend/pkg/catalog"
	"yozakura/backend/pkg/fsutil"
	"yozakura/backend/pkg/paths"
)

// The theme overhaul changed some defaults. A key missing from a config
// file follows the new default on its own; a file that stores the OLD
// default (written by the settings, a preset or an older build) is moved
// to the new one, once. A value the user set to anything else is kept.

// DefaultsShiftMarker records that the default shift ran (data dir).
const DefaultsShiftMarker = ".defaults-shift-theme-overhaul"

// DefaultShift is one changed default: domain + key path, old -> new.
type DefaultShift struct {
	Domain string
	Path   []string
	Old    any
	New    any
}

// DefaultShifts are the theme overhaul's changed defaults.
var DefaultShifts = []DefaultShift{
	{"theme", []string{"shape", "popupCorners"}, "", "cut"},
	{"theme", []string{"signatures", "brushHighlight"}, false, true},
	{"theme", []string{"signatures", "petals"}, false, true},
	{"compositor", []string{"motionProfile"}, "smooth", "sakura"},
}

// EnsureDefaultsShift applies DefaultShifts once and records it. It
// returns the keys it rewrote ("theme.signatures.petals", ...). A missing
// or malformed file is left alone (the shell resets a malformed one).
func EnsureDefaultsShift(p paths.Paths) ([]string, error) {
	if p.ConfigDir == "" || p.DataDir == "" {
		return nil, nil
	}
	marker := filepath.Join(p.DataDir, DefaultsShiftMarker)
	if _, err := os.Stat(marker); err == nil {
		return nil, nil
	}
	var changed []string
	for _, domain := range shiftDomains() {
		keys, err := shiftFile(p.Config(domain), domain)
		if err != nil {
			return changed, err
		}
		changed = append(changed, keys...)
	}
	if err := os.MkdirAll(p.DataDir, 0o755); err != nil {
		return changed, err
	}
	return changed, fsutil.WriteFile(marker, []byte("1\n"), 0o644)
}

func shiftDomains() []string {
	var out []string
	seen := map[string]bool{}
	for _, s := range DefaultShifts {
		if !seen[s.Domain] {
			seen[s.Domain] = true
			out = append(out, s.Domain)
		}
	}
	return out
}

// shiftFile rewrites the old-default values of one domain file.
func shiftFile(path, domain string) ([]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	v, err := catalog.DecodeOrdered(data)
	if err != nil {
		return nil, nil
	}
	doc, ok := v.(*catalog.Object)
	if !ok {
		return nil, nil
	}
	var keys []string
	for _, s := range DefaultShifts {
		if s.Domain != domain {
			continue
		}
		if cur, ok := catalog.GetOrdered(doc, s.Path); ok && cur == s.Old {
			catalog.SetOrdered(doc, s.Path, s.New)
			keys = append(keys, domain+"."+strings.Join(s.Path, "."))
		}
	}
	if len(keys) == 0 {
		return nil, nil
	}
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return nil, err
	}
	return keys, fsutil.WriteFile(path, append(out, '\n'), 0o644)
}
