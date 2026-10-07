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

// Parts are the built-in layouts, styles and palettes sets are composed
// from (<OfficialDir>/{layouts,styles,palettes}/<Name>). Applying one
// deep-merges its keys into the live config (everything else stays) and
// records it as the current part of its kind in active_parts.json.

// setDomain is set.json in a preset's file map (not a config domain).
const setDomain = "set"

// Part is one layout, style or palette.
type Part struct {
	Kind        string         `json:"kind"`
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Official    bool           `json:"official"`
	Active      bool           `json:"active"`
	Domains     []string       `json:"domains"`
	Look        map[string]any `json:"look"`
	Tags        []string       `json:"tags"`
	Path        string         `json:"-"`
}

// PartsReport is `preset parts --json`.
type PartsReport struct {
	Layouts  []Part `json:"layouts"`
	Styles   []Part `json:"styles"`
	Palettes []Part `json:"palettes"`
	Current  SetRef `json:"current"`
}

// PartsFile records the current part of each kind.
func (m *Manager) PartsFile() string { return filepath.Join(m.UserDir, "active_parts.json") }

// CurrentParts returns the current part markers ("" = unknown).
func (m *Manager) CurrentParts() SetRef {
	var ref SetRef
	if data, err := os.ReadFile(m.PartsFile()); err == nil {
		_ = json.Unmarshal(data, &ref)
	}
	return ref
}

// setCurrentParts writes the part markers (all empty removes the file).
func (m *Manager) setCurrentParts(ref SetRef) error {
	if ref == (SetRef{}) {
		if err := os.Remove(m.PartsFile()); err != nil && !os.IsNotExist(err) {
			return err
		}
		return nil
	}
	return writeAtomic(m.PartsFile(), encodeSetRef(ref))
}

// knownParts returns the current parts when every one is named and exists.
func (m *Manager) knownParts() (SetRef, bool) {
	ref := m.CurrentParts()
	if !ref.Complete() {
		return ref, false
	}
	for _, kind := range PartKinds {
		if _, err := PartDir(m.OfficialDir, kind, ref.Get(kind)); err != nil {
			return ref, false
		}
	}
	return ref, true
}

func checkKind(kind string) error {
	if !contains(PartKinds, kind) {
		return fmt.Errorf("unknown part kind %q (kinds: %s)", kind, strings.Join(PartKinds, ", "))
	}
	return nil
}

// Parts lists the parts of a kind by name (without looks).
func (m *Manager) Parts(kind string) ([]Part, error) {
	if err := checkKind(kind); err != nil {
		return nil, err
	}
	out := []Part{}
	if m.OfficialDir == "" {
		return out, nil
	}
	entries, _ := os.ReadDir(filepath.Join(m.OfficialDir, kind+"s"))
	current := m.CurrentParts().Get(kind)
	for _, e := range entries {
		if !e.IsDir() || strings.HasPrefix(e.Name(), ".") {
			continue
		}
		dir := filepath.Join(m.OfficialDir, kind+"s", e.Name())
		p := Part{Kind: kind, Name: e.Name(), Official: true, Path: dir, Domains: domainsIn(dir), Tags: []string{}}
		if len(p.Domains) == 0 {
			continue
		}
		if inf, ok := readInfo(dir); ok {
			p.Description = inf.Description
		}
		p.Active = strings.EqualFold(p.Name, current)
		out = append(out, p)
	}
	sort.Slice(out, func(i, j int) bool { return strings.ToLower(out[i].Name) < strings.ToLower(out[j].Name) })
	return out, nil
}

// AllParts lists every kind with looks: each look is the live config with
// the part merged in, so a thumbnail shows the result of applying it.
func (m *Manager) AllParts() (PartsReport, error) {
	r := PartsReport{Current: m.CurrentParts()}
	live, err := m.rawDocuments(Current)
	if err != nil {
		return r, err
	}
	lists := map[string]*[]Part{PartLayout: &r.Layouts, PartStyle: &r.Styles, PartPalette: &r.Palettes}
	for _, kind := range PartKinds {
		parts, err := m.Parts(kind)
		if err != nil {
			return r, err
		}
		for i := range parts {
			if docs, err := m.partOverLive(live, parts[i].Path); err == nil {
				parts[i].Look = m.LookOf(docs)
				parts[i].Tags = TagsOf(parts[i].Look)
			}
		}
		*lists[kind] = parts
	}
	return r, nil
}

// partOverLive merges a part's files over the live documents.
func (m *Manager) partOverLive(live map[string][]byte, dir string) (map[string]any, error) {
	files, err := m.partFiles(dir)
	if err != nil {
		return nil, err
	}
	merged := map[string][]byte{}
	for d, data := range live {
		merged[d] = data
	}
	if err := mergeFiles(merged, files); err != nil {
		return nil, err
	}
	docs := map[string]any{}
	for d, data := range merged {
		var v any
		if err := json.Unmarshal(data, &v); err != nil {
			return nil, err
		}
		docs[d] = v
	}
	return docs, nil
}

// partFiles reads a part's domain files without machine-local keys.
func (m *Manager) partFiles(dir string) (map[string][]byte, error) {
	raw, err := readDir(dir, domainsIn(dir))
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

// findPart resolves a part by name (case-insensitively).
func (m *Manager) findPart(kind, name string) (Part, error) {
	if err := checkKind(kind); err != nil {
		return Part{}, err
	}
	dir, err := PartDir(m.OfficialDir, kind, name)
	if err != nil {
		return Part{}, err
	}
	p := Part{Kind: kind, Name: filepath.Base(dir), Official: true, Path: dir, Domains: domainsIn(dir)}
	if len(p.Domains) == 0 {
		return p, fmt.Errorf("%s %q has no config files", kind, p.Name)
	}
	return p, nil
}

// ApplyPart merges a layout, style or palette into the live config and
// makes it the current part of its kind. A running preview is kept.
func (m *Manager) ApplyPart(kind, name string) (Part, []catalog.Problem, error) {
	unlock, err := m.lock()
	if err != nil {
		return Part{}, nil, err
	}
	defer unlock()
	p, problems, err := m.applyPart(kind, name)
	if err == nil {
		m.dropSession(PreviewSession)
	}
	return p, problems, err
}

func (m *Manager) applyPart(kind, name string) (Part, []catalog.Problem, error) {
	p, err := m.findPart(kind, name)
	if err != nil {
		return p, nil, err
	}
	files, err := m.partFiles(p.Path)
	if err != nil {
		return p, nil, err
	}
	for d, data := range files {
		if d == WallpaperDomain || !m.Cat.HasDomain(d) {
			continue
		}
		if live, err := os.ReadFile(m.Store.File(d)); err == nil {
			if merged, err := MergeJSON(live, data); err == nil {
				files[d] = merged
			}
		}
	}
	problems, err := m.applyFiles(files)
	if err != nil {
		return p, problems, err
	}
	ref := m.CurrentParts()
	ref.Set(kind, p.Name)
	if err := m.setCurrentParts(ref); err != nil {
		return p, problems, err
	}
	// The active set no longer describes the look unless it names this part.
	if active := m.Active(); active != "" {
		if set, err := m.Find(active); err != nil || !strings.EqualFold(SetRef{Layout: set.Layout, Style: set.Style, Palette: set.Palette}.Get(kind), p.Name) {
			if err := m.setActive(""); err != nil {
				return p, problems, err
			}
		}
	}
	p.Active = true
	return p, problems, nil
}

// PreviewPart applies a part for a look in the preview session (Revert
// restores the config from before the first preview of the chain).
func (m *Manager) PreviewPart(kind, name string) (*Session, error) {
	return m.preview(func() (previewTarget, error) {
		p, err := m.findPart(kind, name)
		return previewTarget{name: p.Name, part: kind, domains: p.Domains, apply: func() error {
			_, _, err := m.applyPart(kind, p.Name)
			return err
		}}, err
	})
}
