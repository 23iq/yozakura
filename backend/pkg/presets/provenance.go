package presets

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"yozakura/backend/pkg/catalog"
)

// Provenance: applied.json (<data dir>/presets) remembers the value every
// preset apply wrote, key by key (first-level keys of each domain). A later
// apply of a whole snapshot can then tell a setting a preset left behind
// (reset to its default when the snapshot predates it, so switching back
// restores that look) from one the user changed since (kept: presets never
// override the user's own settings). Without a record nothing is reset.

// Applied is the provenance record.
type Applied struct {
	Preset string                    `json:"preset"`
	At     time.Time                 `json:"at"`
	Values map[string]map[string]any `json:"values"` // domain -> key -> value written
}

// ApplySummary is what an apply did, by full key: Set (the preset names
// it), Reset (left by an earlier preset, back to the default) and Kept (the
// user's own value, kept although the preset predates it).
type ApplySummary struct {
	Set   []string `json:"set"`
	Reset []string `json:"reset"`
	Kept  []string `json:"keptUserValues"`
}

// AppliedFile is the provenance record ("" without a data dir: none kept).
func (m *Manager) AppliedFile() string {
	if m.DataDir == "" {
		return ""
	}
	return filepath.Join(m.DataDir, "presets", "applied.json")
}

// readApplied returns the record, nil when there is none (or it is broken).
func (m *Manager) readApplied() *Applied {
	if m.AppliedFile() == "" {
		return nil
	}
	data, err := os.ReadFile(m.AppliedFile())
	if err != nil {
		return nil
	}
	var a Applied
	if json.Unmarshal(data, &a) != nil || a.Values == nil {
		return nil
	}
	return &a
}

func (m *Manager) writeApplied(a *Applied) error {
	if m.AppliedFile() == "" {
		return nil
	}
	data, err := json.MarshalIndent(a, "", "  ")
	if err != nil {
		return err
	}
	return writeAtomic(m.AppliedFile(), append(data, '\n'))
}

// wrote reports whether the record holds v as the value written for d.k.
func (a *Applied) wrote(d, k string, v any) bool {
	if a == nil {
		return false
	}
	w, ok := a.Values[d][k]
	return ok && canon(w) == canon(v)
}

// canon is an order-independent JSON rendering for equality.
func canon(v any) string {
	if o, ok := v.(*catalog.Object); ok {
		data, _ := json.Marshal(o)
		var plain any
		_ = json.Unmarshal(data, &plain)
		v = plain
	}
	data, err := json.Marshal(v)
	if err != nil {
		return ""
	}
	return string(data)
}

// liveTop is the live file of a domain as first-level values (nil: none).
func (m *Manager) liveTop(d string) map[string]any {
	data, err := os.ReadFile(m.Store.File(d))
	if err != nil {
		return nil
	}
	var doc map[string]any
	if json.Unmarshal(data, &doc) != nil {
		return nil
	}
	return doc
}

// effective is a first-level value as the shell runs it (missing: default).
func effective(live, defs map[string]any, k string) any {
	if v, ok := live[k]; ok {
		return v
	}
	return defs[k]
}

// localTop are the first-level keys of a domain that are machine-local.
func (m *Manager) localTop(d string) map[string]bool {
	out := map[string]bool{}
	for _, p := range m.localPaths(d) {
		if len(p) == 1 {
			out[p[0]] = true
		}
	}
	return out
}

// definedKeys lists, per catalog domain, the first-level keys the preset
// files name (followed and machine-local keys excluded: those stay the
// user's).
func (m *Manager) definedKeys(raw map[string][]byte, follows []string) map[string]map[string]bool {
	followed := map[string]bool{}
	for _, f := range follows {
		followed[f] = true
	}
	out := map[string]map[string]bool{}
	for d, data := range raw {
		if !m.Cat.HasDomain(d) {
			continue
		}
		var doc map[string]any
		if json.Unmarshal(data, &doc) != nil {
			continue
		}
		local := m.localTop(d)
		keys := map[string]bool{}
		for k := range doc {
			if !local[k] && !followed[d+"."+k] {
				keys[k] = true
			}
		}
		out[d] = keys
	}
	return out
}

// overProvenance turns the files of a whole snapshot into whole documents:
// a key the snapshot names is set (over its default, deep), a key it does
// not name is reset to its default only when its live value is still the
// one the last apply wrote (always with exact), and otherwise keeps the
// user's value.
func (m *Manager) overProvenance(raw map[string][]byte, defined map[string]map[string]bool, follows []string, exact bool) (map[string][]byte, ApplySummary, error) {
	prev := m.readApplied()
	followed := map[string]bool{}
	for _, f := range follows {
		followed[f] = true
	}
	var sum ApplySummary
	for _, d := range sortedKeys(raw) {
		if !m.Cat.HasDomain(d) {
			continue
		}
		live, defs, local := m.liveTop(d), m.Cat.DomainDefault(d), m.localTop(d)
		var doc map[string]any
		if json.Unmarshal(raw[d], &doc) != nil {
			continue
		}
		base := catalog.NewObject()
		for _, k := range m.Cat.TopKeys(d) {
			def, hasDef := defs[k]
			if _, named := doc[k]; named {
				if hasDef {
					base.Set(k, def)
				}
				if defined[d][k] {
					sum.Set = append(sum.Set, d+"."+k)
				}
				continue
			}
			cur, inLive := live[k]
			if !inLive {
				cur = def
			}
			switch {
			case local[k] || followed[d+"."+k]:
				// keepLocal / keepFollowed put the live value back
			case exact || prev.wrote(d, k, cur):
				if hasDef {
					base.Set(k, def)
				}
				if canon(cur) != canon(def) {
					sum.Reset = append(sum.Reset, d+"."+k)
				}
				continue
			case inLive:
				base.Set(k, cur)
				if canon(cur) != canon(def) {
					sum.Kept = append(sum.Kept, d+"."+k)
				}
				continue
			}
			if hasDef {
				base.Set(k, def)
			}
		}
		b, err := json.Marshal(base)
		if err != nil {
			return raw, sum, err
		}
		if raw[d], err = MergeJSON(b, raw[d]); err != nil {
			return raw, sum, err
		}
	}
	return raw, sum, nil
}

// noteApplied updates the record after an apply wrote the given keys: their
// live values now, plus the earlier entries the user has not changed since.
func (m *Manager) noteApplied(name string, written map[string]map[string]bool) error {
	if m.AppliedFile() == "" {
		return nil
	}
	prev := m.readApplied()
	next := &Applied{Preset: name, At: time.Now().UTC(), Values: map[string]map[string]any{}}
	domains := map[string]bool{}
	for d := range written {
		domains[d] = true
	}
	if prev != nil {
		for d := range prev.Values {
			domains[d] = true
		}
	}
	for d := range domains {
		if Excluded[d] || !m.Cat.HasDomain(d) {
			continue
		}
		live, defs := m.liveTop(d), m.Cat.DomainDefault(d)
		vals := map[string]any{}
		for k := range written[d] {
			vals[k] = effective(live, defs, k)
		}
		if prev != nil {
			for k, v := range prev.Values[d] {
				if _, ok := vals[k]; !ok && canon(effective(live, defs, k)) == canon(v) {
					vals[k] = v
				}
			}
		}
		if len(vals) > 0 {
			next.Values[d] = vals
		}
	}
	return m.writeApplied(next)
}

// withReset adds the reset keys of a summary to the written set.
func withReset(written map[string]map[string]bool, reset []string) map[string]map[string]bool {
	for _, key := range reset {
		d, k := splitKey(key)
		if written[d] == nil {
			written[d] = map[string]bool{}
		}
		written[d][k] = true
	}
	return written
}

func splitKey(key string) (string, string) {
	d, k, _ := strings.Cut(key, ".")
	return d, k
}

// setKeys lists the defined keys as full keys (an apply summary's Set).
func setKeys(defined map[string]map[string]bool) []string {
	var out []string
	for d, keys := range defined {
		for k := range keys {
			out = append(out, d+"."+k)
		}
	}
	sort.Strings(out)
	return out
}

// Sessions (try, edit, preview) keep the record from before them, so a
// revert also brings its provenance back.

func (m *Manager) appliedBackup(kind string) string {
	return filepath.Join(m.StateDir, "presets", kind+"-applied.json")
}

// backupApplied saves the record at a session's start ("null": none).
func (m *Manager) backupApplied(kind string) error {
	if m.AppliedFile() == "" || m.StateDir == "" {
		return nil
	}
	data, err := os.ReadFile(m.AppliedFile())
	if err != nil {
		data = []byte("null\n")
	}
	return writeAtomic(m.appliedBackup(kind), data)
}

// restoreApplied puts the record from a session's start back.
func (m *Manager) restoreApplied(kind string) error {
	if m.AppliedFile() == "" || m.StateDir == "" {
		return nil
	}
	data, err := os.ReadFile(m.appliedBackup(kind))
	if err != nil {
		return nil // an older session: no backup, keep the record
	}
	if string(data) == "null\n" {
		if err := os.Remove(m.AppliedFile()); err != nil && !os.IsNotExist(err) {
			return err
		}
		return nil
	}
	return writeAtomic(m.AppliedFile(), data)
}

// completeSet reports whether a preset is a whole official look (a set with
// a layout, a style and a palette): applying it replaces the earlier look,
// so what the earlier preset wrote and this one does not name goes.
func completeSet(p Preset) bool {
	return p.Official && SetRef{Layout: p.Layout, Style: p.Style, Palette: p.Palette}.Complete()
}

// resetLeftovers adds to the files of a complete set the keys the last
// apply wrote that the set does not name, back at their default, when the
// live value is still the one written (Emaki's panorama wallpaper must not
// stick under Kotoba). A key the user changed since is kept (Kept); keys of
// unknown origin are never touched.
func (m *Manager) resetLeftovers(raw map[string][]byte, follows []string) (map[string][]byte, ApplySummary, error) {
	var sum ApplySummary
	prev := m.readApplied()
	if prev == nil {
		return raw, sum, nil
	}
	followed := map[string]bool{}
	for _, f := range follows {
		followed[f] = true
	}
	for _, d := range sortedKeys(prev.Values) {
		if Excluded[d] || d == WallpaperDomain || !m.Cat.HasDomain(d) {
			continue
		}
		var doc map[string]any
		if data, ok := raw[d]; ok && json.Unmarshal(data, &doc) != nil {
			continue
		}
		live, defs, local := m.liveTop(d), m.Cat.DomainDefault(d), m.localTop(d)
		reset := catalog.NewObject()
		for _, k := range sortedKeys(prev.Values[d]) {
			def, hasDef := defs[k]
			if _, named := doc[k]; named || !hasDef || local[k] || followed[d+"."+k] {
				continue
			}
			cur := effective(live, defs, k)
			if canon(cur) == canon(def) {
				continue
			}
			if !prev.wrote(d, k, cur) {
				sum.Kept = append(sum.Kept, d+"."+k)
				continue
			}
			reset.Set(k, def)
			sum.Reset = append(sum.Reset, d+"."+k)
		}
		if len(reset.Keys()) == 0 {
			continue
		}
		b, err := json.Marshal(reset)
		if err != nil {
			return raw, sum, err
		}
		if over, ok := raw[d]; ok {
			if b, err = MergeJSON(b, over); err != nil {
				return raw, sum, err
			}
		}
		raw[d] = b
	}
	return raw, sum, nil
}
