package presets

import (
	"strings"

	"yozakura/backend/pkg/catalog"
)

// Diff is one key that differs between two presets. A domain present in
// only one side is reported once with OnlyIn set.
type Diff struct {
	Key    string `json:"key"`
	A      any    `json:"a,omitempty"`
	B      any    `json:"b,omitempty"`
	OnlyIn string `json:"onlyIn,omitempty"` // "a" or "b": the domain file exists on one side only
}

// Compare diffs two presets, "current", "defaults" or bundle files, key by
// key. Each side is read as the shell would run it (missing keys = defaults).
func (m *Manager) Compare(a, b string) ([]Diff, error) {
	da, err := m.Documents(a)
	if err != nil {
		return nil, err
	}
	db, err := m.Documents(b)
	if err != nil {
		return nil, err
	}
	return m.compareDocs(da, db, nil), nil
}

// compareDocs diffs two document sets over the given domains (nil: every
// domain of either side; a domain missing on one side is reported once).
func (m *Manager) compareDocs(da, db map[string]any, only []string) []Diff {
	domains := map[string]bool{}
	if only != nil {
		for _, d := range only {
			domains[d] = true
		}
	} else {
		for d := range da {
			domains[d] = true
		}
		for d := range db {
			domains[d] = true
		}
	}
	var out []Diff
	for _, d := range sortedKeys(domains) {
		docA, okA := da[d]
		docB, okB := db[d]
		if d == WallpaperDomain && only == nil && (!okA || !okB) {
			continue // no wallpaper.json: the preset keeps the user's scheme
		}
		switch {
		case only == nil && !okA:
			out = append(out, Diff{Key: d, OnlyIn: "b"})
			continue
		case only == nil && !okB:
			out = append(out, Diff{Key: d, OnlyIn: "a"})
			continue
		}
		fa := m.flatten(d, docA)
		fb := m.flatten(d, docB)
		keys := map[string]bool{}
		for k := range fa {
			keys[k] = true
		}
		for k := range fb {
			keys[k] = true
		}
		for _, k := range sortedKeys(keys) {
			if m.Cat.MachineLocal(k) {
				continue // never a preset key (stripped on read; old files may hold one)
			}
			if catalog.Compact(fa[k]) != catalog.Compact(fb[k]) {
				out = append(out, Diff{Key: k, A: m.maskSecret(k, fa[k]), B: m.maskSecret(k, fb[k])})
			}
		}
	}
	return out
}

// flatten merges doc over the domain defaults and lists every leaf
// (arrays are leaves) by full key.
func (m *Manager) flatten(domain string, doc any) map[string]any {
	out := map[string]any{}
	var walk func(prefix string, def, cur any)
	walk = func(prefix string, def, cur any) {
		dm, _ := def.(map[string]any)
		cm, _ := cur.(map[string]any)
		if dm == nil && cm == nil {
			if cur == nil {
				cur = def
			}
			out[prefix] = cur
			return
		}
		seen := map[string]bool{}
		for k := range dm {
			seen[k] = true
		}
		for k := range cm {
			seen[k] = true
		}
		for k := range seen {
			var c any
			if cm != nil {
				c = cm[k]
			}
			walk(prefix+"."+k, dm[k], c)
		}
	}
	walk(domain, m.Cat.DomainDefault(domain), doc)
	for k := range out {
		if strings.Count(k, ".") == 0 {
			delete(out, k)
		}
	}
	return out
}
