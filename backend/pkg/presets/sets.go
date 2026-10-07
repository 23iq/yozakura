package presets

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"yozakura/backend/pkg/catalog"
)

// A set is a preset directory that names a layout, a style and a palette
// in set.json and may carry domain files of its own (overrides). Its
// documents are composed: for every domain the layout's, the style's, the
// palette's and the set's own file are deep-merged in that order (objects
// merge recursively, arrays and scalars replace). A directory without
// set.json is a legacy self-contained set: its files are used as they are.

// SetFile is the file naming a set's parts ("set" is never a domain).
const SetFile = "set.json"

// Part kinds, in composition order.
const (
	PartLayout  = "layout"
	PartStyle   = "style"
	PartPalette = "palette"
)

// PartKinds lists the part kinds in composition order.
var PartKinds = []string{PartLayout, PartStyle, PartPalette}

// SetRef is set.json: the parts a set is built from.
type SetRef struct {
	Layout  string `json:"layout"`
	Style   string `json:"style"`
	Palette string `json:"palette"`
}

// Get returns the part of a kind ("" for an unknown kind).
func (r SetRef) Get(kind string) string {
	switch kind {
	case PartLayout:
		return r.Layout
	case PartStyle:
		return r.Style
	case PartPalette:
		return r.Palette
	}
	return ""
}

// Set changes the part of a kind.
func (r *SetRef) Set(kind, name string) {
	switch kind {
	case PartLayout:
		r.Layout = name
	case PartStyle:
		r.Style = name
	case PartPalette:
		r.Palette = name
	}
}

// Complete reports whether every part is named.
func (r SetRef) Complete() bool { return r.Layout != "" && r.Style != "" && r.Palette != "" }

// ReadSetRef reads a directory's set.json; ok is false for a legacy set.
func ReadSetRef(dir string) (ref SetRef, ok bool, err error) {
	data, err := os.ReadFile(filepath.Join(dir, SetFile))
	if os.IsNotExist(err) {
		return SetRef{}, false, nil
	}
	if err != nil {
		return SetRef{}, false, err
	}
	if err := json.Unmarshal(data, &ref); err != nil {
		return SetRef{}, false, fmt.Errorf("%s/%s: %w", dir, SetFile, err)
	}
	return ref, true, nil
}

func encodeSetRef(ref SetRef) []byte {
	data, _ := json.MarshalIndent(ref, "", "    ")
	return append(data, '\n')
}

// PartDir resolves a part directory <officialDir>/<kind>s/<name>
// (case-insensitively).
func PartDir(officialDir, kind, name string) (string, error) {
	if officialDir == "" || name == "" || filepath.Base(name) != name || strings.HasPrefix(name, ".") {
		return "", fmt.Errorf("no %s %q", kind, name)
	}
	root := filepath.Join(officialDir, kind+"s")
	exact := filepath.Join(root, name)
	if st, err := os.Stat(exact); err == nil && st.IsDir() {
		return exact, nil
	}
	entries, _ := os.ReadDir(root)
	for _, e := range entries {
		if e.IsDir() && strings.EqualFold(e.Name(), name) {
			return filepath.Join(root, e.Name()), nil
		}
	}
	return "", fmt.Errorf("no %s %q in %s", kind, name, root)
}

// Compose returns the domain files of the set in setDir, its parts looked
// up in officialDir. It needs no catalog: only file contents are merged.
func Compose(officialDir, setDir string) (map[string][]byte, error) {
	own, err := readDir(setDir, domainsIn(setDir))
	if err != nil {
		return nil, err
	}
	ref, ok, err := ReadSetRef(setDir)
	if err != nil || !ok {
		return own, err
	}
	out := map[string][]byte{}
	for _, kind := range PartKinds {
		name := ref.Get(kind)
		if name == "" {
			continue
		}
		dir, err := PartDir(officialDir, kind, name)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", setDir, err)
		}
		files, err := readDir(dir, domainsIn(dir))
		if err != nil {
			return nil, err
		}
		if err := mergeFiles(out, files); err != nil {
			return nil, fmt.Errorf("%s: %w", dir, err)
		}
	}
	if err := mergeFiles(out, own); err != nil {
		return nil, fmt.Errorf("%s: %w", setDir, err)
	}
	return out, nil
}

// mergeFiles deep-merges every file of over into dst (a domain only in
// over is taken byte for byte).
func mergeFiles(dst, over map[string][]byte) error {
	for _, d := range sortedKeys(over) {
		if base, ok := dst[d]; ok {
			merged, err := MergeJSON(base, over[d])
			if err != nil {
				return fmt.Errorf("%s.json: %w", d, err)
			}
			dst[d] = merged
			continue
		}
		dst[d] = over[d]
	}
	return nil
}

// MergeJSON deep-merges the JSON document over into base, keeping base's
// key order: objects merge recursively, anything else in over replaces.
func MergeJSON(base, over []byte) ([]byte, error) {
	b, err := catalog.DecodeOrdered(base)
	if err != nil {
		return nil, err
	}
	o, err := catalog.DecodeOrdered(over)
	if err != nil {
		return nil, err
	}
	out, err := json.MarshalIndent(mergeValue(b, o), "", "  ")
	if err != nil {
		return nil, err
	}
	return append(out, '\n'), nil
}

func mergeValue(base, over any) any {
	bo, ok1 := base.(*catalog.Object)
	oo, ok2 := over.(*catalog.Object)
	if !ok1 || !ok2 {
		return over
	}
	for _, k := range oo.Keys() {
		v, _ := oo.Get(k)
		if cur, ok := bo.Get(k); ok {
			bo.Set(k, mergeValue(cur, v))
		} else {
			bo.Set(k, v)
		}
	}
	return bo
}

// isSetDir reports whether dir holds a set (set.json or domain files).
func isSetDir(dir string) bool {
	if _, err := os.Stat(filepath.Join(dir, SetFile)); err == nil {
		return true
	}
	return len(domainsIn(dir)) > 0
}

// officialSets is the directory of the built-in sets: <OfficialDir>/sets,
// or <OfficialDir> itself (legacy single-folder presets) without it.
func (m *Manager) officialSets() string { return OfficialSetsDir(m.OfficialDir) }

// OfficialSetsDir is officialSets for a built-in presets directory.
func OfficialSetsDir(officialDir string) string {
	if officialDir == "" {
		return ""
	}
	sets := filepath.Join(officialDir, "sets")
	if st, err := os.Stat(sets); err == nil && st.IsDir() {
		return sets
	}
	return officialDir
}

// dirFiles is the composed domain files of a set directory, without
// machine-local keys: what applying, previewing, hashing, duplicating and
// exporting the set use.
func (m *Manager) dirFiles(dir string) (map[string][]byte, error) {
	raw, err := Compose(m.OfficialDir, dir)
	if err != nil {
		return nil, err
	}
	for d, data := range raw {
		if raw[d], err = m.stripLocal(d, data); err != nil {
			return nil, fmt.Errorf("%s/%s.json: %w", dir, d, err)
		}
	}
	return raw, nil
}

// fillSet sets the composed Domains, Hash and parts of a listed preset;
// false when the set is broken or empty.
func fillSet(p *Preset, officialDir string) bool {
	files, err := Compose(officialDir, p.Path)
	if err != nil || len(files) == 0 {
		return false
	}
	p.Domains = sortedKeys(files)
	p.Hash = hashFiles(files)
	if ref, ok, _ := ReadSetRef(p.Path); ok {
		ref = resolveRef(officialDir, ref)
		p.Layout, p.Style, p.Palette = ref.Layout, ref.Style, ref.Palette
	}
	return true
}

// resolveRef spells every part like its directory.
func resolveRef(officialDir string, ref SetRef) SetRef {
	for _, kind := range PartKinds {
		if dir, err := PartDir(officialDir, kind, ref.Get(kind)); err == nil {
			ref.Set(kind, filepath.Base(dir))
		}
	}
	return ref
}

func domainsIn(dir string) []string {
	files, _ := filepath.Glob(filepath.Join(dir, "*.json"))
	var out []string
	for _, f := range files {
		d := strings.TrimSuffix(filepath.Base(f), ".json")
		if d == "info" || d == "set" || Excluded[d] {
			continue
		}
		out = append(out, d)
	}
	sort.Strings(out)
	return out
}

func readDir(dir string, domains []string) (map[string][]byte, error) {
	out := map[string][]byte{}
	for _, d := range domains {
		data, err := os.ReadFile(filepath.Join(dir, d+".json"))
		if err != nil {
			return nil, err
		}
		if !json.Valid(data) {
			return nil, fmt.Errorf("%s/%s.json is not valid JSON", dir, d)
		}
		out[d] = data
	}
	return out, nil
}
